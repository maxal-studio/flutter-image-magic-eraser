import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'mappers/input_size.dart';
export 'mappers/input_size.dart';

class InpaintingService {
  InpaintingService._internal();

  static final InpaintingService _instance = InpaintingService._internal();

  static InpaintingService get instance => _instance;

  // The ONNX session used for inference.
  OrtSession? _session;

  // LaMa model expects 512x512 input images
  static InputSize _modelInputSize = InputSize(width: 512, height: 512);

  /// Initializes the ONNX environment and creates a session.
  ///
  /// This method should be called once before using the [removeBg] method.
  Future<void> initializeOrt(String modelPath) async {
    try {
      /// Initialize the ONNX runtime environment.
      OrtEnv.instance.init();

      /// Create the ONNX session.
      await _createSession(modelPath);
    } catch (e) {
      rethrow;
    }
  }

  /// Creates an ONNX session using the model from assets.
  Future<void> _createSession(String modelPath) async {
    try {
      /// Session configuration options.
      final sessionOptions = OrtSessionOptions();

      /// Load the model as a raw asset.
      final rawAssetFile = await rootBundle.load(modelPath);

      /// Convert the asset to a byte array.
      final bytes = rawAssetFile.buffer.asUint8List();

      /// Create the ONNX session.
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      if (kDebugMode) {
        log('ONNX session created successfully.', name: "InpaintingService");
      }
    } catch (e) {
      throw Exception('Error creating ONNX session: $e');
    }
  }

  /// Set model input size
  void setModelInputSize(InputSize size) {
    _modelInputSize = size;
  }

