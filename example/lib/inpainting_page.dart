import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

class InpaintingPage extends StatefulWidget {
  const InpaintingPage({super.key});

  @override
  State<InpaintingPage> createState() {
    return _InpaintingPageState();
  }
}

class _InpaintingPageState extends State<InpaintingPage> {
  ui.Image? _outputImage;
  bool _isModelLoaded = false;
  bool _isInpainting = false;
  bool _isLoadingModel = false;
  static ImagePicker imagePicker = ImagePicker();

  XFile? image;
  XFile? mask;

  // Demo polygons for testing inpainting
  final List<List<Map<String, double>>> _demoPolygons = [
    // Rectangle in the center to cover the man
    [
      {'x': 230.0, 'y': 300.0},
      {'x': 430.0, 'y': 300.0},
      {'x': 430.0, 'y': 770.0},
      {'x': 230.0, 'y': 770.0},
    ],
  ];

  // Add a state variable to hold the debug mask image
  Image? _debugMaskImage;

  @override
  void initState() {
    super.initState();

    // Check if model is already loaded
    _isModelLoaded = InpaintingService.instance.isModelLoaded();

    if (!_isModelLoaded) {
      _loadModel();
    }
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoadingModel = true;
    });

    try {
      await InpaintingService.instance
          .initializeOrt('assets/models/lama_fp32.onnx');
      InpaintingService.instance
          .setModelInputSize(InputSize(width: 512, height: 512));

      setState(() {
        _isModelLoaded = true;
        _isLoadingModel = false;
      });
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _isLoadingModel = false;
      });
      debugPrint('Error loading model: $e');
    }
  }

  @override
  void dispose() {
    // No need to dispose of the service here as it's a singleton
    // and might be used elsewhere in the app
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> pickImage() async {
    try {
      final file = await imagePicker.pickImage(source: ImageSource.gallery);
      setState(() {
        image = file;
      });
    } on Exception catch (e) {
      debugPrint('Error picking mask: $e');
    }
  }

  /// Pick a mask from the gallery
  Future<void> pickMask() async {
    try {
      final file = await imagePicker.pickImage(source: ImageSource.gallery);
      setState(() {
        mask = file;
      });
    } on Exception catch (e) {
      debugPrint('Error picking mask: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Inpainting")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: (_isLoadingModel)
            ? Column(
                children: [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text("Loading model..."),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (image == null)
                            ? ElevatedButton(
                                onPressed: pickImage,
                                child: const Text("Pick Image"),
                              )
                            : Image.file(File(image!.path), width: 400),
                        (mask == null)
                            ? ElevatedButton(
                                onPressed: pickMask,
                                child: const Text("Pick Mask"),
                              )
                            : Image.file(File(mask!.path), width: 400),
                        if (_isInpainting)
                          const CircularProgressIndicator()
                        else if (_outputImage != null)
                          RawImage(
                            image: _outputImage,
                            width: 400,
                          )
                        else
                          Container(),
                      ],
                    ),
                    if (image != null && mask != null) ...[
                      // Original inpainting with mask image
                      ElevatedButton(
                        onPressed: () async {
                          if (_isInpainting) return;
                          setState(() {
                            _isInpainting = true;
                          });

                          final ByteData bytes =
                              await rootBundle.load(image!.path);
                          final Uint8List selectedImageBytes =
                              bytes.buffer.asUint8List();

                          final ByteData maskBytes =
                              await rootBundle.load(mask!.path);
                          final Uint8List selectedMaskBytes =
                              maskBytes.buffer.asUint8List();

                          try {
                            final outputImage = await InpaintingService.instance
                                .inpaint(selectedImageBytes, selectedMaskBytes);
                            setState(() {
                              _outputImage = outputImage;
                              _isInpainting = false;
                            });
                          } catch (e) {
                            setState(() {
                              _isInpainting = false;
                            });
                            debugPrint('Error inpainting: $e');
                          }
                        },
                        child: const Text("Inpaint with Mask"),
                      ),
                    ],
                    if (image != null) ...[
                      // Add button for visualizing mask
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () => _visualizeMask(),
                          child: const Text('Visualize Polygons Mask'),
                        ),
                      ),

                      // Inpainting with polygons
                      ElevatedButton(
                        onPressed: () async {
                          if (_isInpainting) return;
                          setState(() {
                            _isInpainting = true;
                          });

                          final ByteData bytes =
                              await rootBundle.load(image!.path);
                          final Uint8List selectedImageBytes =
                              bytes.buffer.asUint8List();

                          try {
                            final outputImage = await InpaintingService.instance
                                .inpaintWithPolygons(
                              selectedImageBytes,
                              _demoPolygons,
                            );
                            setState(() {
                              _outputImage = outputImage;
                              _isInpainting = false;
                            });
                          } catch (e) {
                            setState(() {
                              _isInpainting = false;
                            });
                            debugPrint('Error inpainting with polygons: $e');
                          }
                        },
                        child: const Text("Inpaint with Polygons"),
                      ),

                      // Add the debug mask image display
                      if (_debugMaskImage != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                image!.path,
                                width: 400,
                              ),
                              _debugMaskImage!,
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// Visualize the mask from polygons
  Future<void> _visualizeMask() async {
    try {
      // Load image bytes using rootBundle
      final ByteData bytes = await rootBundle.load(image!.path);
      final Uint8List selectedImageBytes = bytes.buffer.asUint8List();

      final debugMask = await InpaintingService.instance.generateDebugMask(
        selectedImageBytes,
        _demoPolygons,
        backgroundColor: Colors.black.withValues(alpha: 0.5),
      );

      setState(() {
        _debugMaskImage = debugMask;
      });
    } catch (e) {
      _showError('Failed to visualize mask: $e');
    }
  }

  void _showError(String message) {
    // Implement error handling logic
    debugPrint(message);
  }
}
