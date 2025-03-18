import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/src/services/image_processing/models.dart';
import 'package:image_magic_eraser/src/utils/image_disposal_util.dart';

/// Handles mask generation operations
class MaskProcessor {
  /// Generates a mask image from a list of polygons
  ///
  /// [polygons] is a list of lists, each inner list containing points as maps with 'x' and 'y' keys
  /// Each polygon should have at least 3 points to be valid
  /// [width] and [height] are the dimensions of the mask image
  /// [strokeWidth] is the width of the strokes for outlines (default: 10.0)
  /// [backgroundColor] is the color of the background (default: black)
  /// [fillColor] is the color of the filled polygons (default: white)
  /// [drawOutline] determines whether to draw an outline around the polygons (default: false)
  static Future<ui.Image> generateUIImageMask(
    List<List<Map<String, double>>> polygons,
    int width,
    int height, {
    double strokeWidth = 0,
    Color backgroundColor = Colors.black,
    Color fillColor = Colors.white,
    bool drawOutline = false,
  }) async {
    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill the canvas with the background color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()
        ..color = backgroundColor
        ..isAntiAlias = false, // Disable anti-aliasing for crisp edges
    );

    // Draw each polygon
    for (final points in polygons) {
      // Skip polygons with less than 3 points
      if (points.length < 3) {
        if (kDebugMode) {
          log('Skipping invalid polygon with ${points.length} points',
              name: 'MaskGenerationService');
        }
        continue;
      }

      // Create a fill paint for the polygon
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = false; // Disable anti-aliasing for crisp edges

      // Create a path for the polygon
      final uiPath = Path();

      // Start at the first point
      uiPath.moveTo(points[0]['x']!.toDouble(), points[0]['y']!.toDouble());

      // Add lines to each subsequent point
      for (int i = 1; i < points.length; i++) {
        uiPath.lineTo(points[i]['x']!.toDouble(), points[i]['y']!.toDouble());
      }

      // Close the path to form a polygon
      uiPath.close();

      // Fill the polygon
      canvas.drawPath(uiPath, fillPaint);

      // Draw outline if requested
      if (drawOutline) {
        final outlinePaint = Paint()
          ..color = fillColor.withValues(alpha: 0.8)
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = false; // Disable anti-aliasing for crisp edges

        canvas.drawPath(uiPath, outlinePaint);
      }
    }

    // End recording and convert to an image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);

    if (kDebugMode) {
      log('Generated mask with dimensions: ${width}x$height',
          name: 'MaskGenerationService');
    }

    return image;
  }

  /// Converts a mask image to bytes
  static Future<Uint8List> maskImageToBytes(ui.Image maskImage) async {
    final byteData = await maskImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception("Failed to get mask ByteData");

    return byteData.buffer.asUint8List();
  }

  /// Debug method to generate a mask image for visualization
  ///
  /// This method generates a mask image and returns it as a Flutter Image widget
  /// for debugging purposes.
  ///
  /// [polygons] is a list of lists, each inner list containing points as maps with 'x' and 'y' keys
  /// [width] and [height] are the dimensions of the mask image
  /// [strokeWidth] is the width of the strokes for outlines (default: 3.0)
  /// [backgroundColor] is the color of the background (default: transparent)
  /// [fillColor] is the color of the filled polygons (default: red with 50% opacity)
  /// [drawOutline] determines whether to draw an outline around the polygons (default: true)
  static Future<Image> generateDebugMask(
    List<List<Map<String, double>>> polygons,
    int width,
    int height, {
    double strokeWidth = 0,
    Color backgroundColor = Colors.black,
    Color fillColor = Colors.white,
    bool drawOutline = false,
  }) async {
    // Generate the mask image
    final maskImage = await generateUIImageMask(
      polygons,
      width,
      height,
      strokeWidth: strokeWidth,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      drawOutline: drawOutline,
    );

    // Convert the mask image to bytes
    final bytes = await maskImageToBytes(maskImage);

    // Dispose the maskImage since we have the bytes now
    ImageDisposalUtil.disposeImage(maskImage);

    // Return the mask image as a Flutter Image widget
    return Image.memory(
      bytes,
      width: width.toDouble(),
      height: height.toDouble(),
      fit: BoxFit.contain,
    );
  }

  /// Generates a mask from polygons using the image package
  ///
  /// - [polygons]: List of polygons to draw
  /// - [width]: Width of the mask
  /// - [height]: Height of the mask
  /// - Returns: An img.Image containing the mask
  static Future<img.Image> generateMaskImage(
    List<List<Map<String, double>>> polygons,
    int width,
    int height,
  ) async {
    return compute(
      _generateMaskImageIsolate,
      MaskImageParams(polygons, width, height),
    );
  }

  /// Isolate function for generating a mask
  static img.Image _generateMaskImageIsolate(MaskImageParams params) {
    if (kDebugMode) {
      log('Generating mask with dimensions: ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    final width = params.width;
    final height = params.height;
    final polygons = params.polygons;

    if (kDebugMode) {
      log('Generating mask with dimensions: $width x $height',
          name: 'ImagePackageService');
    }

    // Create a new RGBA image with 4 channels
    final img.Image mask =
        img.Image(width: width, height: height, numChannels: 4);

    final bgColor = img.ColorRgba8(0, 0, 0, 255); // Pure black
    final fillColorRgba = img.ColorRgba8(255, 255, 255, 255); // Pure white

    // Fill with background color
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        mask.setPixel(x, y, bgColor);
      }
    }

    // Draw each polygon
    for (final polygon in polygons) {
      if (polygon.length < 3) {
        continue;
      }

      // Convert polygon points to list of points
      final points = polygon.map((point) {
        return img.Point(
          point['x']!.round(),
          point['y']!.round(),
        );
      }).toList();

      // Fill the polygon with the fill color
      img.fillPolygon(
        mask,
        vertices: points,
        color: fillColorRgba,
      );
    }

    // Ensure the image data is properly initialized
    if (mask.data == null) {
      throw Exception('Failed to generate mask: image data is null');
    }

    return mask;
  }
}
