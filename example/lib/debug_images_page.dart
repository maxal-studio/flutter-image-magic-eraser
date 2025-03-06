import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;

class DebugImagesPage extends StatefulWidget {
  final Uint8List imageBytes;
  final List<List<Map<String, double>>> polygons;

  const DebugImagesPage({
    super.key,
    required this.imageBytes,
    required this.polygons,
  });

  @override
  State<DebugImagesPage> createState() => _DebugImagesPageState();
}

class _DebugImagesPageState extends State<DebugImagesPage> {
  bool _isLoading = true;
  Map<String, ui.Image>? _debugImages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDebugImages();
  }

  @override
  void dispose() {
    // Dispose of debug images when leaving the page
    _disposeDebugImages();
    super.dispose();
  }

  /// Dispose of debug images to free up memory
  void _disposeDebugImages() {
    if (_debugImages != null) {
      InpaintingService.instance.disposeDebugImages(_debugImages!);
      _debugImages = null;
    }
  }

  Future<void> _loadDebugImages() async {
    try {
      // Dispose any existing images first
      _disposeDebugImages();

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final debugImages = await InpaintingService.instance.generateDebugImages(
        widget.imageBytes,
        widget.polygons,
      );

      setState(() {
        _debugImages = debugImages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Images'),
        centerTitle: true,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating debug images...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error generating debug images',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDebugImages,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_debugImages == null || _debugImages!.isEmpty) {
      return const Center(
        child: Text('No debug images available'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Images',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'These images show the different steps of the inpainting process.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ..._debugImages!.entries.map((entry) {
              return _buildDebugImageCard(entry.key, entry.value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugImageCard(String name, ui.Image image) {
    // Format the name for display
    final displayName = name
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _getDescriptionForImage(name),
            const SizedBox(height: 16),
            Center(
              child: RawImage(
                image: image,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Size: ${image.width}x${image.height}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDescriptionForImage(String name) {
    String description;

    switch (name) {
      case 'original':
        description = 'The original input image before any processing.';
        break;
      case 'cropped':
        description =
            'The image cropped to the bounding box of the polygon selection.';
        break;
      case 'mask':
        description =
            'The mask generated from the polygon selection (white areas will be inpainted).';
        break;
      case 'resized_image':
        description =
            'The image resized to the dimensions required by the model.';
        break;
      case 'resized_mask':
        description = 'The mask resized to match the resized image.';
        break;
      case 'inpainted_patch_raw':
        description = 'The raw output from the inpainting model.';
        break;
      case 'inpainted_patch_resized':
        description =
            'The inpainted patch resized back to the original dimensions.';
        break;
      case 'inpainted_patch':
        description =
            'The final inpainted patch that will be blended into the original image.';
        break;
      case 'blended':
        description =
            'Visualization of how the inpainted patch is blended into the original image.';
        break;
      default:
        description = 'Debug image for the inpainting process.';
    }

    return Text(
      description,
      style: TextStyle(fontSize: 14, color: Color(0xFF616161)),
    );
  }
}
