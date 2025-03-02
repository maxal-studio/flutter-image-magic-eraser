import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service for handling image processing operations
class ImageProcessingService {
  ImageProcessingService._internal();

  static final ImageProcessingService _instance =
      ImageProcessingService._internal();

  /// Returns the singleton instance of the service
  static ImageProcessingService get instance => _instance;

  /// Resizes the input image to the specified dimensions
  Future<ui.Image> resizeImage(
      ui.Image image, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect =
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    return picture.toImage(targetWidth, targetHeight);
  }

  /// Converts an image to grayscale
  Future<ui.Image> convertToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final grayBytes = Uint8List(
        pixelCount * 4); // Still RGBA format but with grayscale values

    for (int i = 0; i < pixelCount; i++) {
      // Convert RGB to grayscale using standard luminance formula
      final r = rgbaBytes[i * 4];
      final g = rgbaBytes[i * 4 + 1];
      final b = rgbaBytes[i * 4 + 2];
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

      // If blackNWhite is true, convert all non-black/white colors to white
      int finalGray = gray;
      if (blackNWhite) {
        // Consider pixels as black if they're very dark (below threshold)
        // Otherwise convert to white
        finalGray = gray < threshold ? 0 : 255;
      } else {
        finalGray = gray;
      }

      // Set all RGB channels to the same grayscale value
      grayBytes[i * 4] = finalGray; // R
      grayBytes[i * 4 + 1] = finalGray; // G
      grayBytes[i * 4 + 2] = finalGray; // B
      grayBytes[i * 4 + 3] = rgbaBytes[i * 4 + 3]; // Keep original alpha
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        grayBytes, image.width, image.height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  /// Converts an image into a floating-point tensor
  Future<List<double>> imageToFloatTensor(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final floats = List<double>.filled(pixelCount * 3, 0);

    // Extract and normalize RGB channels
    for (int i = 0; i < pixelCount; i++) {
      floats[i] = rgbaBytes[i * 4] / 255.0; // Red
      floats[pixelCount + i] = rgbaBytes[i * 4 + 1] / 255.0; // Green
      floats[2 * pixelCount + i] = rgbaBytes[i * 4 + 2] / 255.0; // Blue
    }

    return floats;
  }

  /// Converts a mask image into a floating-point tensor
  Future<List<double>> maskToFloatTensor(ui.Image maskImage) async {
    final byteData =
        await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get mask ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = maskImage.width * maskImage.height;
    final floats = List<double>.filled(pixelCount, 0);

    // For mask, we need to ensure it's truly binary (0 or 1)
    // We'll use a threshold of 128 (mid-gray) to determine if a pixel is white or black
    for (int i = 0; i < pixelCount; i++) {
      // Calculate grayscale value using standard luminance formula
      final r = rgbaBytes[i * 4];
      final g = rgbaBytes[i * 4 + 1];
      final b = rgbaBytes[i * 4 + 2];
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b);

      // Apply threshold to get binary value (0 or 1)
      floats[i] = luminance > 128 ? 1.0 : 0.0;
    }

    if (kDebugMode) {
      // Log some statistics about the mask
      int nonZeroCount = 0;
      for (int i = 0; i < pixelCount; i++) {
        if (floats[i] > 0) nonZeroCount++;
      }
      final percentNonZero = (nonZeroCount / pixelCount) * 100;
      log('Mask statistics: $nonZeroCount/$pixelCount non-zero pixels (${percentNonZero.toStringAsFixed(2)}%)',
          name: 'ImageProcessingService');
    }

    return floats;
  }

  /// Converts an RGB tensor output to a UI image
  Future<ui.Image> rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    // Get dimensions from the tensor
    final height = rgbOutput[0].length;
    final width = rgbOutput[0][0].length;

    if (kDebugMode) {
      log('Converting tensor with dimensions: ${rgbOutput.length}x${height}x$width',
          name: 'ImageProcessingService');
    }

    // Create the output RGBA bytes
    final outputRgbaBytes = Uint8List(width * height * 4);

    // Process each pixel - direct conversion without any manipulations
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;

        // Get RGB values directly from the tensor
        // Assuming values are in [0,255] range - if not, they'll be clamped
        outputRgbaBytes[i] = rgbOutput[0][y][x].round().clamp(0, 255); // R
        outputRgbaBytes[i + 1] = rgbOutput[1][y][x].round().clamp(0, 255); // G
        outputRgbaBytes[i + 2] = rgbOutput[2][y][x].round().clamp(0, 255); // B
        outputRgbaBytes[i + 3] = 255; // Alpha (fully opaque)
      }
    }

    // Create a ui.Image from the RGBA bytes
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        outputRgbaBytes, width, height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  /// Resizes the RGB output to match the original image dimensions
  List<List<List<double>>> resizeRGBOutput(
      List output, int originalWidth, int originalHeight) {
    // Get the actual dimensions of the model output
    final channels = output.length;
    final outputHeight = output[0].length;
    final outputWidth = output[0][0].length;

    if (kDebugMode) {
      log('RGB Model output dimensions: ${channels}x${outputHeight}x$outputWidth',
          name: 'ImageProcessingService');
      log('Target dimensions: ${originalWidth}x$originalHeight',
          name: 'ImageProcessingService');
    }

    // Create a 3D list for RGB channels
    final resizedOutput = List.generate(
      channels,
      (_) => List.generate(
        originalHeight,
        (_) => List.filled(originalWidth, 0.0),
      ),
    );

    // Resize each channel
    for (int c = 0; c < channels; c++) {
      for (int y = 0; y < originalHeight; y++) {
        for (int x = 0; x < originalWidth; x++) {
          // Scale coordinates based on actual output dimensions
          final scaledX = (x * outputWidth / originalWidth).floor();
          final scaledY = (y * outputHeight / originalHeight).floor();

          // Ensure we don't go out of bounds
          final safeX = scaledX.clamp(0, outputWidth - 1);
          final safeY = scaledY.clamp(0, outputHeight - 1);

          resizedOutput[c][y][x] = output[c][safeY][safeX];
        }
      }
    }

    return resizedOutput;
  }
}
