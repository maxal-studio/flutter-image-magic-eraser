import 'dart:async';
import 'dart:ui' as ui;

import 'image_processing/grayscale_processor.dart';
import 'image_processing/tensor_processor.dart';
import 'image_processing/resize_processor.dart';

/// Service for handling image processing operations
class ImageProcessingService {
  ImageProcessingService._internal();

  static final ImageProcessingService _instance =
      ImageProcessingService._internal();

  /// Returns the singleton instance of the service
  static ImageProcessingService get instance => _instance;

  /// Resizes the input image to the specified dimensions
  Future<ui.Image> resizeImage(
      ui.Image image, int targetWidth, int targetHeight) async {
    return ResizeProcessor.resizeImage(image, targetWidth, targetHeight);
  }

  /// Converts an image to grayscale
  Future<ui.Image> convertToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    return GrayscaleProcessor.convertToGrayscale(
      image,
      blackNWhite: blackNWhite,
      threshold: threshold,
    );
  }

  /// Converts an image into a floating-point tensor
  Future<List<double>> imageToFloatTensor(ui.Image image) async {
    return TensorProcessor.imageToFloatTensor(image);
  }

  /// Converts a mask image into a floating-point tensor
  Future<List<double>> maskToFloatTensor(ui.Image maskImage) async {
    return TensorProcessor.maskToFloatTensor(maskImage);
  }

  /// Converts an RGB tensor output to a UI image
  Future<ui.Image> rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    return TensorProcessor.rgbTensorToUIImage(rgbOutput);
  }

  /// Resizes the RGB output to match the original image dimensions
  List<List<List<double>>> resizeRGBOutput(
      List<List<List<double>>> output, int originalWidth, int originalHeight) {
    return ResizeProcessor.resizeRGBOutput(
        output, originalWidth, originalHeight);
  }

  /// Asynchronous version of resizeRGBOutput that uses compute for large images
  Future<List<List<List<double>>>> resizeRGBOutputAsync(
      List<List<List<double>>> output,
      int originalWidth,
      int originalHeight) async {
    return ResizeProcessor.resizeRGBOutputAsync(
        output, originalWidth, originalHeight);
  }
}
