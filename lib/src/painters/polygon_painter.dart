import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../models/polygon.dart';

/// Custom painter for drawing polygons on an image
class PolygonPainter extends CustomPainter {
  /// List of polygons to draw
  final List<Polygon> polygons;

  /// Currently active polygon being drawn
  final Polygon? activePolygon;

  /// Size of the original image
  final Size imageSize;

  /// Rectangle where the image is displayed on screen
  final Rect displayRect;

  /// Enable debug mode
  final bool debug;

  /// Creates a new polygon painter
  PolygonPainter({
    required this.polygons,
    this.activePolygon,
    required this.imageSize,
    required this.displayRect,
    this.debug = false,
  });

  /// Log debug information
  void _log(String message) {
    if (debug) {
      developer.log(message, name: 'PolygonPainter');
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Only log once per paint cycle to reduce verbosity
    if (debug) {
      _log(
          'Painting with canvas size=$size, displayRect=$displayRect, imageSize=$imageSize');
      _log(
          'Number of polygons: ${polygons.length}, active polygon: ${activePolygon != null}');
    }

    // Draw a border around the image area
    if (debug) {
      _drawDebugInfo(canvas);
    }

    // Draw completed polygons
    for (final polygon in polygons) {
      _drawPolygon(canvas, polygon);
    }

    // Draw active polygon if it exists
    if (activePolygon != null) {
      _drawPolygon(canvas, activePolygon!);
    }
  }

  /// Draw debug information on the canvas
  void _drawDebugInfo(Canvas canvas) {
    // Draw a border around the image area
    final debugPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(displayRect, debugPaint);

    // Draw a crosshair at the center of the image
    final centerX = displayRect.left + displayRect.width / 2;
    final centerY = displayRect.top + displayRect.height / 2;
    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      debugPaint,
    );
    canvas.drawLine(
      Offset(centerX, centerY - 20),
      Offset(centerX, centerY + 20),
      debugPaint,
    );

    // Draw the image dimensions
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Image: ${imageSize.width.toInt()}x${imageSize.height.toInt()}',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(displayRect.left + 5, displayRect.top + 5));

    // Draw the display dimensions
    final displayTextPainter = TextPainter(
      text: TextSpan(
        text:
            'Display: ${displayRect.width.toInt()}x${displayRect.height.toInt()}',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    displayTextPainter.layout();
    displayTextPainter.paint(
        canvas, Offset(displayRect.left + 5, displayRect.top + 20));
  }

  /// Draws a single polygon
  void _drawPolygon(Canvas canvas, Polygon polygon) {
    if (polygon.points.isEmpty) return;

    // Only log once per polygon to reduce verbosity
    if (debug) {
      _log(
          'Drawing polygon with ${polygon.points.length} points, closed=${polygon.isClosed}');
    }

    // Create paint for the stroke
    final strokePaint = Paint()
      ..color = polygon.strokeColor
      ..strokeWidth = polygon.strokeWidth
      ..style = PaintingStyle.stroke;

    // Create paint for the fill
    final fillPaint = Paint()
      ..color = polygon.fillColor
      ..style = PaintingStyle.fill;

    // Create a path for the polygon
    final path = Path();

    // Convert the first point from image coordinates to screen coordinates
    final firstPoint = imageToScreenCoordinates(polygon.points.first);
    if (firstPoint == null) {
      _log('Failed to convert first point: ${polygon.points.first}');
      return;
    }

    path.moveTo(firstPoint.dx, firstPoint.dy);

    // Add lines to the remaining points, converting each one
    for (int i = 1; i < polygon.points.length; i++) {
      final screenPoint = imageToScreenCoordinates(polygon.points[i]);
      if (screenPoint == null) {
        _log('Failed to convert point at index $i: ${polygon.points[i]}');
        continue;
      }
      path.lineTo(screenPoint.dx, screenPoint.dy);
    }

    // Close the path if the polygon is closed
    if (polygon.isClosed && polygon.points.length > 2) {
      path.close();

      // Fill the polygon if it's closed
      canvas.drawPath(path, fillPaint);
    }

    // Draw the stroke
    canvas.drawPath(path, strokePaint);

    // Draw points as small circles
    final pointPaint = Paint()
      ..color = polygon.strokeColor
      ..style = PaintingStyle.fill;

    for (final point in polygon.points) {
      final screenPoint = imageToScreenCoordinates(point);
      if (screenPoint == null) continue;

      canvas.drawCircle(screenPoint, polygon.strokeWidth * 2.0, pointPaint);

      // Draw point coordinates in debug mode
      if (debug) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '(${point.dx.toInt()},${point.dy.toInt()})',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
            canvas, Offset(screenPoint.dx + 5, screenPoint.dy + 5));
      }
    }
  }

  /// Converts a point from image coordinates to screen coordinates
  /// Returns null if conversion fails
  Offset? imageToScreenCoordinates(Offset imagePoint) {
    // Validate input
    if (imagePoint.dx < 0 ||
        imagePoint.dy < 0 ||
        imagePoint.dx > imageSize.width ||
        imagePoint.dy > imageSize.height) {
      if (debug) {
        _log('Image point out of bounds: $imagePoint, imageSize: $imageSize');
      }
      return null;
    }

    // Calculate the relative position within the image (0.0 to 1.0)
    final relativeX = imagePoint.dx / imageSize.width;
    final relativeY = imagePoint.dy / imageSize.height;

    // Convert to screen coordinates
    final screenX = displayRect.left + (relativeX * displayRect.width);
    final screenY = displayRect.top + (relativeY * displayRect.height);

    return Offset(screenX, screenY);
  }

  @override
  bool shouldRepaint(covariant PolygonPainter oldDelegate) {
    return oldDelegate.polygons != polygons ||
        oldDelegate.activePolygon != activePolygon ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.displayRect != displayRect;
  }
}
