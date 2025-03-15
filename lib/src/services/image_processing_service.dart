import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/bounding_box.dart';
import 'image_processing/grayscale_processor.dart';
import 'image_processing/tensor_processor.dart';
import 'image_processing/resize_processor.dart';

/// Service for handling image processing operations
class ImageProcessingService {
  ImageProcessingService._internal();

  static final ImageProcessingService _instance =
      ImageProcessingService._internal();

  /// Returns the singleton instance of the service
  static ImageProcessingService get instance => _instance;

  /// Resizes the input image to the specified dimensions
  Future<ui.Image> resizeUIImage(
      ui.Image image, int targetWidth, int targetHeight) async {
    return ResizeProcessor.resizeUIImage(image, targetWidth, targetHeight);
  }

  /// Converts an image to grayscale
  Future<ui.Image> convertUIImageToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    return GrayscaleProcessor.convertUIImageToGrayscale(
      image,
      blackNWhite: blackNWhite,
      threshold: threshold,
    );
  }

  /// Converts an image into a floating-point tensor
  Future<List<double>> convertUIImageToFloatTensor(ui.Image image) async {
    return TensorProcessor.convertUIImageToFloatTensor(image);
  }

  /// Converts a mask image into a floating-point tensor
  Future<List<double>> convertUIMaskToFloatTensor(ui.Image maskImage) async {
    return TensorProcessor.convertUIMaskToFloatTensor(maskImage);
  }

  /// Converts an RGB tensor output to a UI image
  Future<ui.Image> rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    return TensorProcessor.rgbTensorToUIImage(rgbOutput);
  }

  /// Resizes the RGB output to match the original image dimensions
  List<List<List<double>>> resizeRGBOutput(
      List<List<List<double>>> output, int originalWidth, int originalHeight) {
    return ResizeProcessor.resizeRGBOutput(
        output, originalWidth, originalHeight);
  }

  /// Asynchronous version of resizeRGBOutput that uses compute for large images
  Future<List<List<List<double>>>> resizeRGBOutputAsync(
      List<List<List<double>>> output,
      int originalWidth,
      int originalHeight) async {
    return ResizeProcessor.resizeRGBOutputAsync(
        output, originalWidth, originalHeight);
  }

  /// Blends an inpainted patch back into the original image
  ///
  /// This method draws the inpainted patch only within the polygon area,
  /// ensuring that only the masked region is affected by the inpainting.
  Future<ui.Image> blendUIPatchIntoUIImage(
    ui.Image originalImage,
    ui.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

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
}
