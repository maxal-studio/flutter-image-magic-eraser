import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Utility class for managing image disposal
class ImageDisposalUtil {
  /// Safely dispose a UI image and set it to null
  /// Returns true if the image was successfully disposed
  static bool disposeImage(ui.Image? image) {
    if (image == null) return false;

    try {
      image.dispose();
      return true;
    } catch (e) {
      if (kDebugMode) {
        log('Error disposing image: $e', name: 'ImageDisposalUtil', error: e);
      }
      return false;
    }
  }

  /// Safely dispose multiple UI images
  /// Returns the number of successfully disposed images
  static int disposeImages(List<ui.Image?> images) {
    int count = 0;
    for (final image in images) {
      if (disposeImage(image)) {
        count++;
      }
    }
    return count;
  }

  /// Safely dispose all UI images in a map
  /// Returns the number of successfully disposed images
  static int disposeImageMap(Map<String, ui.Image> imageMap) {
    int count = 0;
    for (final image in imageMap.values) {
      if (disposeImage(image)) {
        count++;
      }
    }
    return count;
  }
}
