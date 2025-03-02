import 'dart:typed_data';

/// Parameter class for grayscale conversion
class GrayscaleParams {
  final Uint8List rgbaBytes;
  final int pixelCount;
  final bool blackNWhite;
  final int threshold;

  GrayscaleParams({
    required this.rgbaBytes,
    required this.pixelCount,
    required this.blackNWhite,
    required this.threshold,
  });
}

/// Parameter class for tensor conversion
class TensorParams {
  final Uint8List rgbaBytes;
  final int pixelCount;

  TensorParams({
    required this.rgbaBytes,
    required this.pixelCount,
  });
}

/// Parameter class for mask processing
class MaskParams {
  final Uint8List rgbaBytes;
  final int pixelCount;
  final bool debugMode;

  MaskParams({
    required this.rgbaBytes,
    required this.pixelCount,
    required this.debugMode,
  });
}

/// Result class for mask processing
class MaskResult {
  final List<double> floats;
  final String? debugInfo;

  MaskResult({
    required this.floats,
    this.debugInfo,
  });
}

/// Parameter class for RGB tensor to image conversion
class RgbTensorParams {
  final List<List<List<double>>> rgbOutput;
  final int width;
  final int height;

  RgbTensorParams({
    required this.rgbOutput,
    required this.width,
    required this.height,
  });
}

/// Parameter class for RGB resizing
class ResizeParams {
  final List<List<List<double>>> output;
  final int originalWidth;
  final int originalHeight;
  final int channels;
  final int outputWidth;
  final int outputHeight;

  ResizeParams({
    required this.output,
    required this.originalWidth,
    required this.originalHeight,
    required this.channels,
    required this.outputWidth,
    required this.outputHeight,
  });
}
