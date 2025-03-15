import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/bounding_box.dart';

/// Parameters for image conversion from ui.Image to img.Image
class UiToImgParams {
  final Uint8List bytes;
  final int width;
  final int height;

  UiToImgParams(this.bytes, this.width, this.height);
}

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

/// Parameters for image cropping
class CropParams {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;

  CropParams(this.image, this.x, this.y, this.width, this.height);
}

/// Parameters for image resizing
class ResizeParams {
  final img.Image image;
  final int targetWidth;
  final int targetHeight;
  final bool useBilinear;

  ResizeParams(
      this.image, this.targetWidth, this.targetHeight, this.useBilinear);
}

/// Parameters for mask generation
class MaskParams {
  final List<List<Map<String, double>>> polygons;
  final int width;
  final int height;

  MaskParams(this.polygons, this.width, this.height);
}

/// Parameters for blending a patch into an image
class BlendParams {
  final img.Image originalImage;
  final img.Image patch;
  final BoundingBox box;
  final List<Map<String, double>> polygon;
  final String debugTag;

  BlendParams(
      this.originalImage, this.patch, this.box, this.polygon, this.debugTag);
}

/// Service for image processing using the image package
///
/// This service provides methods for image processing operations using the image package,
/// which offers better performance and memory efficiency for image operations.
class ImagePackageService {
  ImagePackageService._internal();

  static final ImagePackageService _instance = ImagePackageService._internal();

  /// Returns the singleton instance of the service
  static ImagePackageService get instance => _instance;

  /// Converts a ui.Image to an img.Image
  ///
  /// - [uiImage]: The ui.Image to convert
  /// - Returns: An img.Image representation of the image
  Future<img.Image> convertUiImageToImgImage(ui.Image uiImage) async {
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();

    // Run the conversion in an isolate
    return compute(
      _convertUiToImgIsolate,
      UiToImgParams(rgbaBytes, uiImage.width, uiImage.height),
    );
  }

