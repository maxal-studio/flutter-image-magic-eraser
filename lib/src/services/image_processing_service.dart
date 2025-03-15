import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_magic_eraser/src/services/image_processing/blend_processor.dart';
import 'package:image_magic_eraser/src/services/image_processing/convert_processor.dart';
import 'package:image_magic_eraser/src/services/image_processing/crop_processor.dart';
import 'package:image_magic_eraser/src/services/image_processing/mask_processor.dart';

import '../models/bounding_box.dart';
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

  /// Resize image to the specified dimensions
  ///
  /// - [image]: The image to resize
  /// - [targetWidth]: The target width of the resized image
  /// - [targetHeight]: The target height of the resized image
  /// - [useBilinear]: Whether to use bilinear interpolation (optional)
  Future<img.Image> resizeImage(
      img.Image image, int targetWidth, int targetHeight,
      {bool useBilinear = true}) async {
    return ResizeProcessor.resizeImage(
      image,
      targetWidth,
      targetHeight,
      useBilinear: useBilinear,
    );
  }

  /// Resizes the input image to the specified dimensions
  ///
  /// - [image]: The image to resize
  /// - [targetWidth]: The target width of the resized image
  /// - [targetHeight]: The target height of the resized image
  Future<ui.Image> resizeUIImage(
      ui.Image image, int targetWidth, int targetHeight) async {
    return ResizeProcessor.resizeUIImage(image, targetWidth, targetHeight);
  }

  /// Converts an image to grayscale
  ///
  /// - [image]: The image to convert
  /// - [blackNWhite]: Whether to convert to black and white (optional)
  /// - [threshold]: The threshold for the grayscale conversion (optional)
  Future<ui.Image> convertUIImageToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    return GrayscaleProcessor.convertUIImageToGrayscale(
      image,
      blackNWhite: blackNWhite,
      threshold: threshold,
    );
  }

  /// Converts an image into a floating-point tensor
  ///
  /// - [image]: The image to convert
  /// - Returns: A floating-point tensor representation of the image
  Future<List<double>> convertUIImageToFloatTensor(ui.Image image) async {
    return TensorProcessor.convertUIImageToFloatTensor(image);
  }

  /// Converts a mask image into a floating-point tensor
  ///
  /// - [maskImage]: The mask image to convert
  /// - Returns: A floating-point tensor representation of the mask image
  Future<List<double>> convertUIMaskToFloatTensor(ui.Image maskImage) async {
    return TensorProcessor.convertUIMaskToFloatTensor(maskImage);
  }

  /// Converts an RGB tensor output to a UI image
  ///
  /// - [rgbOutput]: The RGB output to convert
  /// - Returns: A ui.Image representation of the RGB output
  Future<ui.Image> rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    return TensorProcessor.rgbTensorToUIImage(rgbOutput);
  }

  /// Resizes the RGB output to match the original image dimensions
  ///
  /// - [output]: The RGB output to resize
  /// - [originalWidth]: The original width of the image
  /// - [originalHeight]: The original height of the image
  List<List<List<double>>> resizeRGBOutput(
      List<List<List<double>>> output, int originalWidth, int originalHeight) {
    return ResizeProcessor.resizeRGBOutput(
        output, originalWidth, originalHeight);
  }

  /// Asynchronous version of resizeRGBOutput that uses compute for large images
  ///
  /// - [output]: The RGB output to resize
  /// - [originalWidth]: The original width of the image
  /// - [originalHeight]: The original height of the image
  Future<List<List<List<double>>>> resizeRGBOutputAsync(
      List<List<List<double>>> output,
      int originalWidth,
      int originalHeight) async {
    return ResizeProcessor.resizeRGBOutputAsync(
        output, originalWidth, originalHeight);
  }

  /// Blends a patch image into an original image
  ///
  /// - [originalImage]: The original image
  /// - [patch]: The patch image to blend
  /// - [box]: The bounding box of the patch
  /// - [polygon]: The polygon of the patch
  /// - [debugTag]: The debug tag for the patch (optional)
  Future<ui.Image> blendUIPatchIntoUIImage(
    ui.Image originalImage,
    ui.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    return BlendProcessor.blendUIPatchIntoUIImage(
      originalImage,
      patch,
      box,
      polygon,
      debugTag,
    );
  }

  /// Blends a patch image into an original image
  ///
  /// - [originalImage]: The original image
  /// - [patch]: The patch image to blend
  /// - [box]: The bounding box of the patch
  /// - [polygon]: The polygon of the patch
  /// - [debugTag]: The debug tag for the patch (optional)
  Future<img.Image> blendImgPatchIntoImage(
    img.Image originalImage,
    img.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    return BlendProcessor.blendImgPatchIntoImage(
      originalImage,
      patch,
      box,
      polygon,
      debugTag,
    );
  }

  /// Crops an image to the specified dimensions
  ///
  /// - [image]: The image to crop
  /// - [x]: The x-coordinate of the top-left corner of the crop
  /// - [y]: The y-coordinate of the top-left corner of the crop
  /// - [width]: The width of the crop
  /// - [height]: The height of the crop
  Future<img.Image> cropImage(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
  ) async {
    return CropProcessor.cropImage(image, x, y, width, height);
  }

  /// Converts an img.Image to a ui.Image
  ///
  /// - [image]: The img.Image to convert
  /// - Returns: A ui.Image representation of the image
  Future<ui.Image> convertImageToUiImage(img.Image image) async {
    return ConvertProcessor.convertImageToUiImage(image);
  }

  /// Converts a ui.Image to an img.Image
  ///
  /// - [uiImage]: The ui.Image to convert
  /// - Returns: An img.Image representation of the image
  Future<img.Image> convertUiImageToImage(ui.Image uiImage) async {
    return ConvertProcessor.convertUiImageToImage(uiImage);
  }

  /// Generates a mask image from a list of polygons
  ///
  /// [polygons] is a list of lists, each inner list containing points as maps with 'x' and 'y' keys
  /// Each polygon should have at least 3 points to be valid
  /// [width] and [height] are the dimensions of the mask image
  /// [strokeWidth] is the width of the strokes for outlines (default: 10.0)
  /// [backgroundColor] is the color of the background (default: black)
  /// [fillColor] is the color of the filled polygons (default: white)
  /// [drawOutline] determines whether to draw an outline around the polygons (default: false)
  Future<ui.Image> generateUIImageMask(
    List<List<Map<String, double>>> polygons,
    int width,
    int height, {
    double strokeWidth = 0,
    Color backgroundColor = Colors.black,
    Color fillColor = Colors.white,
    bool drawOutline = false,
  }) async {
    return MaskProcessor.generateUIImageMask(
      polygons,
      width,
      height,
      strokeWidth: strokeWidth,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      drawOutline: drawOutline,
    );
  }

  /// Converts a mask image to bytes
  ///
  /// - [maskImage]: The mask image to convert
  /// - Returns: A Uint8List representation of the mask image
  Future<Uint8List> maskImageToBytes(ui.Image maskImage) async {
    return MaskProcessor.maskImageToBytes(maskImage);
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
  Future<Image> generateDebugMask(
    List<List<Map<String, double>>> polygons,
    int width,
    int height, {
    double strokeWidth = 0,
    Color backgroundColor = Colors.black,
    Color fillColor = Colors.white,
    bool drawOutline = false,
  }) async {
    return MaskProcessor.generateDebugMask(
      polygons,
      width,
      height,
      strokeWidth: strokeWidth,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      drawOutline: drawOutline,
    );
  }

  /// Generates a mask from polygons using the image package
  ///
  /// - [polygons]: List of polygons to draw
  /// - [width]: Width of the mask
  /// - [height]: Height of the mask
  /// - Returns: An img.Image containing the mask
  Future<img.Image> generateMaskImage(
    List<List<Map<String, double>>> polygons,
    int width,
    int height,
  ) async {
    return MaskProcessor.generateMaskImage(
      polygons,
      width,
      height,
    );
  }
}
