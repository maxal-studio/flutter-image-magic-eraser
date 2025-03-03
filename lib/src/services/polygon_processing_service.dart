import 'dart:math' hide log;
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Service for processing and optimizing polygons
class PolygonProcessingService {
  PolygonProcessingService._internal();

  static final PolygonProcessingService _instance =
      PolygonProcessingService._internal();

  static PolygonProcessingService get instance => _instance;

  /// Process polygons by filtering and merging them
  ///
  /// 1. Removes polygons with less than 3 points
  /// 2. Merges polygons that touch or intersect each other
  List<List<Map<String, double>>> processPolygons(
      List<List<Map<String, double>>> polygons) {
    if (polygons.isEmpty) return [];

    try {
      // Step 1: Filter out polygons with less than 3 points
      var validPolygons =
          polygons.where((polygon) => polygon.length >= 3).toList();
      if (validPolygons.isEmpty) return [];

      // Step 2: Group touching polygons
      var mergedPolygons = _mergeConnectedPolygons(validPolygons);

      if (kDebugMode) {
        dev.log(
          'Processed ${polygons.length} polygons into ${mergedPolygons.length} merged polygons',
          name: 'PolygonProcessingService',
        );
      }

      return mergedPolygons;
    } catch (e) {
      if (kDebugMode) {
        dev.log(
          'Error processing polygons: $e',
          name: 'PolygonProcessingService',
          error: e,
        );
      }
      // Return filtered polygons if merging fails
      return polygons.where((polygon) => polygon.length >= 3).toList();
    }
  }

  /// Merge polygons that touch or intersect each other
  List<List<Map<String, double>>> _mergeConnectedPolygons(
      List<List<Map<String, double>>> polygons) {
    if (polygons.length < 2) return polygons;

    List<Set<int>> connectedGroups = [];

    // Find connected polygons
    for (var i = 0; i < polygons.length; i++) {
      for (var j = i + 1; j < polygons.length; j++) {
        if (_doPolygonsTouch(polygons[i], polygons[j])) {
          // Find or create groups for these polygons
          var groupFound = false;
          for (var group in connectedGroups) {
            if (group.contains(i) || group.contains(j)) {
              group.add(i);
              group.add(j);
              groupFound = true;
              break;
            }
          }
          if (!groupFound) {
            connectedGroups.add({i, j});
          }
        }
      }
    }

    // Merge groups that share polygons
    connectedGroups = _mergeOverlappingGroups(connectedGroups);

    // Create result by merging polygons in each group
    List<List<Map<String, double>>> result = [];
    Set<int> processedIndices = {};

    // Process grouped polygons
    for (var group in connectedGroups) {
      var mergedPolygon =
          _mergePolygonGroup(group.map((i) => polygons[i]).toList());
      result.add(mergedPolygon);
      processedIndices.addAll(group);
    }

    // Add ungrouped polygons
    for (var i = 0; i < polygons.length; i++) {
      if (!processedIndices.contains(i)) {
        result.add(polygons[i]);
      }
    }

    return result;
  }

  /// Merge overlapping groups of polygon indices
  List<Set<int>> _mergeOverlappingGroups(List<Set<int>> groups) {
    if (groups.isEmpty) return groups;

    bool merged;
    do {
      merged = false;
      for (var i = 0; i < groups.length; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          if (groups[i].intersection(groups[j]).isNotEmpty) {
            groups[i].addAll(groups[j]);
            groups.removeAt(j);
            merged = true;
            break;
          }
        }
        if (merged) break;
      }
    } while (merged);

