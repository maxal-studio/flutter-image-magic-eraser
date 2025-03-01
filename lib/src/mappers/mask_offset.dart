/// Represents a point in a mask with x and y coordinates
class MaskOffset {
  final double x;
  final double y;

  /// Creates a new mask offset with the given coordinates
  ///
  /// [x] and [y] are normalized coordinates (0.0 to 1.0) relative to the image dimensions
  MaskOffset(this.x, this.y);

  /// Creates a new mask offset with absolute pixel coordinates
  ///
  /// [x] and [y] are absolute pixel coordinates
  /// [imageWidth] and [imageHeight] are the dimensions of the image
  factory MaskOffset.fromAbsolute(
      double x, double y, double imageWidth, double imageHeight) {
    return MaskOffset(
      x / imageWidth,
      y / imageHeight,
    );
  }

  /// Converts normalized coordinates to absolute pixel coordinates
  ///
  /// [imageWidth] and [imageHeight] are the dimensions of the image
  /// Returns a map with 'x' and 'y' keys containing the absolute coordinates
  Map<String, int> toAbsolute(int imageWidth, int imageHeight) {
    return {
      'x': (x * imageWidth).round(),
      'y': (y * imageHeight).round(),
    };
  }
}
