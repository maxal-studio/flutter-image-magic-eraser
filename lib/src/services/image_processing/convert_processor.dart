import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/src/services/image_processing/models.dart';

/// Handles image resizing operations
class ConvertProcessor {
  /// Converts a ui.Image to an img.Image
  ///
  /// - [uiImage]: The ui.Image to convert
  /// - Returns: An img.Image representation of the image
  static Future<img.Image> convertUiImageToImage(ui.Image uiImage) async {
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();

    // Run the conversion in an isolate
    return compute(
      _convertUiToImgIsolate,
      UiToImgParams(rgbaBytes, uiImage.width, uiImage.height),
    );
  }

  /// Isolate function for converting ui.Image bytes to img.Image
  static img.Image _convertUiToImgIsolate(UiToImgParams params) {
    if (kDebugMode) {
      log('Converting ui.Image to img.Image with dimensions: ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    return img.Image.fromBytes(
      width: params.width,
      height: params.height,
      bytes: params.bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Converts an img.Image to a ui.Image
  ///
  /// - [image]: The img.Image to convert
  /// - Returns: A ui.Image representation of the image
  static Future<ui.Image> convertImageToUiImage(img.Image image) async {
    // Process the image in an isolate
    final processedBytes = await compute(
      _convertImgToUiIsolate,
      ImgToUiParams(image),
    );

    // Create a Completer to wait for the async decoding
    final Completer<ui.Image> completer = Completer();

    // Decode pixels into a ui.Image (must be done on the main thread)
    ui.decodeImageFromPixels(
      processedBytes.bytes,
      processedBytes.width,
      processedBytes.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  /// Isolate function for converting img.Image to bytes for ui.Image
  static ImageConversionResult _convertImgToUiIsolate(ImgToUiParams params) {
    if (kDebugMode) {
      log('Converting img.Image to bytes for ui.Image with dimensions: ${params.image.width}x${params.image.height}',
          name: 'ImagePackageService');
    }
    final img.Image image = params.image;

    // Ensure we have an RGBA image
    img.Image rgbaImage;
    if (image.numChannels != 4) {
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

    // Convert img.Image to Uint8List (RGBA format)
    Uint8List uint8List =
        Uint8List.fromList(rgbaImage.getBytes(order: img.ChannelOrder.rgba));

    return ImageConversionResult(uint8List, rgbaImage.width, rgbaImage.height);
  }
}
