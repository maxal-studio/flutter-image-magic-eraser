import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/src/services/image_processing/models.dart';

/// Handles image resizing operations
class CropProcessor {
  /// Crops an image to the specified dimensions
  ///
  /// - [image]: The input image to crop
  /// - [x]: The x coordinate of the top-left corner of the crop region
  /// - [y]: The y coordinate of the top-left corner of the crop region
  /// - [width]: The width of the crop region
  /// - [height]: The height of the crop region
  /// - Returns: A new cropped image
  static Future<img.Image> cropImage(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
  ) async {
    return compute(
      _cropImageIsolate,
      CropImageParams(image, x, y, width, height),
    );
  }

  /// Isolate function for cropping an image
  static img.Image _cropImageIsolate(CropImageParams params) {
    if (kDebugMode) {
      log('Cropping image with dimensions: ${params.image.width}x${params.image.height} to ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    return img.copyCrop(
      params.image,
      x: params.x,
      y: params.y,
      width: params.width,
      height: params.height,
    );
  }
}
