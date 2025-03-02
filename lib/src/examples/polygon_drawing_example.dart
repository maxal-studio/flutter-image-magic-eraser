import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';

/// Example widget demonstrating how to use the polygon drawing widget
class PolygonDrawingExample extends StatefulWidget {
  /// Creates a new polygon drawing example
  const PolygonDrawingExample({super.key});

  @override
  State<PolygonDrawingExample> createState() => _PolygonDrawingExampleState();
}

class _PolygonDrawingExampleState extends State<PolygonDrawingExample> {
  late PolygonPainterController _controller;
  DrawingMode _drawingMode = DrawingMode.none;
  List<List<Map<String, double>>> _polygons = [];

  @override
  void initState() {
    super.initState();
    _controller = PolygonPainterController();
    _controller.onPolygonsChanged = _onPolygonsChanged;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPolygonsChanged(List<List<Map<String, double>>> polygons) {
    setState(() {
      _polygons = polygons;
    });

    // Here you could call your inpainting service with the polygons
    // For example:
    // InpaintingService.instance.inpaint(imageBytes, polygons);
  }

  void _toggleDrawingMode() {
    setState(() {
      _drawingMode = _drawingMode == DrawingMode.none
          ? DrawingMode.draw
          : DrawingMode.none;
      _controller.drawingMode = _drawingMode;
    });
  }

  void _clearPolygons() {
    _controller.clearPolygons();
  }

  void _undoLastPolygon() {
    _controller.undoLastPolygon();
  }

  void _changePolygonStyle() {
    // Example of changing the polygon style
    _controller.strokeColor = Colors.blue;
    _controller.strokeWidth = 3.0;
    _controller.fillColor = const Color.fromRGBO(0, 0, 255, 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polygon Drawing Example'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PolygonDrawingWidget(
              controller: _controller,
              child: Image.asset(
                'assets/example_image.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Polygons: ${_polygons.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _toggleDrawingMode,
                      child: Text(_drawingMode == DrawingMode.draw
                          ? 'Stop Drawing'
                          : 'Start Drawing'),
                    ),
                    ElevatedButton(
                      onPressed: _clearPolygons,
                      child: const Text('Clear All'),
                    ),
                    ElevatedButton(
                      onPressed: _undoLastPolygon,
                      child: const Text('Undo Last'),
                    ),
                    ElevatedButton(
                      onPressed: _changePolygonStyle,
                      child: const Text('Change Style'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
