import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/image_magic_eraser.dart';

/// Parameters for image conversion from img.Image to ui.Image
class ImgToUiParams {
  final img.Image image;

  ImgToUiParams(this.image);
}

/// Result class for image conversion
class ImageConversionResult {
  final Uint8List bytes;
  final int width;
  final int height;

  ImageConversionResult(this.bytes, this.width, this.height);
}

/// Parameters for image conversion from ui.Image to img.Image
class UiToImgParams {
  final Uint8List bytes;
  final int width;
  final int height;

  UiToImgParams(this.bytes, this.width, this.height);
}

/// Parameters for blending a patch into an image
class BlendImageParams {
  final img.Image originalImage;
  final img.Image patch;
  final BoundingBox box;
  final List<Map<String, double>> polygon;
  final String debugTag;

  BlendImageParams(
      this.originalImage, this.patch, this.box, this.polygon, this.debugTag);
}

/// Parameters for image cropping
class CropImageParams {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;

  CropImageParams(this.image, this.x, this.y, this.width, this.height);
}

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

class MaskImageParams {
  final List<List<Map<String, double>>> polygons;
  final int width;
  final int height;

  MaskImageParams(this.polygons, this.width, this.height);
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

/// Parameters for image resizing
class ResizeImageParams {
  final img.Image image;
  final int targetWidth;
  final int targetHeight;
  final bool useBilinear;

  ResizeImageParams(
      this.image, this.targetWidth, this.targetHeight, this.useBilinear);
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