  /// Isolate function for converting ui.Image bytes to img.Image
  static img.Image _convertUiToImgIsolate(UiToImgParams params) {
    if (kDebugMode) {
      log('Converting ui.Image to img.Image with dimensions: ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    return img.Image.fromBytes(
      width: params.width,
      height: params.height,
      bytes: params.bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Converts an img.Image to a ui.Image
  ///
  /// - [image]: The img.Image to convert
  /// - Returns: A ui.Image representation of the image
  Future<ui.Image> convertImageToUiImage(img.Image image) async {
    // Process the image in an isolate
    final processedBytes = await compute(
      _convertImgToUiIsolate,
      ImgToUiParams(image),
    );

    // Create a Completer to wait for the async decoding
    final Completer<ui.Image> completer = Completer();

    // Decode pixels into a ui.Image (must be done on the main thread)
    ui.decodeImageFromPixels(
      processedBytes.bytes,
      processedBytes.width,
      processedBytes.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  /// Isolate function for converting img.Image to bytes for ui.Image
  static ImageConversionResult _convertImgToUiIsolate(ImgToUiParams params) {
    if (kDebugMode) {
      log('Converting img.Image to bytes for ui.Image with dimensions: ${params.image.width}x${params.image.height}',
          name: 'ImagePackageService');
    }
    final img.Image image = params.image;

    // Ensure we have an RGBA image
    img.Image rgbaImage;
    if (image.numChannels != 4) {
      // Create a new RGBA image
      rgbaImage =
          img.Image(width: image.width, height: image.height, numChannels: 4);

      // Copy the RGB data and add alpha channel
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          rgbaImage.setPixel(
              x, y, img.ColorRgba8(r, g, b, 255)); // Alpha (fully opaque)
        }
      }
    } else {
      rgbaImage = image;
    }

    // Convert img.Image to Uint8List (RGBA format)
    Uint8List uint8List =
        Uint8List.fromList(rgbaImage.getBytes(order: img.ChannelOrder.rgba));

    return ImageConversionResult(uint8List, rgbaImage.width, rgbaImage.height);
  }

  /// Crops an image to the specified dimensions
  ///
  /// - [image]: The input image to crop
  /// - [x]: The x coordinate of the top-left corner of the crop region
  /// - [y]: The y coordinate of the top-left corner of the crop region
  /// - [width]: The width of the crop region
  /// - [height]: The height of the crop region
  /// - Returns: A new cropped image
  Future<img.Image> cropImage(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
  ) async {
    return compute(
      _cropImageIsolate,
      CropParams(image, x, y, width, height),
    );
  }

  /// Isolate function for cropping an image
  static img.Image _cropImageIsolate(CropParams params) {
    if (kDebugMode) {
      log('Cropping image with dimensions: ${params.image.width}x${params.image.height} to ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    return img.copyCrop(
      params.image,
      x: params.x,
      y: params.y,
      width: params.width,
      height: params.height,
    );
  }

  /// Resizes an image to the specified dimensions
  ///
  /// - [image]: The input image to resize
  /// - [targetWidth]: The desired width of the output image
  /// - [targetHeight]: The desired height of the output image
  /// - [useBilinear]: Whether to use bilinear interpolation for better quality (default: true)
  /// - Returns: A new resized image
  Future<img.Image> resizeImage(
    img.Image image,
    int targetWidth,
    int targetHeight, {
    bool useBilinear = true,
  }) async {
    return compute(
      _resizeImageIsolate,
      ResizeParams(image, targetWidth, targetHeight, useBilinear),
    );
  }

  /// Isolate function for resizing an image
  static img.Image _resizeImageIsolate(ResizeParams params) {
    if (kDebugMode) {
      log('Resizing image with dimensions: ${params.image.width}x${params.image.height} to ${params.targetWidth}x${params.targetHeight}',
          name: 'ImagePackageService');
    }
    if (params.useBilinear) {
      return img.copyResize(
        params.image,
        width: params.targetWidth,
        height: params.targetHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      return img.copyResize(
        params.image,
        width: params.targetWidth,
        height: params.targetHeight,
        interpolation: img.Interpolation.nearest,
      );
    }
  }

  /// Generates a mask from polygons using the image package
  ///
  /// - [polygons]: List of polygons to draw
  /// - [width]: Width of the mask
  /// - [height]: Height of the mask
  /// - Returns: An img.Image containing the mask
  Future<img.Image> generateMask(
      List<List<Map<String, double>>> polygons, int width, int height) async {
    return compute(
      _generateMaskIsolate,
      MaskParams(polygons, width, height),
    );
  }

  /// Isolate function for generating a mask
  static img.Image _generateMaskIsolate(MaskParams params) {
    if (kDebugMode) {
      log('Generating mask with dimensions: ${params.width}x${params.height}',
          name: 'ImagePackageService');
    }
    final width = params.width;
    final height = params.height;
    final polygons = params.polygons;

    if (kDebugMode) {
      log('Generating mask with dimensions: $width x $height',
          name: 'ImagePackageService');
    }

    // Create a new RGBA image with 4 channels
    final img.Image mask =
        img.Image(width: width, height: height, numChannels: 4);

    final bgColor = img.ColorRgba8(0, 0, 0, 255); // Pure black
    final fillColorRgba = img.ColorRgba8(255, 255, 255, 255); // Pure white

    // Fill with background color
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        mask.setPixel(x, y, bgColor);
      }
    }

    // Draw each polygon
    for (final polygon in polygons) {
      if (polygon.length < 3) {
        continue;
      }

      // Convert polygon points to list of points
      final points = polygon.map((point) {
        return img.Point(
          point['x']!.round(),
          point['y']!.round(),
        );
      }).toList();

      // Fill the polygon with the fill color
      img.fillPolygon(
        mask,
        vertices: points,
        color: fillColorRgba,
      );
    }

    // Ensure the image data is properly initialized
    if (mask.data == null) {
      throw Exception('Failed to generate mask: image data is null');
    }

    return mask;
  }

  /// Blends an inpainted patch into the original image using a polygon mask
  ///
  /// This method works directly with img.Image objects to blend the patch only within
  /// the polygon area, ensuring that only the masked region is affected by the inpainting.
  ///
  /// - [originalImage]: The original image as img.Image
  /// - [patch]: The inpainted patch as img.Image
  /// - [box]: The bounding box where the patch should be placed
  /// - [polygon]: The polygon defining the area to be inpainted
  /// - Returns: An img.Image with the patch blended into the original image
  Future<img.Image> blendImgPatchIntoImage(
    img.Image originalImage,
    img.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) async {
    return compute(
      _blendImgPatchIntoImageIsolate,
      BlendParams(originalImage, patch, box, polygon, debugTag),
    );
  }

  /// Isolate function for blending a patch into an image
  static img.Image _blendImgPatchIntoImageIsolate(BlendParams params) {
    try {
      if (kDebugMode) {
        log('Blending patch into image with dimensions: ${params.originalImage.width}x${params.originalImage.height}',
            name: 'ImagePackageService');
        if (kDebugMode) {
          log('Blending patch into image with dimensions: ${params.originalImage.width}x${params.originalImage.height}',
              name: 'ImagePackageService');
          log('Patch dimensions: ${params.patch.width}x${params.patch.height}',
              name: 'ImagePackageService');
          log('Bounding box: x=${params.box.x}, y=${params.box.y}, width=${params.box.width}, height=${params.box.height}',
              name: 'ImagePackageService');
        }
      }
      final originalImage = params.originalImage;
      final patch = params.patch;
      final box = params.box;
      final polygon = params.polygon;

      // Create a copy of the original image to avoid modifying it
      final result = img.Image.from(originalImage);

      // For each pixel in the patch's bounding box
      for (int y = 0; y < box.height; y++) {
        final int imgY = box.y + y;
        // Skip if outside the original image bounds
        if (imgY < 0 || imgY >= originalImage.height) continue;

        for (int x = 0; x < box.width; x++) {
          final int imgX = box.x + x;
          // Skip if outside the original image bounds
          if (imgX < 0 || imgX >= originalImage.width) continue;

          // Check if the pixel is inside the polygon
          if (_isPointInPolygon(imgX.toDouble(), imgY.toDouble(), polygon)) {
            // Get the pixel color from the patch
            final patchColor = patch.getPixel(x, y);

            // Set the pixel color in the result image
            result.setPixel(imgX, imgY, patchColor);
          }
        }
      }

      return result;
    } catch (e) {
      throw Exception('Error in blendImgPatchIntoImage: $e');
    }
  }

  /// Checks if a point is inside a polygon using the ray casting algorithm
  static bool _isPointInPolygon(
      double x, double y, List<Map<String, double>> polygon) {
    bool inside = false;
    final int len = polygon.length;

    for (int i = 0, j = len - 1; i < len; j = i++) {
      final double xi = polygon[i]['x']!;
      final double yi = polygon[i]['y']!;
      final double xj = polygon[j]['x']!;
      final double yj = polygon[j]['y']!;

      final bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);

      if (intersect) {
        inside = !inside;
      }
    }

    return inside;
  }
}