  /// Removes the background from an image.
  ///
  /// This function processes the input image and removes its background,
  /// returning a new image with the background removed.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - Returns: A [ui.Image] with the background removed.
  ///
  /// Example usage:
  /// ```dart
  /// final imageBytes = await File('path_to_image').readAsBytes();
  /// final ui.Image imageWithoutBackground = await removeBackground(imageBytes);
  /// ```
  ///
  /// Note: This function may take some time to process depending on the size
  /// and complexity of the input image.
  Future<ui.Image> inpaint(Uint8List imageBytes, Uint8List maskBytes) async {
    if (_session == null) {
      throw Exception("ONNX session not initialized");
    }

    try {
      /// Decode the input image and resize it to the required dimensions.
      final originalImage = await decodeImageFromList(imageBytes);
      log('Original image size: ${originalImage.width}x${originalImage.height}');
      final resizedImage = await _resizeImage(
          originalImage, _modelInputSize.width, _modelInputSize.height);

      /// Decode the mask image and resize it to the required dimensions.
      final originalMask = await decodeImageFromList(maskBytes);
      log('Original mask size: ${originalMask.width}x${originalMask.height}');
      final resizedMask = await _resizeImage(
          originalMask, _modelInputSize.width, _modelInputSize.height);

      /// Convert mask to grayscale if it's not already
      final grayscaleMask = await _convertToGrayscale(resizedMask);
      log('Converted mask to grayscale', name: 'InpaintingService');

      /// Convert the resized image into a tensor format required by the ONNX model.
      final rgbFloats = await _imageToFloatTensor(resizedImage);
      final imageTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(rgbFloats),
        [1, 3, _modelInputSize.width, _modelInputSize.height],
      );

      /// Convert the grayscale mask into a tensor format required by the ONNX model.
      final maskFloats = await _maskToFloatTensor(grayscaleMask);
      final maskTensor = OrtValueTensor.createTensorWithDataList(
        Float32List.fromList(maskFloats),
        [1, 1, _modelInputSize.width, _modelInputSize.height],
      );

      /// Prepare the inputs and run inference on the ONNX model.
      final inputs = {
        'image': imageTensor,
        'mask': maskTensor,
      };
      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(runOptions, inputs);
      imageTensor.release();
      maskTensor.release();
      runOptions.release();

      /// Process the output tensor and generate the final image with the background removed.
      final outputTensor = outputs?[0]?.value;
      if (outputTensor is List) {
        final output = outputTensor[0]; // This should be RGB channels
        log('Output tensor shape: ${output.length} channels',
            name: 'InpaintingService');

        log('Processing RGB output from LaMa model', name: 'InpaintingService');
        final resizedOutput =
            resizeRGBOutput(output, originalImage.width, originalImage.height);
        final inpaintedImage = await _rgbTensorToUIImage(resizedOutput);
        return inpaintedImage;
      } else {
        throw Exception(
          'Unexpected output format from ONNX model.',
        );
      }
    } catch (e) {
      throw Exception('Error inpainting image: $e');
    }
  }

  /// Converts an image to grayscale
  Future<ui.Image> _convertToGrayscale(
    ui.Image image, {
    bool blackNWhite = true,
    int threshold = 50,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final grayBytes = Uint8List(
        pixelCount * 4); // Still RGBA format but with grayscale values

    for (int i = 0; i < pixelCount; i++) {
      // Convert RGB to grayscale using standard luminance formula
      final r = rgbaBytes[i * 4];
      final g = rgbaBytes[i * 4 + 1];
      final b = rgbaBytes[i * 4 + 2];
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

      // If blackNWhite is true, convert all non-black/white colors to white
      int finalGray = gray;
      if (blackNWhite) {
        // Consider pixels as black if they're very dark (below threshold)
        // Otherwise convert to white
        finalGray = gray < threshold ? 0 : 255;
      } else {
        finalGray = gray;
      }

      // Set all RGB channels to the same grayscale value
      grayBytes[i * 4] = finalGray; // R
      grayBytes[i * 4 + 1] = finalGray; // G
      grayBytes[i * 4 + 2] = finalGray; // B
      grayBytes[i * 4 + 3] = rgbaBytes[i * 4 + 3]; // Keep original alpha
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        grayBytes, image.width, image.height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  /// Converts a mask image into a floating-point tensor.
  /// This is specifically for single-channel mask input.
  Future<List<double>> _maskToFloatTensor(ui.Image maskImage) async {
    final byteData =
        await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get mask ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = maskImage.width * maskImage.height;
    final floats = List<double>.filled(pixelCount, 0);

    // For mask, we only need one channel (using red channel as grayscale value)
    for (int i = 0; i < pixelCount; i++) {
      floats[i] = rgbaBytes[i * 4] / 255.0; // Use red channel as the mask value
    }

    return floats;
  }

  /// Converts an image into a floating-point tensor.
  Future<List<double>> _imageToFloatTensor(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");
    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final floats = List<double>.filled(pixelCount * 3, 0);

    /// Extract and normalize RGB channels.
    for (int i = 0; i < pixelCount; i++) {
      floats[i] = rgbaBytes[i * 4] / 255.0; // Red
      floats[pixelCount + i] = rgbaBytes[i * 4 + 1] / 255.0; // Green
      floats[2 * pixelCount + i] = rgbaBytes[i * 4 + 2] / 255.0; // Blue
    }
    return floats;
  }

  /// Resizes the mask to match the original image dimensions.
  List resizeOutput(List output, int originalWidth, int originalHeight) {
    // Get the actual dimensions of the model output
    final outputHeight = output.length;
    final outputWidth = output[0].length;

    log('Model output dimensions: ${outputWidth}x$outputHeight',
        name: 'ResizeOutput');
    log('Target dimensions: ${originalWidth}x$originalHeight',
        name: 'ResizeOutput');

    final resizedOutput = List.generate(
      originalHeight,
      (_) => List.filled(originalWidth, 0.0),
    );

    for (int y = 0; y < originalHeight; y++) {
      for (int x = 0; x < originalWidth; x++) {
        // Scale coordinates based on actual output dimensions
        final scaledX = (x * outputWidth / originalWidth).floor();
        final scaledY = (y * outputHeight / originalHeight).floor();

        // Ensure we don't go out of bounds
        final safeX = scaledX.clamp(0, outputWidth - 1);
        final safeY = scaledY.clamp(0, outputHeight - 1);

        resizedOutput[y][x] = output[safeY][safeX];
      }
    }
    return resizedOutput;
  }

  /// Converts an RGB tensor output to a UI image without any manipulations
  Future<ui.Image> _rgbTensorToUIImage(
      List<List<List<double>>> rgbOutput) async {
    // Get dimensions from the tensor
    final height = rgbOutput[0].length;
    final width = rgbOutput[0][0].length;

    log('Converting tensor with dimensions: ${rgbOutput.length}x${height}x$width',
        name: 'RGBTensorToUIImage');

    // Create the output RGBA bytes
    final outputRgbaBytes = Uint8List(width * height * 4);

    // Process each pixel - direct conversion without any manipulations
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;

        // Get RGB values directly from the tensor
        // Assuming values are in [0,255] range - if not, they'll be clamped
        outputRgbaBytes[i] = rgbOutput[0][y][x].round().clamp(0, 255); // R
        outputRgbaBytes[i + 1] = rgbOutput[1][y][x].round().clamp(0, 255); // G
        outputRgbaBytes[i + 2] = rgbOutput[2][y][x].round().clamp(0, 255); // B
        outputRgbaBytes[i + 3] = 255; // Alpha (fully opaque)
      }
    }

    // Create a ui.Image from the RGBA bytes
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        outputRgbaBytes, width, height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  /// Resizes the RGB output to match the original image dimensions.
  List<List<List<double>>> resizeRGBOutput(
      List output, int originalWidth, int originalHeight) {
    // Get the actual dimensions of the model output
    final channels = output.length;
    final outputHeight = output[0].length;
    final outputWidth = output[0][0].length;

    log('RGB Model output dimensions: ${channels}x${outputHeight}x$outputWidth',
        name: 'ResizeRGBOutput');
    log('Target dimensions: ${originalWidth}x$originalHeight',
        name: 'ResizeRGBOutput');

    // Create a 3D list for RGB channels
    final resizedOutput = List.generate(
      channels,
      (_) => List.generate(
        originalHeight,
        (_) => List.filled(originalWidth, 0.0),
      ),
    );

    // Resize each channel
    for (int c = 0; c < channels; c++) {
      for (int y = 0; y < originalHeight; y++) {
        for (int x = 0; x < originalWidth; x++) {
          // Scale coordinates based on actual output dimensions
          final scaledX = (x * outputWidth / originalWidth).floor();
          final scaledY = (y * outputHeight / originalHeight).floor();

          // Ensure we don't go out of bounds
          final safeX = scaledX.clamp(0, outputWidth - 1);
          final safeY = scaledY.clamp(0, outputHeight - 1);

          resizedOutput[c][y][x] = output[c][safeY][safeX];
        }
      }
    }
    return resizedOutput;
  }

  /// Resizes the input image to the specified dimensions.
  Future<ui.Image> _resizeImage(
      ui.Image image, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect =
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    return picture.toImage(targetWidth, targetHeight);
  }
}
