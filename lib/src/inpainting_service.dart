import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'mappers/input_size.dart';
import 'mappers/inpainting_config.dart';
import 'services/mask_generation_service.dart';
import 'services/onnx_model_service.dart';
import 'services/polygon_inpainting_service.dart';

export 'mappers/input_size.dart';
export 'mappers/inpainting_config.dart';

/// Main service for image inpainting
class InpaintingService {
  InpaintingService._internal();

  static final InpaintingService _instance = InpaintingService._internal();

  static InpaintingService get instance => _instance;

  // LaMa model expects 512x512 input images by default
  InputSize _modelInputSize = const InputSize(width: 512, height: 512);

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
  InputSize get modelInputSize => _modelInputSize;

  /// Set model input size
  void setModelInputSize(InputSize size) {
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
  /// This function processes the input image and inpaints only the areas defined by the polygons,
  /// returning a new image with the masked areas inpainted. The inpainting is applied precisely
  /// within the polygon boundaries, ensuring that only the masked regions are affected.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [polygons]: A list of lists, each inner list containing at least 3 points as maps with 'x' and 'y' keys.
  /// - [config]: Configuration parameters for the inpainting algorithm.
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
  /// final inpaintedImage = await inpaint(imageBytes, polygons);
  /// ```
  Future<ui.Image> inpaint(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    if (!isModelLoaded()) {
      throw Exception("ONNX model not initialized. Call initializeOrt first.");
    }

    try {
      // Use a default configuration with no feathering if none is provided
      final effectiveConfig = config ?? const InpaintingConfig();

      // Use the PolygonInpaintingService to process the polygons
      return await PolygonInpaintingService.instance.inpaintPolygons(
        imageBytes,
        polygons,
        config: effectiveConfig,
      );
    } catch (e) {
      if (kDebugMode) {
        log('Error inpainting with polygons: $e',
            name: "InpaintingService", error: e);
      }
      rethrow;
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

  /// Generates a debug visualization of the inpainting process
  ///
  /// This method generates an image showing the bounding boxes and masks
  /// for each polygon.
  ///
  /// [imageBytes] is the original image
  /// [polygons] is a list of polygons, each containing a list of points
  /// [config] is the configuration for the inpainting algorithm
  Future<ui.Image> generateDebugVisualization(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    return await PolygonInpaintingService.instance.generateDebugVisualization(
      imageBytes,
      polygons,
      config: config,
    );
  }

  /// Generates debug images for each step of the inpainting process
  ///
  /// This method returns a map of debug images for each step of the inpainting process:
  /// - 'original': The original input image
  /// - 'cropped': The cropped image from the bounding box
  /// - 'mask': The mask generated for the polygon
  /// - 'resized_image': The resized image (if resizing was needed)
  /// - 'resized_mask': The resized mask (if resizing was needed)
  /// - 'inpainted_patch_raw': The raw inpainted patch from the model
  /// - 'inpainted_patch_resized': The resized inpainted patch (if resizing was needed)
  /// - 'inpainted_patch': The final inpainted patch
  /// - 'blended': Visualization of how the patch is blended into the original image
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [polygons]: A list of lists, each inner list containing at least 3 points as maps with 'x' and 'y' keys.
  /// - [config]: Configuration parameters for the inpainting algorithm.
  /// - Returns: A map of debug images.
  Future<Map<String, ui.Image>> generateDebugImages(
    Uint8List imageBytes,
    List<List<Map<String, double>>> polygons, {
    InpaintingConfig? config,
  }) async {
    if (!isModelLoaded()) {
      throw Exception("ONNX model not initialized. Call initializeOrt first.");
    }

    try {
      return await PolygonInpaintingService.instance.generateDebugImages(
        imageBytes,
        polygons,
        config: config,
      );
    } catch (e) {
      if (kDebugMode) {
        log('Error generating debug images: $e',
            name: "InpaintingService", error: e);
      }
      rethrow;
    }
  }
}
