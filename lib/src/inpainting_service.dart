import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'services/image_processing_service.dart';
import 'services/mask_generation_service.dart';
import 'services/onnx_model_service.dart';

/// Main service for image inpainting
class InpaintingService {
  InpaintingService._internal();

  static final InpaintingService _instance = InpaintingService._internal();

  static InpaintingService get instance => _instance;

  // LaMa model expects 512x512 input images by default
  int _modelInputSize = 512;

  /// Initializes the ONNX environment and creates a session.
  ///
  /// This method should be called once before using the inpaint methods.
  /// It runs in an isolate to prevent UI freezing.
  Future<void> initializeOrt(String modelPath) async {
    try {
      await OnnxModelService.instance.initializeModel(modelPath);

      if (kDebugMode) {
        log('Inpainting service initialized successfully.',
            name: "InpaintingService");
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error initializing inpainting service: $e',
            name: "InpaintingService", error: e);
      }
      rethrow;
    }
  }

  /// Get model input size
  int get modelInputSize => _modelInputSize;

  /// Set model input size
  void setModelInputSize(int size) {
    _modelInputSize = size;
  }

  /// Check if the model is already loaded
  bool isModelLoaded() {
    return OnnxModelService.instance.isModelLoaded();
  }

  /// Dispose of resources when the service is no longer needed
  void dispose() {
    OnnxModelService.instance.dispose();
    if (kDebugMode) {
      log('Inpainting service disposed.', name: "InpaintingService");
    }
  }

  /// Inpaints the masked areas of an image using polygons defined by points.
  ///
  /// This function processes the input image and inpaints the areas defined by the polygons,
  /// returning a new image with the masked areas inpainted.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [polygons]: A list of lists, each inner list containing at least 3 points as maps with 'x' and 'y' keys.
  /// - [strokeWidth]: The width of the strokes for outlines if needed (default: 5.0).
  /// - Returns: A [ui.Image] with the masked areas inpainted.
  ///
  /// Example usage:
  /// ```dart
  /// final imageBytes = await File('path_to_image').readAsBytes();
  /// final polygons = [
  ///   [
  ///     {'x': 100.0, 'y': 100.0},
  ///     {'x': 300.0, 'y': 100.0},
  ///     {'x': 200.0, 'y': 300.0},
  ///   ],
  /// ];
  /// final inpaintedImage = await inpaintWithPolygons(imageBytes, polygons);
  /// ```
  Future<ui.Image> inpaintWithPolygons(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons,
  ) async {
    if (!isModelLoaded()) {
      throw Exception("ONNX model not initialized. Call initializeOrt first.");
    }

    try {
      // Decode the input image
      final originalImage = await decodeImageFromList(imageBytes);
      if (kDebugMode) {
        log('Original image size: ${originalImage.width}x${originalImage.height}',
            name: 'InpaintingService');
      }

      // Generate mask image from polygons
      final maskImage = await MaskGenerationService.instance
          .generateMask(polygons, originalImage.width, originalImage.height);

      // Convert mask to bytes
      final maskBytes =
          await MaskGenerationService.instance.maskImageToBytes(maskImage);

      // Inpaint using the generated mask
      return await inpaint(imageBytes, maskBytes);
    } catch (e) {
      if (kDebugMode) {
        log('Error inpainting with polygons: $e',
            name: "InpaintingService", error: e);
      }
      rethrow;
    }
  }

  /// Inpaints the masked areas of an image.
  ///
  /// This function processes the input image and inpaints the areas defined by the mask,
  /// returning a new image with the masked areas inpainted.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [maskBytes]: The mask image as a byte array.
  /// - Returns: A [ui.Image] with the masked areas inpainted.
  ///
  /// Example usage:
  /// ```dart
  /// final imageBytes = await File('path_to_image').readAsBytes();
  /// final maskBytes = await File('path_to_mask').readAsBytes();
  /// final inpaintedImage = await inpaint(imageBytes, maskBytes);
  /// ```
  Future<ui.Image> inpaint(Uint8List imageBytes, Uint8List maskBytes,
      {bool debug = false}) async {
    if (!isModelLoaded()) {
      throw Exception("ONNX model not initialized. Call initializeOrt first.");
    }

    try {
      // Decode the input image and resize it to the required dimensions
      final originalImage = await decodeImageFromList(imageBytes);
      if (kDebugMode) {
        log('Original image size: ${originalImage.width}x${originalImage.height}',
            name: 'InpaintingService');
      }

      final resizedImage = await ImageProcessingService.instance
          .resizeImage(originalImage, _modelInputSize, _modelInputSize);

      // Decode the mask image and resize it to the required dimensions
      final originalMask = await decodeImageFromList(maskBytes);
      if (kDebugMode) {
        log('Original mask size: ${originalMask.width}x${originalMask.height}',
            name: 'InpaintingService');
      }

      final resizedMask = await ImageProcessingService.instance
          .resizeImage(originalMask, _modelInputSize, _modelInputSize);

      // Convert mask to grayscale if it's not already
      final grayscaleMask =
          await ImageProcessingService.instance.convertToGrayscale(
        resizedMask,
        blackNWhite: true,
        threshold: 50,
      );

      if (kDebugMode) {
        log('Converted mask to grayscale', name: 'InpaintingService');
      }

      // Convert the resized image into a tensor format required by the ONNX model
      final rgbFloats = await ImageProcessingService.instance
          .imageToFloatTensor(resizedImage);
      final imageTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(rgbFloats),
        [1, 3, _modelInputSize, _modelInputSize],
      );

      // Convert the grayscale mask into a tensor format required by the ONNX model
      final maskFloats = await ImageProcessingService.instance
          .maskToFloatTensor(grayscaleMask);
      final maskTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(maskFloats),
        [1, 1, _modelInputSize, _modelInputSize],
      );

      // Prepare the inputs and run inference on the ONNX model
      final inputs = {
        'image': imageTensor,
        'mask': maskTensor,
      };

      final outputs = await OnnxModelService.instance.runInference(inputs);

      // Release tensors
      imageTensor.release();
      maskTensor.release();

      // Process the output tensor and generate the final image
      final outputTensor = outputs?[0]?.value;
      if (outputTensor is List) {
        final output = outputTensor[0]; // This should be RGB channels
        if (kDebugMode) {
          log('Output tensor shape: ${output.length} channels',
              name: 'InpaintingService');
          log('Processing RGB output from LaMa model',
              name: 'InpaintingService');
        }

        final resizedOutput = ImageProcessingService.instance
            .resizeRGBOutput(output, originalImage.width, originalImage.height);

        final inpaintedImage = await ImageProcessingService.instance
            .rgbTensorToUIImage(resizedOutput);
        return inpaintedImage;
      } else {
        throw Exception('Unexpected output format from ONNX model.');
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error inpainting image: $e', name: "InpaintingService", error: e);
      }
      throw Exception('Error inpainting image: $e');
    }
  }

  /// Generates a debug mask image for visualization
  ///
  /// This method generates a mask image and returns it as a Flutter Image widget
  /// for debugging purposes.
  ///
  /// [image] is the original image to get dimensions from
  /// [polygons] is a list of polygons, each containing a list of points
  ///
  /// Example usage:
  /// ```dart
  /// final polygons = [
  ///   [
  ///     {'x': 100, 'y': 100},
  ///     {'x': 200, 'y': 100},
  ///     {'x': 150, 'y': 200},
  ///   ],
  /// ];
  /// final debugMask = await inpaintingService.generateDebugMask(image, polygons);
  /// ```
  Future<Image> generateDebugMask(
    Uint8List image,
    List<List<Map<String, double>>> polygons, {
    double strokeWidth = 0,
    Color backgroundColor = Colors.black,
    Color fillColor = Colors.white,
    bool drawOutline = false,
  }) async {
    final decodedImage = await decodeImageFromList(image);

    return MaskGenerationService.instance.generateDebugMask(
      polygons,
      decodedImage.width,
      decodedImage.height,
      strokeWidth: strokeWidth,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      drawOutline: drawOutline,
    );
  }
}
