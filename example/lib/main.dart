import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;

import 'debug_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Magic Eraser Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PolygonInpaintingPage(),
    );
  }
}

class PolygonInpaintingPage extends StatefulWidget {
  const PolygonInpaintingPage({super.key});

  @override
  State<PolygonInpaintingPage> createState() => _PolygonInpaintingPageState();
}

class _PolygonInpaintingPageState extends State<PolygonInpaintingPage> {
  // Image picker
  static final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  Size? _imageSize;
  ImageProvider? _imageProvider;

  // Maximum number of polygons
  int _maxPolygons = 5;

  // Inpainting state
  bool _isModelLoaded = false;
  bool _isInpainting = false;
  bool _isLoadingModel = false;

  // Polygon drawing controller
  late PolygonPainterController _polygonController;
  DrawingMode _drawingMode = DrawingMode.none;
  List<List<Map<String, double>>> _polygons = [];

  @override
  void initState() {
    super.initState();

    // Initialize polygon controller
    _polygonController = PolygonPainterController();
    _polygonController.onPolygonsChanged = _onPolygonsChanged;
    _polygonController.maxPolygons = _maxPolygons;

    // Check if model is already loaded
    _isModelLoaded = InpaintingService.instance.isModelLoaded();

    if (!_isModelLoaded) {
      _loadModel();
    }
  }

  @override
  void dispose() {
    _polygonController.dispose();
    super.dispose();
  }

  /// Load the inpainting model
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

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      // Load the image and get its dimensions
      final bytes = await File(file.path).readAsBytes();
      final image = await decodeImageFromList(bytes);

      setState(() {
        _selectedImage = file;
        _imageBytes = bytes;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _imageProvider = MemoryImage(bytes);
        // Clear existing polygons
        _polygonController.clearPolygons();
      });

      _log('Image loaded: ${image.width}x${image.height}');
    } on Exception catch (e) {
      _showError('Error picking image: $e');
    }
  }

  /// Handle polygon changes
  void _onPolygonsChanged(List<List<Map<String, double>>> polygons) {
    setState(() {
      _polygons = polygons;
    });

    inspect(_polygons);
  }

  /// Toggle drawing mode
  void _toggleDrawingMode() {
    setState(() {
      _drawingMode = _drawingMode == DrawingMode.none
          ? DrawingMode.draw
          : DrawingMode.none;
      _polygonController.drawingMode = _drawingMode;
    });
  }

  /// Update maximum number of polygons
  void _updateMaxPolygons(int value) {
    setState(() {
      _maxPolygons = value;
      _polygonController.maxPolygons = value;
    });
    _showSuccess('Maximum polygons set to $value');
  }

  /// Inpaint with polygons
  Future<void> _inpaintWithPolygons() async {
    if (_isInpainting || _selectedImage == null || _polygons.isEmpty) {
      if (_polygons.isEmpty) {
        _showError('Please draw at least one polygon to erase');
      }
      return;
    }

    setState(() {
      _isInpainting = true;
    });

    try {
      final imageBytes =
          _imageBytes ?? await File(_selectedImage!.path).readAsBytes();

      final outputImage = await InpaintingService.instance.inpaint(
        imageBytes,
        _polygons,
      );

      // Convert the ui.Image to bytes for the Image widget
      final ByteData? byteData =
          await outputImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List outputBytes = byteData!.buffer.asUint8List();

      setState(() {
        _imageBytes = outputBytes;
        _imageProvider = MemoryImage(outputBytes);
        _imageSize =
            Size(outputImage.width.toDouble(), outputImage.height.toDouble());
        _isInpainting = false;
        // Clear polygons after successful inpainting
        _polygonController.clearPolygons();
      });
      _showSuccess('Areas successfully erased');
    } catch (e) {
      setState(() {
        _isInpainting = false;
      });
      _showError('Error erasing areas: $e');
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

  /// Log debug information
  void _log(String message) {
    debugPrint('[PolygonInpaintingPage] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Interactive Polygon Inpainting"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugPage()),
              );
            },
            tooltip: 'Debug Page',
          ),
        ],
      ),
      body: _isLoadingModel
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
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Image selection row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                child: Text(
                    _selectedImage == null ? "Pick Image" : "Change Image"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _selectedImage != null ? _toggleDrawingMode : null,
                child: Text(_drawingMode == DrawingMode.draw
                    ? "Stop Drawing"
                    : "Start Drawing"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _polygons.isNotEmpty
                    ? _polygonController.clearPolygons
                    : null,
                child: const Text("Clear All"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _polygons.isNotEmpty
                    ? _polygonController.undoLastPolygon
                    : null,
                child: const Text("Undo Last"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: (_selectedImage != null &&
                        _polygons.isNotEmpty &&
                        !_isInpainting)
                    ? _inpaintWithPolygons
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Erase"),
              ),
            ],
          ),
        ),

        // Max polygons setting
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Max Polygons: "),
              DropdownButton<int>(
                value: _maxPolygons,
                items: [1, 3, 5, 10, 15, 20].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    _updateMaxPolygons(newValue);
                  }
                },
              ),
            ],
          ),
        ),

        // Drawing area
        Expanded(
          child: _selectedImage == null
              ? const Center(child: Text("Please select an image"))
              : Center(
                  child: _isInpainting
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Erasing selected areas..."),
                          ],
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: Colors.black12, // Light gray background
                          ),
                          child: PolygonDrawingWidget(
                            controller: _polygonController,
                            child: _imageProvider != null
                                ? Image(
                                    image: _imageProvider!,
                                  )
                                : null,
                          ),
                        ),
                ),
        ),

        // Status bar
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Polygons: ${_polygons.length}/$_maxPolygons"),
              if (_imageSize != null)
                Text(
                    "Image: ${_imageSize!.width.toInt()}x${_imageSize!.height.toInt()}"),
              Text(
                  "Drawing Mode: ${_drawingMode == DrawingMode.draw ? 'Active' : 'Inactive'}"),
              Text("Model: ${_isModelLoaded ? 'Loaded' : 'Not Loaded'}"),
            ],
          ),
        ),
      ],
    );
  }
}
