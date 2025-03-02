import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'debug_page.dart';

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

  // Demo polygons for testing inpainting
  final List<List<Map<String, double>>> _demoPolygons = [
    // Man sitting
    [
      {'x': 223.0, 'y': 347.0},
      {'x': 218.0, 'y': 314.0},
      {'x': 231.0, 'y': 290.0},
      {'x': 239.0, 'y': 263.0},
      {'x': 272.0, 'y': 259.0},
      {'x': 283.0, 'y': 279.0},
      {'x': 279.0, 'y': 306.0},
      {'x': 290.0, 'y': 321.0},
      {'x': 325.0, 'y': 338.0},
      {'x': 350.0, 'y': 368.0},
      {'x': 369.0, 'y': 393.0},
      {'x': 375.0, 'y': 413.0},
      {'x': 381.0, 'y': 419.0},
      {'x': 339.0, 'y': 419.0},
      {'x': 270.0, 'y': 363.0},
    ],
    // Logo
    [
      {'x': 130.0, 'y': 100.0},
      {'x': 301.0, 'y': 100.0},
      {'x': 306.0, 'y': 0},
      {'x': 127.0, 'y': 0},
    ],
    // Man walking
    [
      {'x': 803.0, 'y': 214.0},
      {'x': 792.0, 'y': 260.0},
      {'x': 810.0, 'y': 294.0},
      {'x': 840.0, 'y': 298.0},
      {'x': 820.0, 'y': 218.0},
    ],
  ];

  // Configuration for the inpainting algorithm
  final InpaintingConfig _config = const InpaintingConfig(
    inputSize: 512,
    expandPercentage: 0.3,
    maxExpansionSize: 200,
  );

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

      setState(() {
        _isModelLoaded = true;
        _isLoadingModel = false;
      });
      _showSuccess('Model loaded successfully');
    } catch (e) {
      setState(() {
        _isModelLoaded = false;
        _isLoadingModel = false;
      });
      _showError('Error loading model: $e');
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
      if (file == null) return;

      setState(() {
        image = file;
        // Reset output image when a new image is selected
        _outputImage = null;
      });
    } on Exception catch (e) {
      _showError('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Polygon-Based Inpainting")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DebugPage()),
          );
        },
        tooltip: 'Debug Page',
        child: const Icon(Icons.bug_report),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: (_isLoadingModel)
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Loading model..."),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Image selection row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            const Text("Input Image",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            (image == null)
                                ? ElevatedButton(
                                    onPressed: pickImage,
                                    child: const Text("Pick Image"),
                                  )
                                : Image.file(File(image!.path), width: 800),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Output image
                    if (_isInpainting)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text("Inpainting in progress..."),
                        ],
                      )
                    else if (_outputImage != null)
                      Column(
                        children: [
                          const Text("Inpainted Result",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          RawImage(
                            image: _outputImage,
                            width: 800,
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Inpainting button
                    if (image != null) ...[
                      ElevatedButton(
                        onPressed:
                            _isInpainting ? null : () => _inpaintWithPolygons(),
                        child: const Text("Inpaint Polygons"),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// Inpaint with polygons
  Future<void> _inpaintWithPolygons() async {
    if (_isInpainting || image == null) return;

    setState(() {
      _isInpainting = true;
    });

    try {
      final imageBytes = await File(image!.path).readAsBytes();

      final outputImage = await InpaintingService.instance.inpaint(
        imageBytes,
        _demoPolygons,
        config: _config,
      );

      setState(() {
        _outputImage = outputImage;
        _isInpainting = false;
      });
      _showSuccess('Polygon inpainting completed successfully');
    } catch (e) {
      setState(() {
        _isInpainting = false;
      });
      _showError('Error inpainting with polygons: $e');
    }
  }

  /// Show error message
  void _showError(String message) {
    debugPrint(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
