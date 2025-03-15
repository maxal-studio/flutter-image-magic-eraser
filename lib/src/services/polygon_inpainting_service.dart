import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_magic_eraser/src/services/image_processing/tensor_processor.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../models/bounding_box.dart';
import '../models/inpainting_config.dart';
import '../utils/image_disposal_util.dart';
import 'image_processing_service.dart';
import 'onnx_model_service.dart';
import 'package:image/image.dart' as img;

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
      img.Image originalImage = img.decodeImage(imageBytes)!;

      for (final polygon in polygons) {
        // Inpaint the polygon
        originalImage = await _inpaintPolygon(originalImage, polygon, cfg);
      }

      // Return the final result (this will be disposed by the caller)
      return await ImageProcessingService.instance
          .convertImageToUiImage(originalImage);
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
  Future<img.Image> _inpaintPolygon(
    img.Image image,
    List<Map<String, double>> polygon,
    InpaintingConfig config,
  ) async {
    img.Image packagedImage = image;
    img.Image? packagedImageCropped;
    img.Image? packagedMask;
    img.Image? inpaintedPackagedImage;
    img.Image? inpaintedPatchFinalImage;

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

      // 3. Crop the image if needed
      if (expandedBox.x != 0 ||
          expandedBox.y != 0 ||
          expandedBox.width != image.width ||
          expandedBox.height != image.height) {
        packagedImageCropped = await ImageProcessingService.instance.cropImage(
          packagedImage,
          expandedBox.x,
          expandedBox.y,
          expandedBox.width,
          expandedBox.height,
        );
      } else {
        packagedImageCropped = packagedImage;
      }

      // Generate mask for the polygon
      final polygonRelativeToBox = _adjustPolygonToBox(polygon, expandedBox);

      // 4. Generate mask
      packagedMask = await ImageProcessingService.instance.generateMaskImage(
        [polygonRelativeToBox],
        expandedBox.width,
        expandedBox.height,
      );

      // 5. Resize if needed
      img.Image resizedPackagedImage;
      img.Image resizedPackagedMask;

      if (expandedBox.width != config.inputSize ||
          expandedBox.height != config.inputSize) {
        resizedPackagedImage =
            await ImageProcessingService.instance.resizeImage(
          packagedImageCropped,
          config.inputSize,
          config.inputSize,
          useBilinear: true,
        );

        resizedPackagedMask = await ImageProcessingService.instance.resizeImage(
          packagedMask,
          config.inputSize,
          config.inputSize,
          useBilinear: false,
        );
      } else {
        resizedPackagedImage = packagedImageCropped;
        resizedPackagedMask = packagedMask;
      }

      // 6. Run inference
      inpaintedPackagedImage = await _runInference(
        resizedPackagedImage,
        resizedPackagedMask,
      );

      // 7. Resize patch back if needed
      if (expandedBox.width != config.inputSize ||
          expandedBox.height != config.inputSize) {
        inpaintedPatchFinalImage =
            await ImageProcessingService.instance.resizeImage(
          inpaintedPackagedImage,
          expandedBox.width,
          expandedBox.height,
          useBilinear: true,
        );
      } else {
        inpaintedPatchFinalImage = inpaintedPackagedImage;
      }

      // 8. Apply inpainted patch
      return await ImageProcessingService.instance.blendImgPatchIntoImage(
        packagedImage,
        inpaintedPatchFinalImage,
        expandedBox,
        polygon,
      );
    } catch (e) {
      debugPrint('-------Error in _inpaintPolygon: $e');
      if (kDebugMode) {
        log('Error in _inpaintPolygon: $e',
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
  Future<img.Image> _runInference(
    img.Image image,
    img.Image mask,
  ) async {
    try {
      // Check if the model is loaded
      if (!OnnxModelService.instance.isModelLoaded()) {
        throw Exception(
            'ONNX model not initialized. Call initializeOrt first.');
      }

      // Convert to tensors
      final rgbFloats = await TensorProcessor.imgImageToFloatTensor(image);
      final maskFloats = await TensorProcessor.imgMaskToFloatTensor(mask);

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
        return await TensorProcessor.rgbTensorToImgImage(output);
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

          // Convert current image to img.Image for processing
          final img.Image packagedImage = await ImageProcessingService.instance
              .convertUiImageToImage(currentImage);

          // 3. Crop the current image using the adjusted bbox
          img.Image croppedPackagedImage;
          if (expandedBox.x != 0 ||
              expandedBox.y != 0 ||
              expandedBox.width != currentImage.width ||
              expandedBox.height != currentImage.height) {
            croppedPackagedImage =
                await ImageProcessingService.instance.cropImage(
              packagedImage,
              expandedBox.x,
              expandedBox.y,
              expandedBox.width,
              expandedBox.height,
            );
          } else {
            croppedPackagedImage = packagedImage;
          }

          // Convert back to ui.Image for debug output
          croppedImage = await ImageProcessingService.instance
              .convertImageToUiImage(croppedPackagedImage);
          debugImages['cropped_$polyIndex'] = croppedImage;

          // Generate mask for the polygon
          final polygonRelativeToBox =
              _adjustPolygonToBox(polygon, expandedBox);

          // 4. Generate mask using ImagePackageService
          img.Image packagedMask =
              await ImageProcessingService.instance.generateMaskImage(
            [polygonRelativeToBox],
            expandedBox.width,
            expandedBox.height,
          );

          // Convert mask to ui.Image for debug output
          maskImage = await ImageProcessingService.instance
              .convertImageToUiImage(packagedMask);
          debugImages['mask_$polyIndex'] = maskImage;

          // 5. Resize if needed
          img.Image resizedPackagedImage;
          img.Image resizedPackagedMask;

          if (expandedBox.width != cfg.inputSize ||
              expandedBox.height != cfg.inputSize) {
            resizedPackagedImage =
                await ImageProcessingService.instance.resizeImage(
              croppedPackagedImage,
              cfg.inputSize,
              cfg.inputSize,
              useBilinear: true,
            );

            resizedPackagedMask =
                await ImageProcessingService.instance.resizeImage(
              packagedMask,
              cfg.inputSize,
              cfg.inputSize,
              useBilinear: false,
            );

            // Convert resized images to ui.Image for debug output
            resizedImage = await ImageProcessingService.instance
                .convertImageToUiImage(resizedPackagedImage);
            debugImages['resized_image_$polyIndex'] = resizedImage;

            resizedMask = await ImageProcessingService.instance
                .convertImageToUiImage(resizedPackagedMask);
            debugImages['resized_mask_$polyIndex'] = resizedMask;
          } else {
            resizedPackagedImage = croppedPackagedImage;
            resizedPackagedMask = packagedMask;
            resizedImage = croppedImage;
            resizedMask = maskImage;
          }

          // 6. Run inference
          try {
            final inpaintedPackagedImage =
                await _runInference(resizedPackagedImage, resizedPackagedMask);

            // Convert inpainted image to ui.Image for debug output
            inpaintedPatch = await ImageProcessingService.instance
                .convertImageToUiImage(inpaintedPackagedImage);
            debugImages['inpainted_patch_raw_$polyIndex'] = inpaintedPatch;

            // If the patch was resized, resize it back to the original bbox size
            if (expandedBox.width != cfg.inputSize ||
                expandedBox.height != cfg.inputSize) {
              // Convert back to img.Image for resizing
              final inpaintedImgImage = await ImageProcessingService.instance
                  .convertUiImageToImage(inpaintedPatch);

              // Resize using ImagePackageService
              final resizedInpaintedImage =
                  await ImageProcessingService.instance.resizeImage(
                inpaintedImgImage,
                expandedBox.width,
                expandedBox.height,
                useBilinear: true,
              );

              // Convert back to ui.Image
              finalPatch = await ImageProcessingService.instance
                  .convertImageToUiImage(resizedInpaintedImage);
            } else {
              finalPatch = inpaintedPatch;
              inpaintedPatch = null; // Avoid double disposal
            }
            debugImages['inpainted_patch_resized_$polyIndex'] = finalPatch;

            // 7. Blend the patch into the current image
            ui.Image previousImage = currentImage;
            if (polyIndex > 0) {
              // Don't blend into the original for first polygon
              currentImage =
                  await ImageProcessingService.instance.blendUIPatchIntoUIImage(
                currentImage,
                finalPatch,
                expandedBox,
                polygon,
              );

              // Dispose the previous intermediate result
              if (previousImage != originalImage) {
                ImageDisposalUtil.disposeImage(previousImage);
              }
            } else {
              // For the first polygon, blend directly into the original image
              currentImage =
                  await ImageProcessingService.instance.blendUIPatchIntoUIImage(
                originalImage,
                finalPatch,
                expandedBox,
                polygon,
              );
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
