import 'package:flutter/material.dart';

import '../models/polygon.dart';

/// Enum representing the drawing mode
enum DrawingMode {
  /// No drawing is allowed
  none,

  /// Drawing polygons is allowed
  draw,
}

/// Controller for the image selector widget
class ImageSelectorController extends ChangeNotifier {
  /// Current drawing mode
  DrawingMode _drawingMode = DrawingMode.none;

  /// List of polygons
  final List<Polygon> _polygons = [];

  /// Currently active polygon being drawn
  Polygon? _activePolygon;

  /// Maximum number of polygons allowed
  int _maxPolygons = 10;

  /// Default stroke color for new polygons
  Color _strokeColor = Colors.red;

  /// Default stroke width for new polygons
  double _strokeWidth = 2.0;

  /// Default fill color for new polygons
  Color _fillColor = const Color.fromRGBO(255, 0, 0, 0.2);

  /// Callback for when polygons change
  Function(List<List<Map<String, double>>>)? onPolygonsChanged;

  /// Gets the current drawing mode
  DrawingMode get drawingMode => _drawingMode;

  /// Gets the list of polygons
  List<Polygon> get polygons => List.unmodifiable(_polygons);

  /// Gets the currently active polygon
  Polygon? get activePolygon => _activePolygon;

  /// Gets the maximum number of polygons allowed
  int get maxPolygons => _maxPolygons;

  /// Gets the default stroke color
  Color get strokeColor => _strokeColor;

  /// Gets the default stroke width
  double get strokeWidth => _strokeWidth;

  /// Gets the default fill color
  Color get fillColor => _fillColor;

  /// Sets the drawing mode
  set drawingMode(DrawingMode mode) {
    _drawingMode = mode;
    notifyListeners();
  }

  /// Sets the maximum number of polygons allowed
  set maxPolygons(int value) {
    _maxPolygons = value;
    // If we have more polygons than allowed, remove the oldest ones
    if (_polygons.length > _maxPolygons) {
      _polygons.removeRange(0, _polygons.length - _maxPolygons);
      _notifyPolygonsChanged();
    }
    notifyListeners();
  }

  /// Sets the default stroke color
  set strokeColor(Color color) {
    _strokeColor = color;
    notifyListeners();
  }

  /// Sets the default stroke width
  set strokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  /// Sets the default fill color
  set fillColor(Color color) {
    _fillColor = color;
    notifyListeners();
  }

  /// Starts a new polygon
  void startPolygon(Offset point) {
    if (_drawingMode != DrawingMode.draw) return;

    // Check if we've reached the maximum number of polygons
    if (_polygons.length >= _maxPolygons) {
      // Remove the oldest polygon
      _polygons.removeAt(0);
    }

    _activePolygon = Polygon(
      points: [point],
      strokeColor: _strokeColor,
      strokeWidth: _strokeWidth,
      fillColor: _fillColor,
      isClosed: false,
    );

    notifyListeners();
  }

  /// Adds a point to the active polygon
  void addPoint(Offset point) {
    if (_drawingMode != DrawingMode.draw || _activePolygon == null) return;

    final updatedPoints = List<Offset>.from(_activePolygon!.points)..add(point);
    _activePolygon = _activePolygon!.copyWith(points: updatedPoints);

    notifyListeners();
  }

  /// Closes the active polygon
  void closePolygon() {
    if (_activePolygon == null) return;

    // Only close if we have at least 3 points
    if (_activePolygon!.points.length >= 3) {
      final closedPolygon = _activePolygon!.copyWith(isClosed: true);
      _polygons.add(closedPolygon);
      _notifyPolygonsChanged();
    }

    _activePolygon = null;
    notifyListeners();
  }

  /// Clears all polygons
  void clearPolygons() {
    _polygons.clear();
    _activePolygon = null;
    _notifyPolygonsChanged();
    notifyListeners();
  }

  /// Undoes the last polygon
  void undoLastPolygon() {
    if (_polygons.isNotEmpty) {
      _polygons.removeLast();
      _notifyPolygonsChanged();
      notifyListeners();
    }
  }

  /// Notifies listeners of polygon changes
  void _notifyPolygonsChanged() {
    if (onPolygonsChanged != null) {
      final polygonsData =
          _polygons.map((polygon) => polygon.toInpaintingFormat()).toList();

      onPolygonsChanged!(polygonsData);
    }
  }

  /// Sets the polygons from a list of polygon data
  void setPolygons(List<List<Map<String, double>>> polygonsData) {
    _polygons.clear();

    for (final polygonData in polygonsData) {
      final polygon = Polygon.fromInpaintingFormat(
        polygonData,
        strokeColor: _strokeColor,
        strokeWidth: _strokeWidth,
        fillColor: _fillColor,
      );

      _polygons.add(polygon);
    }

    _notifyPolygonsChanged();
    notifyListeners();
  }
}
