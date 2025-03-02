import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  ui.Image? _outputImage;
  bool _isModelLoaded = false;
  bool _isInpainting = false;
  bool _isLoadingModel = false;
  static ImagePicker imagePicker = ImagePicker();

  // Debug images
  Map<String, ui.Image> _debugImages = {};
  bool _showDebugImages = false;

  // Visualization for polygons and bounding boxes
  ui.Image? _visualizationImage;
  bool _showVisualization = false;

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

  /// Pick image from gallery
  Future<void> pickImage() async {
    try {
      final file = await imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() {
        image = file;
        // Reset output and debug images when a new image is selected
        _outputImage = null;
        _debugImages = {};
        _showDebugImages = false;
        _visualizationImage = null;
        _showVisualization = false;
      });
    } on Exception catch (e) {
      _showError('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inpainting Debug")),
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

                    // Debug buttons
                    if (image != null) ...[
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16.0,
                        runSpacing: 16.0,
                        children: [
                          ElevatedButton(
                            onPressed: _isInpainting
                                ? null
                                : () => _inpaintWithPolygons(),
                            child: const Text("Inpaint Polygons"),
                          ),
                          ElevatedButton(
                            onPressed:
                                _isInpainting ? null : _generateDebugImages,
                            child: const Text("Generate Debug Images"),
                          ),
                          ElevatedButton(
                            onPressed:
                                _isInpainting ? null : _showPolygonsAndBoxes,
                            child: const Text("Show Polygons & Boxes"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Visualization of polygons and bounding boxes
                      if (_showVisualization &&
                          _visualizationImage != null) ...[
                        const Divider(),
                        const Text("Polygon & Bounding Box Visualization",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        RawImage(
                          image: _visualizationImage,
                          width: 800,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Debug images section
                      if (_showDebugImages && _debugImages.isNotEmpty) ...[
                        const Divider(),
                        const Text("Debug Images",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),

                        // Original image
                        if (_debugImages.containsKey('original')) ...[
                          const Text("Original Image",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          RawImage(
                            image: _debugImages['original'],
                            width: 800,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Final result
                        if (_debugImages.containsKey('final_result')) ...[
                          const Text("Final Result",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          RawImage(
                            image: _debugImages['final_result'],
                            width: 800,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Process for each polygon
                        for (int i = 0; i < _demoPolygons.length; i++) ...[
                          if (_debugImages
                              .containsKey('before_polygon_$i')) ...[
                            Divider(),
                            Text("Polygon $i Processing",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Points: ${_demoPolygons[i].length}",
                                style: TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),

                            // Before and after for this polygon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_debugImages
                                    .containsKey('before_polygon_$i')) ...[
                                  Column(
                                    children: [
                                      const Text("Before",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      RawImage(
                                        image:
                                            _debugImages['before_polygon_$i'],
                                        width: 512,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                if (_debugImages
                                    .containsKey('after_polygon_$i')) ...[
                                  Column(
                                    children: [
                                      const Text("After",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      RawImage(
                                        image: _debugImages['after_polygon_$i'],
                                        width: 512,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Cropped image and mask
                            if (_debugImages.containsKey('cropped_$i') &&
                                _debugImages.containsKey('mask_$i')) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Column(
                                    children: [
                                      const Text("Cropped",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      RawImage(
                                        image: _debugImages['cropped_$i'],
                                        width: 512,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    children: [
                                      const Text("Mask",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      RawImage(
                                        image: _debugImages['mask_$i'],
                                        width: 512,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Inpainted patch
                            if (_debugImages
                                .containsKey('inpainted_patch_$i')) ...[
                              const Text("Inpainted Patch",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              RawImage(
                                image: _debugImages['inpainted_patch_$i'],
                                width: 800,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Blend visualization
                            if (_debugImages
                                .containsKey('blend_visualization_$i')) ...[
                              const Text("Blend Visualization",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              RawImage(
                                image: _debugImages['blend_visualization_$i'],
                                width: 800,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ],

                        // Detailed debug images (expandable section)
                        ExpansionTile(
                          title: const Text("Detailed Debug Images",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          children: [
                            // Original image
                            if (_debugImages.containsKey('original')) ...[
                              const Text("Original Image",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              RawImage(
                                image: _debugImages['original'],
                                width: 800,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Process for each polygon - detailed
                            for (int i = 0; i < _demoPolygons.length; i++) ...[
                              if (_debugImages
                                  .containsKey('before_polygon_$i')) ...[
                                Divider(),
                                Text("Polygon $i - Detailed",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 8),

                                // Resized images (if available)
                                if (_debugImages
                                    .containsKey('resized_image_$i')) ...[
                                  const Text("Resized Image (Model Input)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RawImage(
                                    image: _debugImages['resized_image_$i'],
                                    width: 800,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                if (_debugImages
                                    .containsKey('resized_mask_$i')) ...[
                                  const Text("Resized Mask (Model Input)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RawImage(
                                    image: _debugImages['resized_mask_$i'],
                                    width: 800,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Inpainted patch raw
                                if (_debugImages
                                    .containsKey('inpainted_patch_raw_$i')) ...[
                                  const Text(
                                      "Raw Inpainted Patch (Model Output)",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RawImage(
                                    image:
                                        _debugImages['inpainted_patch_raw_$i'],
                                    width: 800,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Resized inpainted patch
                                if (_debugImages.containsKey(
                                    'inpainted_patch_resized_$i')) ...[
                                  const Text("Resized Inpainted Patch",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RawImage(
                                    image: _debugImages[
                                        'inpainted_patch_resized_$i'],
                                    width: 800,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// Inpaint with polygons
  Future<void> _inpaintWithPolygons() async {
    if (image == null) return;

    setState(() {
      _isInpainting = true;
      // Reset debug images and visualization when starting a new inpainting operation
      _debugImages = {};
      _showDebugImages = false;
      _visualizationImage = null;
      _showVisualization = false;
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

  /// Generate debug images for each step of the inpainting process
  Future<void> _generateDebugImages() async {
    if (image == null) return;

    setState(() {
      _isInpainting = true;
      // Reset visualization when generating debug images
      _visualizationImage = null;
      _showVisualization = false;
    });

    try {
      final imageBytes = await File(image!.path).readAsBytes();

      final debugImages = await InpaintingService.instance.generateDebugImages(
        imageBytes,
        _demoPolygons,
        config: _config,
      );

      setState(() {
        _debugImages = debugImages;
        _showDebugImages = true;
        _isInpainting = false;
      });
      _showSuccess('Debug images generated successfully');
    } catch (e) {
      setState(() {
        _isInpainting = false;
      });
      _showError('Error generating debug images: $e');
    }
  }

  /// Show polygons and bounding boxes for debugging
  Future<void> _showPolygonsAndBoxes() async {
    if (image == null) return;

    setState(() {
      _isInpainting = true;
      // Reset debug images when showing visualization
      _debugImages = {};
      _showDebugImages = false;
    });

    try {
      final imageBytes = await File(image!.path).readAsBytes();

      final visualization =
          await InpaintingService.instance.generateDebugVisualization(
        imageBytes,
        _demoPolygons,
        config: _config,
      );

      setState(() {
        _visualizationImage = visualization;
        _showVisualization = true;
        _isInpainting = false;
      });
      _showSuccess('Visualization generated successfully');
    } catch (e) {
      setState(() {
        _isInpainting = false;
      });
      _showError('Error generating visualization: $e');
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
