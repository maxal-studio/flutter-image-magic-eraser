import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../models/bounding_box.dart';
import '../models/inpainting_config.dart';
import '../utils/image_disposal_util.dart';
import 'image_processing_service.dart';
import 'mask_generation_service.dart';
import 'onnx_model_service.dart';

/// Service for polygon-based inpainting
///
/// This service implements the polygon-based inpainting algorithm, which processes
/// each polygon individually with appropriate context expansion.
class PolygonInpaintingService {
  PolygonInpaintingService._internal();

  static final PolygonInpaintingService _instance =
      PolygonInpaintingService._internal();

  /// Returns the singleton instance of the service
  static PolygonInpaintingService get instance => _instance;

  /// Inpaints the masked areas of an image using polygons defined by points.
  ///
  /// This method processes each polygon individually, expanding the bounding box,
  /// cropping and resizing the image, and applying the inpainted patch precisely
  /// within the polygon boundaries. This ensures that only the masked regions are
  /// affected by the inpainting process.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [polygons]: A list of lists, each inner list containing at least 3 points as maps with 'x' and 'y' keys.
  /// - [config]: Configuration parameters for the inpainting algorithm.
  /// - Returns: A [ui.Image] with the masked areas inpainted.
  Future<ui.Image> inpaintPolygons(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    // Use default configuration if none provided
    final cfg = config ?? const InpaintingConfig();

    if (kDebugMode) {
      log('Starting polygon-based inpainting with config: $cfg',
          name: 'PolygonInpaintingService');
    }

    try {
      // Decode the input image
      final originalImage = await decodeImageFromList(imageBytes);

      // Process each polygon
      ui.Image resultImage = originalImage;
      for (final polygon in polygons) {
        ui.Image previousImage = resultImage;
        // Inpaint the polygon
        resultImage = await _inpaintPolygon(resultImage, polygon, cfg);

        // Dispose previous iteration image if not the original
        if (previousImage != originalImage) {
          ImageDisposalUtil.disposeImage(previousImage);
        }
      }

      // Return the final result (this will be disposed by the caller)
      return resultImage;
    } catch (e) {
      if (kDebugMode) {
        log('Error in inpaintPolygons: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

  /// Inpaints a single polygon in the image
  ///
  /// This method processes a single polygon by:
  /// 1. Computing a bounding box around the polygon
  /// 2. Expanding the bounding box to provide context for the inpainting model
  /// 3. Cropping the image to the expanded bounding box
  /// 4. Creating a mask from the polygon
  /// 5. Resizing the cropped image and mask if needed
  /// 6. Running the inpainting model
  /// 7. Applying the inpainted patch precisely within the polygon boundaries
  ///
  /// The result is an image where only the area inside the polygon has been inpainted.
  Future<ui.Image> _inpaintPolygon(
    ui.Image image,
    List<Map<String, double>> polygon,
    InpaintingConfig config,
  ) async {
    ui.Image? croppedImage;
    ui.Image? maskImage;
    ui.Image? resizedImage;
    ui.Image? resizedMask;
    ui.Image? inpaintedPatch;
    ui.Image? finalPatch;
    ui.Image? result;

    try {
      // 1. Compute bounding box around the polygon
      final bbox = BoundingBox.fromPoints(polygon);

      // 2. Determine expansion size based on mask dimensions
      BoundingBox expandedBox;

      // If bbox is small enough, expand to input_size
      if (bbox.width <= config.inputSize && bbox.height <= config.inputSize) {
        expandedBox = bbox.ensureSize(
          targetSize: config.inputSize,
          imageWidth: image.width,
          imageHeight: image.height,
        );
      } else {
        // Otherwise, expand by the specified percentage
        expandedBox = bbox.expand(
          percentage: config.expandPercentage,
          maxExpansion: config.maxExpansionSize,
          imageWidth: image.width,
          imageHeight: image.height,
        );
      }

      // 3. Crop the original image using the adjusted bbox
      croppedImage = await _cropImage(
        image,
        expandedBox,
      );

      // Generate mask for the polygon
      final polygonRelativeToBox = _adjustPolygonToBox(polygon, expandedBox);

      maskImage = await MaskGenerationService.instance.generateMask(
        [polygonRelativeToBox],
        expandedBox.width,
        expandedBox.height,
        backgroundColor: Colors.black,
        fillColor: Colors.white,
      );

      // 4. Resize to input_size if needed
      if (expandedBox.width != config.inputSize ||
          expandedBox.height != config.inputSize) {
        // Use a safer resizing method
        resizedImage = await _safeResizeImage(
          croppedImage,
          config.inputSize,
          config.inputSize,
        );

        resizedMask = await _safeResizeImage(
          maskImage,
          config.inputSize,
          config.inputSize,
        );
      } else {
        resizedImage = croppedImage;
        resizedMask = maskImage;
      }

      // 5. Send to ONNX model for inpainting
      inpaintedPatch = await _runInference(resizedImage, resizedMask);

      // If the patch was resized, resize it back to the original bbox size
      if (expandedBox.width != config.inputSize ||
          expandedBox.height != config.inputSize) {
        finalPatch = await _safeResizeImage(
          inpaintedPatch,
          expandedBox.width,
          expandedBox.height,
        );
        // Dispose inpaintedPatch as we no longer need it
        ImageDisposalUtil.disposeImage(inpaintedPatch);
        inpaintedPatch = null;
      } else {
        finalPatch = inpaintedPatch;
        inpaintedPatch = null; // Avoid double disposal
      }

      // 6. Apply inpainted patch only within the polygon area
      result = await _blendPatchIntoImage(
        image,
        finalPatch,
        expandedBox,
        polygon,
      );

      return result;
    } catch (e) {
      if (kDebugMode) {
        log('Error in _inpaintPolygon: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    } finally {
      // Dispose all temporary images
      List<ui.Image?> imagesToDispose = [
        croppedImage,
        maskImage,
        // Only dispose resizedImage if it's different from croppedImage
        resizedImage != croppedImage ? resizedImage : null,
        // Only dispose resizedMask if it's different from maskImage
        resizedMask != maskImage ? resizedMask : null,
        inpaintedPatch,
        // Only dispose finalPatch if it's different from inpaintedPatch
        finalPatch != inpaintedPatch ? finalPatch : null,
      ];

      ImageDisposalUtil.disposeImages(imagesToDispose);
    }
  }

  /// Efficiently resizes an image to the specified dimensions
  Future<ui.Image> _safeResizeImage(
    ui.Image image,
    int targetWidth,
    int targetHeight,
  ) async {
    try {
      // Skip resizing if dimensions already match
      if (image.width == targetWidth && image.height == targetHeight) {
        return image;
      }

      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Use a high-quality paint object for better results
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      // Draw the image scaled to the target size
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );

      // Convert to an image
      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(targetWidth, targetHeight);

      return resizedImage;
    } catch (e) {
      if (kDebugMode) {
        log('Error in _safeResizeImage: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

  /// Crops an image to the specified rectangle
  Future<ui.Image> _cropImage(
    ui.Image image,
    BoundingBox box,
  ) async {
    try {
      final x = box.x;
      final y = box.y;
      final width = box.width;
      final height = box.height;

      // Ensure the crop rectangle is within the image bounds
      final safeX = x.clamp(0, image.width - 1);
      final safeY = y.clamp(0, image.height - 1);
      final safeWidth = width.clamp(1, image.width - safeX);
      final safeHeight = height.clamp(1, image.height - safeY);

      if (kDebugMode &&
          (safeX != x ||
              safeY != y ||
              safeWidth != width ||
              safeHeight != height)) {
        log('Adjusted crop rectangle from ($x,$y,$width,$height) to ($safeX,$safeY,$safeWidth,$safeHeight)',
            name: 'PolygonInpaintingService');
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the portion of the image we want to crop
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(safeX.toDouble(), safeY.toDouble(), safeWidth.toDouble(),
            safeHeight.toDouble()),
        Rect.fromLTWH(0, 0, safeWidth.toDouble(), safeHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      return await picture.toImage(safeWidth, safeHeight);
    } catch (e) {
      if (kDebugMode) {
        log('Error in _cropImage: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

  /// Adjusts polygon points to be relative to the bounding box
  List<Map<String, double>> _adjustPolygonToBox(
    List<Map<String, double>> polygon,
    BoundingBox box,
  ) {
    return polygon.map((point) {
      return {
        'x': point['x']! - box.x,
        'y': point['y']! - box.y,
      };
    }).toList();
  }

  /// Runs inference on the ONNX model
  Future<ui.Image> _runInference(
    ui.Image image,
    ui.Image mask,
  ) async {
    try {
      // Check if the model is loaded
      if (!OnnxModelService.instance.isModelLoaded()) {
        throw Exception(
            'ONNX model not initialized. Call initializeOrt first.');
      }

      // Convert mask to grayscale
      final grayscaleMask = mask;

      // Convert to tensors
      final rgbFloats =
          await ImageProcessingService.instance.imageToFloatTensor(image);
      final maskFloats = await ImageProcessingService.instance
          .maskToFloatTensor(grayscaleMask);

      // Create tensors for ONNX model
      final imageTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(rgbFloats),
        [1, 3, image.width, image.height],
      );

      final maskTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(maskFloats),
        [1, 1, mask.width, mask.height],
      );

      // Run inference
      final inputs = {
        'image': imageTensor,
        'mask': maskTensor,
      };

      final outputs = await OnnxModelService.instance.runInference(inputs);

      // Release tensors
      imageTensor.release();
      maskTensor.release();

      // Process output
      final outputTensor = outputs?[0]?.value;
      if (outputTensor is List) {
        final output = outputTensor[0];
        return await ImageProcessingService.instance.rgbTensorToUIImage(output);
      } else {
        throw Exception('Unexpected output format from ONNX model.');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error in _runInference: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

  /// Creates a path from a polygon
  Path _createPolygonPath(List<Map<String, double>> polygon) {
    final polygonPath = Path();

    if (polygon.isNotEmpty) {
      // Start at the first point
      polygonPath.moveTo(
        polygon[0]['x']!.toDouble(),
        polygon[0]['y']!.toDouble(),
      );

      // Add lines to each subsequent point
      for (int i = 1; i < polygon.length; i++) {
        polygonPath.lineTo(
          polygon[i]['x']!.toDouble(),
          polygon[i]['y']!.toDouble(),
        );
      }

      // Close the path
      polygonPath.close();
    }

    return polygonPath;
  }

  /// Blends a patch within a polygon boundary
  Future<ui.Image> _blendPatchWithinPolygon(
    ui.Image originalImage,
    ui.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the original image as the base
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Save the canvas state before clipping
      canvas.save();

      // Create and apply the polygon clip path
      final polygonPath = _createPolygonPath(polygon);
      canvas.clipPath(polygonPath);

      // Draw the patch at the correct position with high quality
      // This will only affect the area inside the polygon clip
      canvas.drawImageRect(
        patch,
        Rect.fromLTWH(0, 0, patch.width.toDouble(), patch.height.toDouble()),
        Rect.fromLTWH(
          box.x.toDouble(),
          box.y.toDouble(),
          box.width.toDouble(),
          box.height.toDouble(),
        ),
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );

      // Restore the canvas state
      canvas.restore();

      // Convert to an image
      final picture = recorder.endRecording();
      return await picture.toImage(originalImage.width, originalImage.height);
    } catch (e) {
      if (kDebugMode) {
        final logTag = debugTag.isNotEmpty
            ? '$debugTag - _blendPatchWithinPolygon'
            : '_blendPatchWithinPolygon';
        log('Error in $logTag: $e', name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

  /// Blends an inpainted patch back into the original image
  ///
  /// This method draws the inpainted patch only within the polygon area,
  /// ensuring that only the masked region is affected by the inpainting.
  Future<ui.Image> _blendPatchIntoImage(
    ui.Image originalImage,
    ui.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, // Original polygon for clipping
  ) async {
    return _blendPatchWithinPolygon(
        originalImage, patch, box, polygon, '_blendPatchIntoImage');
  }

  /// Generates debug images for each step of the inpainting process
  Future<Map<String, ui.Image>> generateDebugImages(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    // Use default configuration if none provided
    final cfg = config ?? const InpaintingConfig();
    final debugImages = <String, ui.Image>{};

    try {
      // Decode the input image
      final originalImage = await decodeImageFromList(imageBytes);
      debugImages['original'] = originalImage;

      if (polygons.isEmpty) {
        if (kDebugMode) {
          log('No polygons provided for debugging',
              name: 'PolygonInpaintingService');
        }
        return debugImages;
      }

      // Process each polygon sequentially
      ui.Image currentImage = originalImage;

      for (int polyIndex = 0; polyIndex < polygons.length; polyIndex++) {
        final polygon = polygons[polyIndex];

        ui.Image? croppedImage;
        ui.Image? maskImage;
        ui.Image? resizedImage;
        ui.Image? resizedMask;
        ui.Image? inpaintedPatch;
        ui.Image? finalPatch;

        try {
          // 1. Compute bounding box around the polygon
          final bbox = BoundingBox.fromPoints(polygon);

          // 2. Determine expansion size based on mask dimensions
          BoundingBox expandedBox;

          // If bbox is small enough, expand to input_size
          if (bbox.width <= cfg.inputSize && bbox.height <= cfg.inputSize) {
            expandedBox = bbox.ensureSize(
              targetSize: cfg.inputSize,
              imageWidth: currentImage.width,
              imageHeight: currentImage.height,
            );
          } else {
            // Otherwise, expand by the specified percentage
            expandedBox = bbox.expand(
              percentage: cfg.expandPercentage,
              maxExpansion: cfg.maxExpansionSize,
              imageWidth: currentImage.width,
              imageHeight: currentImage.height,
            );
          }

          // 3. Crop the current image using the adjusted bbox
          croppedImage = await _cropImage(
            currentImage,
            expandedBox,
          );
          debugImages['cropped_$polyIndex'] = croppedImage;

          // Generate mask for the polygon
          final polygonRelativeToBox =
              _adjustPolygonToBox(polygon, expandedBox);

          maskImage = await MaskGenerationService.instance.generateMask(
            [polygonRelativeToBox],
            expandedBox.width,
            expandedBox.height,
            backgroundColor: Colors.black,
            fillColor: Colors.white,
          );
          debugImages['mask_$polyIndex'] = maskImage;

          // 4. Resize to input_size if needed
          if (expandedBox.width != cfg.inputSize ||
              expandedBox.height != cfg.inputSize) {
            // Resize the image and mask
            resizedImage = await _safeResizeImage(
              croppedImage,
              cfg.inputSize,
              cfg.inputSize,
            );
            debugImages['resized_image_$polyIndex'] = resizedImage;

            resizedMask = await _safeResizeImage(
              maskImage,
              cfg.inputSize,
              cfg.inputSize,
            );
            debugImages['resized_mask_$polyIndex'] = resizedMask;
          } else {
            resizedImage = croppedImage;
            resizedMask = maskImage;
          }

          // 5. Run inference
          try {
            inpaintedPatch = await _runInference(resizedImage, resizedMask);
            debugImages['inpainted_patch_raw_$polyIndex'] = inpaintedPatch;

            // If the patch was resized, resize it back to the original bbox size
            if (expandedBox.width != cfg.inputSize ||
                expandedBox.height != cfg.inputSize) {
              finalPatch = await _safeResizeImage(
                inpaintedPatch,
                expandedBox.width,
                expandedBox.height,
              );
            } else {
              finalPatch = inpaintedPatch;
              inpaintedPatch = null; // Avoid double disposal
            }
            debugImages['inpainted_patch_resized_$polyIndex'] = finalPatch;

            // 7. Blend the patch into the current image
            ui.Image previousImage = currentImage;
            if (polyIndex > 0) {
              // Don't blend into the original for first polygon
              currentImage = await _blendPatchIntoImage(
                currentImage,
                finalPatch,
                expandedBox,
                polygon,
              );

              // Dispose the previous intermediate result
              if (previousImage != originalImage) {
                ImageDisposalUtil.disposeImage(previousImage);
              }
            }
          } catch (e) {
            if (kDebugMode) {
              log('Error generating inpainted patch for polygon $polyIndex: $e',
                  name: 'PolygonInpaintingService', error: e);
            }
          }
        } finally {
          // We don't dispose images stored in debugImages
          // They will be disposed by the caller
        }
      }

      // Store the final result
      debugImages['final_result'] = currentImage;

      return debugImages;
    } catch (e) {
      if (kDebugMode) {
        log('Error generating debug images: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      return debugImages;
    }
  }

  /// Generates a debug visualization of the polygons and bounding boxes
  Future<ui.Image> generateDebugVisualization(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    // Use default configuration if none provided
    final cfg = config ?? const InpaintingConfig();

    try {
      // Decode the input image
      final originalImage = await decodeImageFromList(imageBytes);

      // Create a picture recorder to draw the visualization
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the original image as the base
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Draw each polygon and its bounding box
      for (int i = 0; i < polygons.length; i++) {
        final polygon = polygons[i];

        // Draw the polygon
        final polygonPath = Path();
        polygonPath.moveTo(
            polygon[0]['x']!.toDouble(), polygon[0]['y']!.toDouble());

        for (int j = 1; j < polygon.length; j++) {
          polygonPath.lineTo(
              polygon[j]['x']!.toDouble(), polygon[j]['y']!.toDouble());
        }

        polygonPath.close();

        canvas.drawPath(
          polygonPath,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.8)
            ..style = PaintingStyle.fill,
        );

        // Compute bounding box
        final bbox = BoundingBox.fromPoints(polygon);

        // Determine expansion size
        BoundingBox expandedBox;

        if (bbox.width <= cfg.inputSize && bbox.height <= cfg.inputSize) {
          expandedBox = bbox.ensureSize(
            targetSize: cfg.inputSize,
            imageWidth: originalImage.width,
            imageHeight: originalImage.height,
          );
        } else {
          expandedBox = bbox.expand(
            percentage: cfg.expandPercentage,
            maxExpansion: cfg.maxExpansionSize,
            imageWidth: originalImage.width,
            imageHeight: originalImage.height,
          );
        }

        // Draw the original bounding box
        canvas.drawRect(
          Rect.fromLTWH(
            bbox.x.toDouble(),
            bbox.y.toDouble(),
            bbox.width.toDouble(),
            bbox.height.toDouble(),
          ),
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        // Draw the expanded bounding box
        canvas.drawRect(
          Rect.fromLTWH(
            expandedBox.x.toDouble(),
            expandedBox.y.toDouble(),
            expandedBox.width.toDouble(),
            expandedBox.height.toDouble(),
          ),
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Convert the canvas to an image
      final picture = recorder.endRecording();
      final resultImage =
          await picture.toImage(originalImage.width, originalImage.height);

      return resultImage;
    } catch (e) {
      if (kDebugMode) {
        log('Error generating debug visualization: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }
}
