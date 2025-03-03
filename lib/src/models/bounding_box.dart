/// Represents a bounding box with position and dimensions
class BoundingBox {
  /// X-coordinate of the top-left corner
  final int x;

  /// Y-coordinate of the top-left corner
  final int y;

  /// Width of the bounding box
  final int width;

  /// Height of the bounding box
  final int height;

  /// Creates a new bounding box with the given position and dimensions
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Creates a bounding box from a list of points
  ///
  /// [points] is a list of maps with 'x' and 'y' keys
  factory BoundingBox.fromPoints(List<Map<String, double>> points) {
    if (points.isEmpty) {
      throw ArgumentError(
          'Cannot create a bounding box from an empty list of points');
    }

    double minX = points[0]['x']!;
    double minY = points[0]['y']!;
    double maxX = points[0]['x']!;
    double maxY = points[0]['y']!;

    for (final point in points) {
      if (point['x']! < minX) minX = point['x']!;
      if (point['y']! < minY) minY = point['y']!;
      if (point['x']! > maxX) maxX = point['x']!;
      if (point['y']! > maxY) maxY = point['y']!;
    }

    return BoundingBox(
      x: minX.floor(),
      y: minY.floor(),
      width: (maxX - minX).ceil(),
      height: (maxY - minY).ceil(),
    );
  }

  /// Expands the bounding box by a percentage of its size
  ///
  /// [percentage] is the percentage to expand by (e.g., 0.3 for 30%)
  /// [maxExpansion] is the maximum expansion size in pixels
  /// [imageWidth] and [imageHeight] are the dimensions of the image
  BoundingBox expand({
    required double percentage,
    required int maxExpansion,
    required int imageWidth,
    required int imageHeight,
  }) {
    // Calculate expansion size
    final expansionWidth = (width * percentage).round();
    final expansionHeight = (height * percentage).round();

    // Limit expansion to maxExpansion
    final limitedExpansionWidth =
        expansionWidth > maxExpansion ? maxExpansion : expansionWidth;
    final limitedExpansionHeight =
        expansionHeight > maxExpansion ? maxExpansion : expansionHeight;

    // Calculate new position and dimensions
    int newX = x - limitedExpansionWidth;
    int newY = y - limitedExpansionHeight;
    int newWidth = width + (limitedExpansionWidth * 2);
    int newHeight = height + (limitedExpansionHeight * 2);

    // Ensure the bounding box stays within the image bounds
    if (newX < 0) {
      newWidth += newX; // Reduce width by the amount we're out of bounds
      newX = 0;
    }

    if (newY < 0) {
      newHeight += newY; // Reduce height by the amount we're out of bounds
      newY = 0;
    }

    if (newX + newWidth > imageWidth) {
      newWidth = imageWidth - newX;
    }

    if (newY + newHeight > imageHeight) {
      newHeight = imageHeight - newY;
    }

    return BoundingBox(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Ensures the bounding box has the specified dimensions by expanding it equally in all directions
  ///
  /// [targetSize] is the desired size for both width and height
  /// [imageWidth] and [imageHeight] are the dimensions of the image
  BoundingBox ensureSize({
    required int targetSize,
    required int imageWidth,
    required int imageHeight,
  }) {
    // If the box is already larger than targetSize in both dimensions, return it as is
    if (width >= targetSize && height >= targetSize) {
      return this;
    }

    // Calculate how much we need to expand in each dimension
    final widthDiff = targetSize - width;
    final heightDiff = targetSize - height;

    // Calculate new position and dimensions
    int newX = x - (widthDiff / 2).floor();
    int newY = y - (heightDiff / 2).floor();
    int newWidth = targetSize;
    int newHeight = targetSize;

    // Ensure the bounding box stays within the image bounds
    if (newX < 0) {
      newX = 0;
    }

    if (newY < 0) {
      newY = 0;
    }

    if (newX + newWidth > imageWidth) {
      newX = imageWidth - newWidth;

      // If the image is smaller than the target size, adjust
      if (newX < 0) {
        newX = 0;
        newWidth = imageWidth;
      }
    }

    if (newY + newHeight > imageHeight) {
      newY = imageHeight - newHeight;

      // If the image is smaller than the target size, adjust
      if (newY < 0) {
        newY = 0;
        newHeight = imageHeight;
      }
    }

    return BoundingBox(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
  }

  /// Returns the area of the bounding box
  int get area => width * height;

  /// Checks if this bounding box is valid (positive width and height)
  bool isValid() {
    return width > 0 && height > 0;
  }

  /// Returns a string representation of the bounding box
  @override
  String toString() {
    return 'BoundingBox(x: $x, y: $y, width: $width, height: $height)';
  }
}