    return groups;
  }

  /// Check if two polygons touch or intersect
  bool _doPolygonsTouch(
      List<Map<String, double>> poly1, List<Map<String, double>> poly2) {
    // Check if any points are very close to each other
    const double threshold =
        2.0; // Threshold for considering points as touching

    for (var point1 in poly1) {
      for (var point2 in poly2) {
        var dx = point1['x']! - point2['x']!;
        var dy = point1['y']! - point2['y']!;
        var distance = sqrt(dx * dx + dy * dy);
        if (distance < threshold) {
          return true;
        }
      }
    }

    // Check if any line segments intersect
    for (var i = 0; i < poly1.length; i++) {
      var j = (i + 1) % poly1.length;
      var line1Start = poly1[i];
      var line1End = poly1[j];

      for (var k = 0; k < poly2.length; k++) {
        var l = (k + 1) % poly2.length;
        var line2Start = poly2[k];
        var line2End = poly2[l];

        if (_doLinesIntersect(
          line1Start['x']!,
          line1Start['y']!,
          line1End['x']!,
          line1End['y']!,
          line2Start['x']!,
          line2Start['y']!,
          line2End['x']!,
          line2End['y']!,
        )) {
          return true;
        }
      }
    }

    // Check if one polygon is contained within the other
    var poly1ContainsPoly2 =
        poly2.every((point) => _isPointInPolygon(point, poly1));
    var poly2ContainsPoly1 =
        poly1.every((point) => _isPointInPolygon(point, poly2));

    return poly1ContainsPoly2 || poly2ContainsPoly1;
  }

  /// Check if two line segments intersect
  bool _doLinesIntersect(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double x4,
    double y4,
  ) {
    var denominator = ((x2 - x1) * (y4 - y3)) - ((y2 - y1) * (x4 - x3));
    if (denominator == 0) return false;

    var ua = (((x4 - x3) * (y1 - y3)) - ((y4 - y3) * (x1 - x3))) / denominator;
    var ub = (((x2 - x1) * (y1 - y3)) - ((y2 - y1) * (x1 - x3))) / denominator;

    return (ua >= 0 && ua <= 1) && (ub >= 0 && ub <= 1);
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(
      Map<String, double> point, List<Map<String, double>> polygon) {
    if (polygon.length < 3) return false;

    var x = point['x']!;
    var y = point['y']!;
    var inside = false;

    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      var xi = polygon[i]['x']!;
      var yi = polygon[i]['y']!;
      var xj = polygon[j]['x']!;
      var yj = polygon[j]['y']!;

      var intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Merge a group of polygons into a single polygon
  List<Map<String, double>> _mergePolygonGroup(
      List<List<Map<String, double>>> group) {
    if (group.length == 1) return group[0];

    // Create a list to store the merged polygon points
    List<Map<String, double>> mergedPoints = [];

    // Start with the first polygon
    mergedPoints.addAll(group[0]);

    // Process each additional polygon
    for (var i = 1; i < group.length; i++) {
      var currentPolygon = group[i];

      // Find the closest pair of points between the merged polygon and current polygon
      var closestPair = _findClosestPoints(mergedPoints, currentPolygon);
      var mergedIndex = closestPair.item1;
      var currentIndex = closestPair.item2;

      // Insert the points from the current polygon into the merged polygon
      // starting from the closest point and maintaining order
      var newPoints = <Map<String, double>>[];
      newPoints.addAll(mergedPoints.sublist(0, mergedIndex + 1));

      // Add points from current polygon in order
      for (var j = 0; j < currentPolygon.length; j++) {
        var idx = (j + currentIndex) % currentPolygon.length;
        var point = currentPolygon[idx];
        if (!_pointExists(point, newPoints)) {
          newPoints.add(point);
        }
      }

      // Add first point of current polygon to close the shape if needed
      var firstPoint = currentPolygon[currentIndex];
      if (!_pointEquals(newPoints.last, firstPoint)) {
        newPoints.add(firstPoint);
      }

      // Add remaining points from merged polygon
      for (var j = mergedIndex + 1; j < mergedPoints.length; j++) {
        if (!_pointExists(mergedPoints[j], newPoints)) {
          newPoints.add(mergedPoints[j]);
        }
      }

      mergedPoints = newPoints;
    }

    // Remove duplicate consecutive points
    mergedPoints = _removeConsecutiveDuplicates(mergedPoints);

    return mergedPoints;
  }

  /// Find the closest pair of points between two polygons
  ({int item1, int item2}) _findClosestPoints(
    List<Map<String, double>> poly1,
    List<Map<String, double>> poly2,
  ) {
    var minDistance = double.infinity;
    var poly1Index = 0;
    var poly2Index = 0;

    for (var i = 0; i < poly1.length; i++) {
      for (var j = 0; j < poly2.length; j++) {
        var distance = _pointDistance(poly1[i], poly2[j]);
        if (distance < minDistance) {
          minDistance = distance;
          poly1Index = i;
          poly2Index = j;
        }
      }
    }

    return (item1: poly1Index, item2: poly2Index);
  }

  /// Calculate distance between two points
  double _pointDistance(Map<String, double> p1, Map<String, double> p2) {
    var dx = p1['x']! - p2['x']!;
    var dy = p1['y']! - p2['y']!;
    return sqrt(dx * dx + dy * dy);
  }

  /// Check if a point exists in a list of points
  bool _pointExists(
      Map<String, double> point, List<Map<String, double>> points) {
    return points.any((p) => _pointEquals(p, point));
  }

  /// Check if two points are equal
  bool _pointEquals(Map<String, double> p1, Map<String, double> p2) {
    const epsilon = 0.0001; // Small threshold for floating-point comparison
    return (p1['x']! - p2['x']!).abs() < epsilon &&
        (p1['y']! - p2['y']!).abs() < epsilon;
  }

  /// Remove consecutive duplicate points
  List<Map<String, double>> _removeConsecutiveDuplicates(
      List<Map<String, double>> points) {
    if (points.length <= 1) return points;

    var result = <Map<String, double>>[points[0]];
    for (var i = 1; i < points.length; i++) {
      if (!_pointEquals(points[i], result.last)) {
        result.add(points[i]);
      }
    }

    // Check if the last point equals the first point
    if (result.length > 1 && _pointEquals(result.first, result.last)) {
      result.removeLast();
    }

    return result;
  }
}
