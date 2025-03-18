import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/src/services/image_processing/models.dart';

/// Handles image resizing operations
class BlendProcessor {
  /// Blends an inpainted patch back into the original image
  ///
  /// This method draws the inpainted patch only within the polygon area,
  /// ensuring that only the masked region is affected by the inpainting.
  static Future<ui.Image> blendUIPatchIntoUIImage(
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
  static Path _createPolygonPath(List<Map<String, double>> polygon) {
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

  /// Blends an inpainted patch into the original image using a polygon mask
  ///
  /// This method works directly with img.Image objects to blend the patch only within
  /// the polygon area, ensuring that only the masked region is affected by the inpainting.
  ///
  /// - [originalImage]: The original image as img.Image
  /// - [patch]: The inpainted patch as img.Image
  /// - [box]: The bounding box where the patch should be placed
  /// - [polygon]: The polygon defining the area to be inpainted
  /// - Returns: An img.Image with the patch blended into the original image
  static Future<img.Image> blendImgPatchIntoImage(
    img.Image originalImage,
    img.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    return compute(
      _blendImgPatchIntoImageIsolate,
      BlendImageParams(originalImage, patch, box, polygon, debugTag),
    );
  }

  /// Isolate function for blending a patch into an image
  static img.Image _blendImgPatchIntoImageIsolate(BlendImageParams params) {
    try {
      if (kDebugMode) {
        log('Blending patch into image with dimensions: ${params.originalImage.width}x${params.originalImage.height}',
            name: 'ImagePackageService');
        if (kDebugMode) {
          log('Blending patch into image with dimensions: ${params.originalImage.width}x${params.originalImage.height}',
              name: 'ImagePackageService');
          log('Patch dimensions: ${params.patch.width}x${params.patch.height}',
              name: 'ImagePackageService');
          log('Bounding box: x=${params.box.x}, y=${params.box.y}, width=${params.box.width}, height=${params.box.height}',
              name: 'ImagePackageService');
        }
      }
      final originalImage = params.originalImage;
      final patch = params.patch;
      final box = params.box;
      final polygon = params.polygon;

      // Create a copy of the original image to avoid modifying it
      final result = img.Image.from(originalImage);

      // For each pixel in the patch's bounding box
      for (int y = 0; y < box.height; y++) {
        final int imgY = box.y + y;
        // Skip if outside the original image bounds
        if (imgY < 0 || imgY >= originalImage.height) continue;

        for (int x = 0; x < box.width; x++) {
          final int imgX = box.x + x;
          // Skip if outside the original image bounds
          if (imgX < 0 || imgX >= originalImage.width) continue;

          // Check if the pixel is inside the polygon
          if (_isPointInPolygon(imgX.toDouble(), imgY.toDouble(), polygon)) {
            // Get the pixel color from the patch
            final patchColor = patch.getPixel(x, y);

            // Set the pixel color in the result image
            result.setPixel(imgX, imgY, patchColor);
          }
        }
      }

      return result;
    } catch (e) {
      throw Exception('Error in blendImgPatchIntoImage: $e');
    }
  }

  /// Checks if a point is inside a polygon using the ray casting algorithm
  static bool _isPointInPolygon(
      double x, double y, List<Map<String, double>> polygon) {
    bool inside = false;
    final int len = polygon.length;

    for (int i = 0, j = len - 1; i < len; j = i++) {
      final double xi = polygon[i]['x']!;
      final double yi = polygon[i]['y']!;
      final double xj = polygon[j]['x']!;
      final double yj = polygon[j]['y']!;

      final bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);

      if (intersect) {
        inside = !inside;
      }
    }

    return inside;
  }
}
