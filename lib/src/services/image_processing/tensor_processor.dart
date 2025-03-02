import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Handles tensor-related image processing operations
class TensorProcessor {
  /// Converts an image into a floating-point tensor
  static Future<List<double>> imageToFloatTensor(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;

    // Process in isolate for better performance
    return compute(
      _imageToFloatTensorIsolate,
      TensorParams(rgbaBytes: rgbaBytes, pixelCount: pixelCount),
    );
  }

  /// Converts a mask image into a floating-point tensor
  static Future<List<double>> maskToFloatTensor(ui.Image maskImage) async {
    final byteData =
        await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get mask ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = maskImage.width * maskImage.height;

    // Process in isolate for better performance
    final result = await compute(
      _maskToFloatTensorIsolate,
      MaskParams(
        rgbaBytes: rgbaBytes,
        pixelCount: pixelCount,
        debugMode: kDebugMode,
      ),
    );

    if (kDebugMode && result.debugInfo != null) {
      log('Mask statistics: ${result.debugInfo}', name: 'TensorProcessor');
    }

    return result.floats;
  }

  /// Converts an RGB tensor output to a UI image
  static Future<ui.Image> rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    // Get dimensions from the tensor
    final height = rgbOutput[0].length;
    final width = rgbOutput[0][0].length;

    if (kDebugMode) {
      log('Converting tensor with dimensions: ${rgbOutput.length}x${height}x$width',
          name: 'TensorProcessor');
    }

    // Process in isolate for better performance
    final outputRgbaBytes = await compute(
      _rgbTensorToRgbaIsolate,
      RgbTensorParams(
        rgbOutput: rgbOutput,
        width: width,
        height: height,
      ),
    );

    // Create a ui.Image from the RGBA bytes
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        outputRgbaBytes, width, height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }
}

/// Converts an image to a float tensor in an isolate
List<double> _imageToFloatTensorIsolate(TensorParams params) {
  final floats = List<double>.filled(params.pixelCount * 3, 0);
  final pixelCount = params.pixelCount;

  // Process all channels in a single loop for better cache locality
  for (int i = 0, j = 0; i < pixelCount; i++, j += 4) {
    floats[i] = params.rgbaBytes[j] / 255.0; // Red
    floats[pixelCount + i] = params.rgbaBytes[j + 1] / 255.0; // Green
    floats[2 * pixelCount + i] = params.rgbaBytes[j + 2] / 255.0; // Blue
  }

  return floats;
}

/// Converts a mask to a float tensor in an isolate
MaskResult _maskToFloatTensorIsolate(MaskParams params) {
  final floats = List<double>.filled(params.pixelCount, 0);
  int nonZeroCount = 0;

  // Use a more efficient loop structure
  for (int i = 0, j = 0; i < params.pixelCount; i++, j += 4) {
    // Calculate grayscale value using standard luminance formula
    final r = params.rgbaBytes[j];
    final g = params.rgbaBytes[j + 1];
    final b = params.rgbaBytes[j + 2];
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b);

    // Apply threshold to get binary value (0 or 1)
    final value = luminance > 128 ? 1.0 : 0.0;
    floats[i] = value;

    if (params.debugMode && value > 0) {
      nonZeroCount++;
    }
  }

  String? debugInfo;
  if (params.debugMode) {
    final percentNonZero = (nonZeroCount / params.pixelCount) * 100;
    debugInfo =
        '$nonZeroCount/${params.pixelCount} non-zero pixels (${percentNonZero.toStringAsFixed(2)}%)';
  }

  return MaskResult(floats: floats, debugInfo: debugInfo);
}

/// Converts an RGB tensor to RGBA bytes in an isolate
Uint8List _rgbTensorToRgbaIsolate(RgbTensorParams params) {
  final outputRgbaBytes = Uint8List(params.width * params.height * 4);

  // Process in row-major order for better cache locality
  for (int y = 0; y < params.height; y++) {
    for (int x = 0; x < params.width; x++) {
      final i = (y * params.width + x) * 4;

      // Get RGB values directly from the tensor
      outputRgbaBytes[i] = params.rgbOutput[0][y][x].round().clamp(0, 255); // R
      outputRgbaBytes[i + 1] =
          params.rgbOutput[1][y][x].round().clamp(0, 255); // G
      outputRgbaBytes[i + 2] =
          params.rgbOutput[2][y][x].round().clamp(0, 255); // B
      outputRgbaBytes[i + 3] = 255; // Alpha (fully opaque)
    }
  }

  return outputRgbaBytes;
}
