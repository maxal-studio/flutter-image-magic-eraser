import 'dart:async';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/bounding_box.dart';

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
    return img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: rgbaBytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Converts an img.Image to a ui.Image
  ///
  /// - [image]: The img.Image to convert
  /// - Returns: A ui.Image representation of the image
  Future<ui.Image> convertImageToUiImage(img.Image image) async {
    debugPrint('Converting image to ui.Image');
    debugPrint(
        'Original image format: ${image.format}, Channels: ${image.numChannels}');

    // Ensure we have an RGBA image
    img.Image rgbaImage;
    if (image.numChannels != 4) {
      debugPrint('Converting image to RGBA format');
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

    debugPrint(
        'Final image format: ${rgbaImage.format}, Channels: ${rgbaImage.numChannels}');

    // Convert img.Image to Uint8List (RGBA format)
    Uint8List uint8List =
        Uint8List.fromList(rgbaImage.getBytes(order: img.ChannelOrder.rgba));

    // Create a Completer to wait for the async decoding
    final Completer<ui.Image> completer = Completer();

    // Decode pixels into a ui.Image
    ui.decodeImageFromPixels(
      uint8List,
      rgbaImage.width,
      rgbaImage.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  /// Crops an image to the specified dimensions
  ///
  /// - [image]: The input image to crop
  /// - [x]: The x coordinate of the top-left corner of the crop region
  /// - [y]: The y coordinate of the top-left corner of the crop region
  /// - [width]: The width of the crop region
  /// - [height]: The height of the crop region
  /// - Returns: A new cropped image
  img.Image cropImage(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
  ) {
    return img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  /// Resizes an image to the specified dimensions
  ///
  /// - [image]: The input image to resize
  /// - [targetWidth]: The desired width of the output image
  /// - [targetHeight]: The desired height of the output image
  /// - [useBilinear]: Whether to use bilinear interpolation for better quality (default: true)
  /// - Returns: A new resized image
  img.Image resizeImage(
    img.Image image,
    int targetWidth,
    int targetHeight, {
    bool useBilinear = true,
  }) {
    if (useBilinear) {
      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      return img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.nearest,
      );
    }
  }

  /// Generates a mask from polygons using the image package
  ///
  /// - [polygons]: List of polygons to draw
  /// - [width]: Width of the mask
  /// - [height]: Height of the mask
  /// - [backgroundColor]: Background color (default: black)
  /// - [fillColor]: Fill color for polygons (default: white)
  /// - Returns: An img.Image containing the mask
  img.Image generateMask(
      List<List<Map<String, double>>> polygons, int width, int height) {
    debugPrint('Generating mask with dimensions: $width x $height');
    debugPrint('Number of polygons: ${polygons.length}');

    // Create a new RGBA image with 4 channels
    final img.Image mask =
        img.Image(width: width, height: height, numChannels: 4);

    final bgColor = img.ColorRgba8(0, 0, 0, 255); // Pure black
    final fillColorRgba = img.ColorRgba8(255, 255, 255, 255); // Pure white

    debugPrint(
        'Background color: R=${bgColor.r}, G=${bgColor.g}, B=${bgColor.b}, A=${bgColor.a}');
    debugPrint(
        'Fill color: R=${fillColorRgba.r}, G=${fillColorRgba.g}, B=${fillColorRgba.b}, A=${fillColorRgba.a}');

    // Fill with background color
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        mask.setPixel(x, y, bgColor);
      }
    }

    // Count black pixels after background fill
    int blackPixels = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = mask.getPixel(x, y);
        if (pixel.r == 0 && pixel.g == 0 && pixel.b == 0) {
          blackPixels++;
        }
      }
    }
    debugPrint(
        'Black pixels after background fill: $blackPixels out of ${width * height}');

    // Draw each polygon
    for (final polygon in polygons) {
      if (polygon.length < 3) {
        debugPrint('Skipping polygon with less than 3 points');
        continue;
      }

      // Convert polygon points to list of points
      final points = polygon.map((point) {
        return img.Point(
          point['x']!.round(),
          point['y']!.round(),
        );
      }).toList();

      debugPrint('Drawing polygon with ${points.length} points');
      debugPrint('First point: (${points.first.x}, ${points.first.y})');
      debugPrint('Last point: (${points.last.x}, ${points.last.y})');

      // Fill the polygon with the fill color
      img.fillPolygon(
        mask,
        vertices: points,
        color: fillColorRgba,
      );
    }

    // Count white pixels after polygon fill
    int whitePixels = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = mask.getPixel(x, y);
        if (pixel.r == 255 && pixel.g == 255 && pixel.b == 255) {
          whitePixels++;
        }
      }
    }
    debugPrint(
        'White pixels after polygon fill: $whitePixels out of ${width * height}');

    // Ensure the image data is properly initialized
    if (mask.data == null) {
      throw Exception('Failed to generate mask: image data is null');
    }

    debugPrint(
        'Mask generated successfully. Data length: ${mask.data!.length}');
    debugPrint('Image format: ${mask.format}, Channels: ${mask.numChannels}');

    // Verify the mask has proper black and white values
    _verifyMask(mask);

    return mask;
  }

  /// Verifies that the mask has proper black and white values
  void _verifyMask(img.Image mask) {
    int blackPixels = 0;
    int whitePixels = 0;
    int otherPixels = 0;

    for (int y = 0; y < mask.height; y++) {
      for (int x = 0; x < mask.width; x++) {
        final pixel = mask.getPixel(x, y);
        if (pixel.r == 0 && pixel.g == 0 && pixel.b == 0) {
          blackPixels++;
        } else if (pixel.r == 255 && pixel.g == 255 && pixel.b == 255) {
          whitePixels++;
        } else {
          otherPixels++;
          debugPrint(
              'Found non-black/white pixel at ($x, $y): R=${pixel.r}, G=${pixel.g}, B=${pixel.b}, A=${pixel.a}');
        }
      }
    }

    debugPrint('Mask verification:');
    debugPrint('- Black pixels: $blackPixels');
    debugPrint('- White pixels: $whitePixels');
    debugPrint('- Other pixels: $otherPixels');

    if (otherPixels > 0) {
      debugPrint('WARNING: Mask contains non-black/white pixels!');
    }
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
  img.Image blendImgPatchIntoImage(
    img.Image originalImage,
    img.Image patch,
    BoundingBox box,
    List<Map<String, double>> polygon, [
    String debugTag = '',
  ]) {
    try {
      debugPrint(
          'Blending patch into image with dimensions: ${originalImage.width}x${originalImage.height}');
      debugPrint('Patch dimensions: ${patch.width}x${patch.height}');
      debugPrint(
          'Bounding box: x=${box.x}, y=${box.y}, width=${box.width}, height=${box.height}');

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

      if (kDebugMode) {
        debugPrint('Successfully blended patch into original image');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        final logTag = debugTag.isNotEmpty
            ? '$debugTag - blendImgPatchIntoImage'
            : 'blendImgPatchIntoImage';
        debugPrint('Error in $logTag: $e');
      }
      rethrow;
    }
  }

  /// Checks if a point is inside a polygon using the ray casting algorithm
  bool _isPointInPolygon(
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
