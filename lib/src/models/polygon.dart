import 'package:flutter/material.dart';

/// Represents a polygon drawn on an image
class Polygon {
  /// List of points that make up the polygon
  final List<Offset> points;

  /// Color of the polygon stroke
  final Color strokeColor;

  /// Width of the polygon stroke
  final double strokeWidth;

  /// Color to fill the polygon with
  final Color fillColor;

  /// Whether the polygon is closed
  final bool isClosed;

  /// Creates a new polygon
  Polygon({
    required this.points,
    this.strokeColor = Colors.red,
    this.strokeWidth = 2.0,
    this.fillColor = const Color.fromRGBO(255, 0, 0, 0.2),
    this.isClosed = true,
  });

  /// Creates a copy of this polygon with the given fields replaced
  Polygon copyWith({
    List<Offset>? points,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    bool? isClosed,
  }) {
    return Polygon(
      points: points ?? this.points,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      fillColor: fillColor ?? this.fillColor,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  /// Converts the polygon to a format compatible with the inpainting service
  List<Map<String, double>> toInpaintingFormat() {
    return points
        .map((point) => {
              'x': point.dx,
              'y': point.dy,
            })
        .toList();
  }

  /// Creates a polygon from a list of points in the inpainting format
  static Polygon fromInpaintingFormat(
    List<Map<String, double>> points, {
    Color strokeColor = Colors.red,
    double strokeWidth = 2.0,
    Color fillColor = const Color.fromRGBO(255, 0, 0, 0.2),
    bool isClosed = true,
  }) {
    return Polygon(
      points: points.map((point) => Offset(point['x']!, point['y']!)).toList(),
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      fillColor: fillColor,
      isClosed: isClosed,
    );
  }
}
