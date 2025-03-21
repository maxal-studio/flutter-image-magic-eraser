import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;

import 'debug_images_page.dart';
import 'visualization_page.dart';

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
  ImageProvider? _imageProvider;

  // Maximum number of polygons
  final int _maxPolygons = 5;

  // Inpainting state
  bool _isInpainting = false;
  bool _useGpu = true;
  double? _lastExecutionTimeMs;
  StreamSubscription<ModelLoadingState>? _modelLoadingSubscription;

  // Polygon drawing controller
  late ImageSelectorController _imageSelectorController;
  DrawingMode _drawingMode = DrawingMode.none;
  List<List<Map<String, double>>> _polygons = [];

  @override
  void initState() {
    super.initState();

    // Initialize polygon controller
    _imageSelectorController = ImageSelectorController();
    _imageSelectorController.onPolygonsChanged = _onPolygonsChanged;
    _imageSelectorController.maxPolygons = _maxPolygons;

    // Subscribe to model loading state changes
    _modelLoadingSubscription =
        InpaintingService.instance.modelLoadingStateStream.listen((state) {
      if (!mounted) return;
      debugPrint('Model loading state: $state');
      setState(() {});
    });

    // Check if the model is loaded
    if (!InpaintingService.instance.isModelLoaded()) {
      // Show error if model is not loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showModelNotLoadedError();
      });
    }
  }

  @override
  void dispose() {
    _modelLoadingSubscription?.cancel();
    _imageSelectorController.dispose();
    _clearImageResources();
    super.dispose();
  }

  /// Clear image resources to prevent memory leaks
  void _clearImageResources() {
    // Reset image provider to release memory
    if (_imageProvider != null) {
      if (_imageProvider is MemoryImage) {
        (_imageProvider as MemoryImage).evict();
      }
      _imageProvider = null;
    }

    // Clear image bytes reference
    _imageBytes = null;
    _selectedImage = null;
  }

  /// Show error if model is not loaded and navigate back
  void _showModelNotLoadedError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error: Model not loaded. Please load the model first.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    // Navigate back after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      // Clear previous image resources
      _clearImageResources();

      // Load the image and get its dimensions
      final bytes = await File(file.path).readAsBytes();
      final image = await decodeImageFromList(bytes);

      if (!mounted) return;

      setState(() {
        _selectedImage = file;
        _imageBytes = bytes;
        _imageProvider = MemoryImage(bytes);
        // Clear existing polygons
        _imageSelectorController.clearPolygons();
      });

      _log('Image loaded: ${image.width}x${image.height}');

      // Dispose the decoded image as we don't need it anymore
      image.dispose();
    } on Exception catch (e) {
      if (!mounted) return;
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
      _imageSelectorController.drawingMode = _drawingMode;
    });
  }

  /// Inpaint with polygons
  Future<void> _inpaintWithPolygons() async {
    if (_imageBytes == null || _imageSelectorController.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image and draw at least one polygon'),
        ),
      );
      return;
    }

    setState(() {
      _isInpainting = true;
      _lastExecutionTimeMs = null;
    });

    try {
      // Convert polygons to the format expected by the inpainting service
      final polygonsData = _imageSelectorController.polygons
          .map((polygon) => polygon.toInpaintingFormat())
          .toList();

      final stopwatch = Stopwatch()..start();

      final result = await InpaintingService.instance.inpaint(
        _imageBytes!,
        polygonsData,
        config: InpaintingConfig(useGpu: _useGpu),
      );

      stopwatch.stop();
      final executionTime = stopwatch.elapsedMilliseconds;

      // Convert ui.Image to Uint8List
      final ByteData? byteData =
          await result.toByteData(format: ui.ImageByteFormat.png);

      // Dispose the result image now that we have the byte data
      result.dispose();

      final Uint8List outputBytes = byteData!.buffer.asUint8List();

      if (!mounted) return;

      // Clear all polygons
      _imageSelectorController.clearPolygons();

      // Clear previous image provider
      if (_imageProvider != null && _imageProvider is MemoryImage) {
        (_imageProvider as MemoryImage).evict();
      }

      setState(() {
        _imageBytes = outputBytes;
        _imageProvider = MemoryImage(outputBytes);
        _isInpainting = false;
        _lastExecutionTimeMs = executionTime.toDouble();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInpainting = false;
        _lastExecutionTimeMs = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during inpainting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// View debug images
  void _showDebugImages() {
    if (_imageBytes == null || _imageSelectorController.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image and draw at least one polygon'),
        ),
      );
      return;
    }

    // Convert polygons to the format expected by the debug images page
    final polygonsData = _imageSelectorController.polygons
        .map((polygon) => polygon.toInpaintingFormat())
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugImagesPage(
          imageBytes: _imageBytes!,
          polygons: polygonsData,
        ),
      ),
    );
  }

  /// Show visualization
  void _showVisualization() {
    if (_imageBytes == null || _imageSelectorController.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image and draw at least one polygon'),
        ),
      );
      return;
    }

    // Convert polygons to the format expected by the visualization page
    final polygonsData = _imageSelectorController.polygons
        .map((polygon) => polygon.toInpaintingFormat())
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisualizationPage(
          imageBytes: _imageBytes!,
          polygons: polygonsData,
        ),
      ),
    );
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

  /// Log debug information
  void _log(String message) {
    debugPrint('[PolygonInpaintingPage] $message');
  }

  @override
  Widget build(BuildContext context) {
    final modelState = InpaintingService.instance.modelLoadingState;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Image Magic Eraser"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: modelState == ModelLoadingState.loading
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
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Control panel
        _buildControlPanel(),

        // Drawing area
        Expanded(
          child:
              _selectedImage == null ? _buildEmptyState() : _buildDrawingArea(),
        ),

        // Status bar
        _buildStatusBar(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_search,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            "No image selected",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Select an image to start erasing objects",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text("Select Image"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingArea() {
    return Center(
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
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageMaskSelector(
                  controller: _imageSelectorController,
                  child: _imageProvider != null
                      ? Image(
                          image: _imageProvider!,
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
              ),
            ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('Select Image'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedImage != null ? _toggleDrawingMode : null,
                  icon: Icon(
                      _drawingMode == DrawingMode.draw
                          ? Icons.edit_off
                          : Icons.edit,
                      size: 18),
                  label: Text(_drawingMode == DrawingMode.draw
                      ? "Stop Drawing"
                      : "Start Drawing"),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                    backgroundColor: _drawingMode == DrawingMode.draw
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                    foregroundColor: _drawingMode == DrawingMode.draw
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _imageSelectorController.clearPolygons,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _imageSelectorController.undoLastPolygon,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _inpaintWithPolygons,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Inpaint'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDebugImages,
                  icon: const Icon(Icons.bug_report, size: 18),
                  label: const Text('Debug'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showVisualization,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Visualize'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers, size: 16),
          const SizedBox(width: 4),
          Text("Selections: ${_polygons.length}/$_maxPolygons"),
          const Spacer(),
          if (_lastExecutionTimeMs != null) ...[
            const Icon(Icons.timer, size: 16),
            const SizedBox(width: 4),
            Text("${(_lastExecutionTimeMs! / 1000).toStringAsFixed(1)}s"),
            const SizedBox(width: 16),
          ],
          Switch(
            value: _useGpu,
            onChanged: (value) => setState(() => _useGpu = value),
          ),
          Text(_useGpu ? 'GPU' : 'CPU'),
        ],
      ),
    );
  }
}
