/// Represents the input size for the inpainting model
class InputSize {
  /// Width of the input image
  final int width;

  /// Height of the input image
  final int height;

  /// Creates a new input size with the given width and height
  const InputSize({
    required this.width,
    required this.height,
  });

  /// Creates a square input size with the same width and height
  factory InputSize.square(int size) {
    return InputSize(width: size, height: size);
  }

  /// Returns a string representation of the input size
  @override
  String toString() {
    return 'InputSize(width: $width, height: $height)';
  }
}
