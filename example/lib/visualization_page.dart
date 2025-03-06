import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;

class VisualizationPage extends StatefulWidget {
  final Uint8List imageBytes;
  final List<List<Map<String, double>>> polygons;

  const VisualizationPage({
    super.key,
    required this.imageBytes,
    required this.polygons,
  });

  @override
  State<VisualizationPage> createState() => _VisualizationPageState();
}

class _VisualizationPageState extends State<VisualizationPage> {
  bool _isLoading = true;
  ui.Image? _visualization;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisualization();
  }

  @override
  void dispose() {
    // Dispose of visualization image
    _disposeVisualization();
    super.dispose();
  }

  /// Dispose of visualization image to free up memory
  void _disposeVisualization() {
    if (_visualization != null) {
      _visualization!.dispose();
      _visualization = null;
    }
  }

  Future<void> _loadVisualization() async {
    try {
      // Dispose any existing visualization first
      _disposeVisualization();

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final visualization =
          await InpaintingService.instance.generateDebugVisualization(
        widget.imageBytes,
        widget.polygons,
      );

      setState(() {
        _visualization = visualization;
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
        title: const Text('Inpainting Visualization'),
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
            Text('Generating visualization...'),
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
              'Error generating visualization',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadVisualization,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_visualization == null) {
      return const Center(
        child: Text('No visualization available'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inpainting Visualization',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This visualization shows the bounding boxes and masks for each polygon.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Visualization',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: RawImage(
                        image: _visualization,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${_visualization!.width}x${_visualization!.height}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Legend:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(Colors.red, 'Polygon Outline'),
                    _buildLegendItem(Colors.blue, 'Bounding Box'),
                    _buildLegendItem(Colors.white.withValues(alpha: 0.7),
                        'Mask Area (to be inpainted)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black45),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
