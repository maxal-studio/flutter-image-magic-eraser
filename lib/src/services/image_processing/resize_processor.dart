import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'models.dart';

/// Handles image resizing operations
class ResizeProcessor {
  /// Resizes an image to the specified dimensions
  ///
  /// - [image]: The input image to resize
  /// - [targetWidth]: The desired width of the output image
  /// - [targetHeight]: The desired height of the output image
  /// - [useBilinear]: Whether to use bilinear interpolation for better quality (default: true)
  /// - Returns: A new resized image
  static Future<img.Image> resizeImage(
    img.Image image,
    int targetWidth,
    int targetHeight, {
    bool useBilinear = true,
  }) async {
    return compute(
      _resizeImageIsolate,
      ResizeImageParams(image, targetWidth, targetHeight, useBilinear),
    );
  }

  /// Isolate function for resizing an image
  static img.Image _resizeImageIsolate(ResizeImageParams params) {
    if (kDebugMode) {
      log('Resizing image with dimensions: ${params.image.width}x${params.image.height} to ${params.targetWidth}x${params.targetHeight}',
          name: 'ImagePackageService');
    }
    if (params.useBilinear) {
      return img.copyResize(
        params.image,
        width: params.targetWidth,
        height: params.targetHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      return img.copyResize(
        params.image,
        width: params.targetWidth,
        height: params.targetHeight,
        interpolation: img.Interpolation.nearest,
      );
    }
  }

  /// Efficiently resizes an image to the specified dimensions
  static Future<ui.Image> resizeUIImage(
    ui.Image image,
    int targetWidth,
    int targetHeight,
  ) async {
    try {
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

  /// Resizes the RGB output to match the original image dimensions
  static List<List<List<double>>> resizeRGBOutput(
      List<List<List<double>>> output, int originalWidth, int originalHeight) {
    // Get the actual dimensions of the model output
    final channels = output.length;
    final outputHeight = output[0].length;
    final outputWidth = output[0][0].length;

    if (kDebugMode) {
      log('RGB Model output dimensions: ${channels}x${outputHeight}x$outputWidth',
          name: 'ResizeProcessor');
      log('Target dimensions: ${originalWidth}x$originalHeight',
          name: 'ResizeProcessor');
    }

    // Use compute for better performance with large images
    if (originalWidth * originalHeight > 500000) {
      // Only for large images
      // For synchronous method, we can't use compute directly
      // Instead, we'll use the same algorithm but run it in the current isolate
      return _resizeRGBOutputIsolate(ResizeParams(
        output: output,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        channels: channels,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      ));
    }

    // For smaller images, process directly
    // Create a 3D list for RGB channels with proper typing
    final resizedOutput = List.generate(
      channels,
      (_) => List.generate(
        originalHeight,
        (_) => List<double>.filled(originalWidth, 0.0),
      ),
    );

    // Precompute scale factors to avoid division in inner loops
    final xScale = outputWidth / originalWidth;
    final yScale = outputHeight / originalHeight;

    // Resize each channel
    for (int c = 0; c < channels; c++) {
      for (int y = 0; y < originalHeight; y++) {
        final scaledY = (y * yScale).floor().clamp(0, outputHeight - 1);

        for (int x = 0; x < originalWidth; x++) {
          final scaledX = (x * xScale).floor().clamp(0, outputWidth - 1);
          resizedOutput[c][y][x] = output[c][scaledY][scaledX];
        }
      }
    }

    return resizedOutput;
  }

  /// Asynchronous version of resizeRGBOutput that uses compute for large images
  static Future<List<List<List<double>>>> resizeRGBOutputAsync(
      List<List<List<double>>> output,
      int originalWidth,
      int originalHeight) async {
    // Get the actual dimensions of the model output
    final channels = output.length;
    final outputHeight = output[0].length;
    final outputWidth = output[0][0].length;

    if (kDebugMode) {
      log('RGB Model output dimensions: ${channels}x${outputHeight}x$outputWidth',
          name: 'ResizeProcessor');
      log('Target dimensions: ${originalWidth}x$originalHeight',
          name: 'ResizeProcessor');
    }

    // Use compute for better performance with large images
    if (originalWidth * originalHeight > 500000) {
      // Only for large images
      return compute(
        _resizeRGBOutputIsolate,
        ResizeParams(
          output: output,
          originalWidth: originalWidth,
          originalHeight: originalHeight,
          channels: channels,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
        ),
      );
    }

    // For smaller images, process directly using the same algorithm as the synchronous version
    return _resizeRGBOutputIsolate(ResizeParams(
      output: output,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      channels: channels,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    ));
  }
}

/// Resizes RGB output in an isolate
List<List<List<double>>> _resizeRGBOutputIsolate(ResizeParams params) {
  // Create a 3D list for RGB channels
  final resizedOutput = List.generate(
    params.channels,
    (_) => List.generate(
      params.originalHeight,
      (_) => List<double>.filled(params.originalWidth, 0.0),
    ),
  );

  // Precompute scale factors
  final xScale = params.outputWidth / params.originalWidth;
  final yScale = params.outputHeight / params.originalHeight;

  // Resize each channel
  for (int c = 0; c < params.channels; c++) {
    for (int y = 0; y < params.originalHeight; y++) {
      final scaledY = (y * yScale).floor().clamp(0, params.outputHeight - 1);

      for (int x = 0; x < params.originalWidth; x++) {
        final scaledX = (x * xScale).floor().clamp(0, params.outputWidth - 1);
        resizedOutput[c][y][x] = params.output[c][scaledY][scaledX];
      }
    }
  }

  return resizedOutput;
}
