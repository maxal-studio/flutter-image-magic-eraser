import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'models.dart' as tensor_models;

/// Handles tensor-related image processing operations
class TensorProcessor {
  /// Converts an image into a floating-point tensor
  static Future<List<double>> convertUIImageToFloatTensor(
      ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;

    // Process in isolate for better performance
    return compute(
      _uiImageToFloatTensorIsolate,
      tensor_models.TensorParams(rgbaBytes: rgbaBytes, pixelCount: pixelCount),
    );
  }

  /// Converts a mask image into a floating-point tensor
  static Future<List<double>> convertUIMaskToFloatTensor(
      ui.Image maskImage) async {
    final byteData =
        await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get mask ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = maskImage.width * maskImage.height;

    // Process in isolate for better performance
    final result = await compute(
      _uiMaskToFloatTensorIsolate,
      tensor_models.MaskParams(
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
      tensor_models.RgbTensorParams(
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

  /// Converts an img.Image to a floating-point tensor
  ///
  /// This method converts an image package Image directly to a float tensor,
  /// avoiding the creation of intermediate ui.Image objects.
  ///
  /// - [image]: The img.Image to convert
  /// - Returns: A list of floating-point values representing the RGB channels
  static Future<List<double>> imgImageToFloatTensor(img.Image image) async {
    if (kDebugMode) {
      log('Converting image to tensor with dimensions: ${image.width}x${image.height}',
          name: 'TensorProcessor');
      log('Image format: ${image.format}, Channels: ${image.numChannels}',
          name: 'TensorProcessor');
    }

    // Ensure we have an RGBA image
    img.Image rgbaImage;
    if (image.numChannels != 4) {
      if (kDebugMode) {
        log('Converting image to RGBA format', name: 'TensorProcessor');
      }
      // Create a new RGBA image
      rgbaImage =
          img.Image(width: image.width, height: image.height, numChannels: 4);

      // Copy the RGB data and add alpha channel
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          rgbaImage.setPixel(
              x, y, img.ColorRgba8(r, g, b, 255)); // Alpha (fully opaque)
        }
      }
    } else {
      rgbaImage = image;
    }

    final pixelCount = rgbaImage.width * rgbaImage.height;
    final rgbaBytes = rgbaImage.data!.buffer.asUint8List();

    if (rgbaBytes.length != pixelCount * 4) {
      throw Exception(
        "Invalid RGBA data: expected ${pixelCount * 4} bytes, got ${rgbaBytes.length}",
      );
    }

    // Process in isolate for better performance
    return compute(
      _uiImageToFloatTensorIsolate,
      tensor_models.TensorParams(
        rgbaBytes: rgbaBytes,
        pixelCount: pixelCount,
      ),
    );
  }

  /// Converts an RGB tensor to img.Image
  ///
  /// This method processes the RGB tensor output and converts it directly into
  /// an img.Image object, avoiding the creation of intermediate ui.Image objects.
  ///
  /// - [rgbOutput]: The RGB tensor output from the model.
  /// - Returns: An img.Image object containing the RGBA pixel data.
  static Future<img.Image> rgbTensorToImgImage(
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
      tensor_models.RgbTensorParams(
        rgbOutput: rgbOutput,
        width: width,
        height: height,
      ),
    );

    // Create an img.Image from the RGBA bytes
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: outputRgbaBytes.buffer,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Converts an img.Image mask to a float tensor
  ///
  /// This method converts a binary mask image directly to a float tensor,
  /// ensuring the output is purely black and white (0.0 or 1.0).
  ///
  /// - [mask]: The img.Image mask to convert
  /// - Returns: A list of floating-point values (0.0 or 1.0) representing the binary mask
  static Future<List<double>> imgMaskToFloatTensor(img.Image mask) async {
    if (kDebugMode) {
      log('Converting mask to tensor with dimensions: ${mask.width}x${mask.height}',
          name: 'TensorProcessor');
    }

    final pixelCount = mask.width * mask.height;
    final rgbaBytes = mask.data!.buffer.asUint8List();

    if (rgbaBytes.length != pixelCount * 4) {
      throw Exception(
        "Invalid RGBA data: expected ${pixelCount * 4} bytes, got ${rgbaBytes.length}",
      );
    }

    // Process in isolate for better performance
    final result = await compute(
      _uiMaskToFloatTensorIsolate,
      tensor_models.MaskParams(
        rgbaBytes: rgbaBytes,
        pixelCount: pixelCount,
        debugMode: kDebugMode,
      ),
    );

    if (kDebugMode && result.debugInfo != null) {
      log('Mask tensor conversion complete. ${result.debugInfo}',
          name: 'TensorProcessor');
    }

    return result.floats;
  }
}

/// Converts an image to a float tensor in an isolate
List<double> _uiImageToFloatTensorIsolate(tensor_models.TensorParams params) {
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

/// Isolate function to convert RGBA bytes to a float tensor for mask
tensor_models.MaskResult _uiMaskToFloatTensorIsolate(
    tensor_models.MaskParams params) {
  if (params.debugMode) {
    log('Starting mask tensor conversion in isolate', name: 'TensorProcessor');
  }

  final rgbaBytes = params.rgbaBytes;
  final pixelCount = params.pixelCount;
  final result = List<double>.filled(pixelCount, 0.0);
  int nonZeroCount = 0;

  if (params.debugMode) {
    log('Processing $pixelCount pixels for mask tensor',
        name: 'TensorProcessor');
  }

  for (int i = 0; i < pixelCount; i++) {
    final byteIndex = i * 4;
    if (byteIndex + 2 >= rgbaBytes.length) {
      if (params.debugMode) {
        log('Warning: Reached end of bytes array prematurely',
            name: 'TensorProcessor');
      }
      break;
    }

    // Calculate luminance using standard coefficients
    final r = rgbaBytes[byteIndex] / 255.0;
    final g = rgbaBytes[byteIndex + 1] / 255.0;
    final b = rgbaBytes[byteIndex + 2] / 255.0;
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;

    // Convert to binary (0.0 or 1.0) using threshold
    result[i] = luminance > 0.5 ? 1.0 : 0.0;
    if (result[i] > 0.0) nonZeroCount++;
  }

  String? debugInfo;
  if (params.debugMode) {
    final percentNonZero = (nonZeroCount / pixelCount) * 100;
    debugInfo =
        '$nonZeroCount/$pixelCount non-zero pixels (${percentNonZero.toStringAsFixed(2)}%)';
    log('Mask tensor conversion complete. $debugInfo', name: 'TensorProcessor');
  }

  return tensor_models.MaskResult(floats: result, debugInfo: debugInfo);
}

/// Converts an RGB tensor to RGBA bytes in an isolate
Uint8List _rgbTensorToRgbaIsolate(tensor_models.RgbTensorParams params) {
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
