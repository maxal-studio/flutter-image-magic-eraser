import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image_magic_eraser/src/services/image_processing/models.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Handles image resizing operations
class CropProcessor {
  /// Crops an image to the specified rectangle
  ///
  /// - [image]: The input image to crop
  /// - [box]: The bounding box of the crop region
  /// - Returns: A new cropped image
  static Future<ui.Image> cropUIImage(
    ui.Image image,
    BoundingBox box,
  ) async {
    try {
      final x = box.x;
      final y = box.y;
      final width = box.width;
      final height = box.height;

      // Ensure the crop rectangle is within the image bounds
      final safeX = x.clamp(0, image.width - 1);
      final safeY = y.clamp(0, image.height - 1);
      final safeWidth = width.clamp(1, image.width - safeX);
      final safeHeight = height.clamp(1, image.height - safeY);

      if (kDebugMode &&
          (safeX != x ||
              safeY != y ||
              safeWidth != width ||
              safeHeight != height)) {
        log('Adjusted crop rectangle from ($x,$y,$width,$height) to ($safeX,$safeY,$safeWidth,$safeHeight)',
            name: 'PolygonInpaintingService');
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the portion of the image we want to crop
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(safeX.toDouble(), safeY.toDouble(), safeWidth.toDouble(),
            safeHeight.toDouble()),
        Rect.fromLTWH(0, 0, safeWidth.toDouble(), safeHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      return await picture.toImage(safeWidth, safeHeight);
    } catch (e) {
      if (kDebugMode) {
        log('Error in _cropImage: $e',
            name: 'PolygonInpaintingService', error: e);
      }
      rethrow;
    }
  }

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
