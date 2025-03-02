import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Handles grayscale image processing operations
class GrayscaleProcessor {
  /// Converts an image to grayscale
  static Future<ui.Image> convertToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;

    // Process pixels in an isolate for better performance
    final grayBytes = await compute(
      _processGrayscalePixels,
      GrayscaleParams(
        rgbaBytes: rgbaBytes,
        pixelCount: pixelCount,
        blackNWhite: blackNWhite,
        threshold: threshold,
      ),
    );

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        grayBytes, image.width, image.height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }
}

/// Processes grayscale pixels in an isolate
Uint8List _processGrayscalePixels(GrayscaleParams params) {
  final grayBytes = Uint8List(params.pixelCount * 4);

  // Use a more efficient loop structure
  for (int i = 0, j = 0; i < params.pixelCount; i++, j += 4) {
    // Convert RGB to grayscale using standard luminance formula
    final r = params.rgbaBytes[j];
    final g = params.rgbaBytes[j + 1];
    final b = params.rgbaBytes[j + 2];
    final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

    // If blackNWhite is true, convert all non-black/white colors to white
    final finalGray =
        params.blackNWhite ? (gray < params.threshold ? 0 : 255) : gray;

    // Set all RGB channels to the same grayscale value
    grayBytes[j] = finalGray; // R
    grayBytes[j + 1] = finalGray; // G
    grayBytes[j + 2] = finalGray; // B
    grayBytes[j + 3] = params.rgbaBytes[j + 3]; // Keep original alpha
  }

  return grayBytes;
}
