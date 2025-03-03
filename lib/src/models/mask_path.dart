import 'mask_offset.dart';

/// Represents a path in a mask, consisting of a list of offsets forming a polygon
class MaskPath {
  final List<MaskOffset> offsets;
  final double strokeWidth;

  /// Creates a new mask path with the given offsets and stroke width
  ///
  /// [offsets] is a list of normalized coordinates (0.0 to 1.0) relative to the image dimensions
  /// [strokeWidth] is the width of the stroke in pixels (used for outline rendering if needed)
  ///
  /// Note: A valid polygon requires at least 3 points
  MaskPath(this.offsets, {this.strokeWidth = 10.0}) {
    if (offsets.length < 3) {
      throw ArgumentError('A valid polygon requires at least 3 points');
    }
  }

  /// Creates a new mask path with absolute pixel coordinates
  ///
  /// [points] is a list of maps with 'x' and 'y' keys containing absolute pixel coordinates
  /// [imageWidth] and [imageHeight] are the dimensions of the image
  /// [strokeWidth] is the width of the stroke in pixels
  ///
  /// Note: A valid polygon requires at least 3 points
  factory MaskPath.fromAbsolutePoints(
    List<Map<String, double>> points,
    double imageWidth,
    double imageHeight, {
    double strokeWidth = 10.0,
  }) {
    if (points.length < 3) {
      throw ArgumentError('A valid polygon requires at least 3 points');
    }

    return MaskPath(
      points
          .map((point) => MaskOffset.fromAbsolute(
                point['x']!,
                point['y']!,
                imageWidth,
                imageHeight,
              ))
          .toList(),
      strokeWidth: strokeWidth,
    );
  }

  /// Checks if this path forms a valid polygon (at least 3 points)
  bool isValid() {
    return offsets.length >= 3;
  }
}
