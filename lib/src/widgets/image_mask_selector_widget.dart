import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../controllers/image_selector_controller.dart';
import '../painters/polygon_painter.dart';

/// A widget that allows drawing polygons on top of an image
class ImageMaskSelector extends StatefulWidget {
  /// The child widget (must be an Image or null)
  final Image? child;

  /// The controller for the polygon painter
  final ImageSelectorController controller;

  /// Minimum distance between points to add a new point
  final double minDistance;

  /// Whether to auto-close the polygon when the user lifts their finger
  final bool autoCloseOnPointerUp;

  /// Creates a new polygon drawing widget
  const ImageMaskSelector({
    super.key,
    this.child,
    required this.controller,
    this.minDistance = 10.0,
    this.autoCloseOnPointerUp = true,
  });

  @override
  State<ImageMaskSelector> createState() => _ImageMaskSelectorState();
}

class _ImageMaskSelectorState extends State<ImageMaskSelector> {
  // Drawing state
  bool _isDrawing = false;

  // Keys and sizes
  final GlobalKey _imageKey = GlobalKey();
  Size? _containerSize;
  Size? _imageSize;
  Rect? _displayRect;

  // Debug mode
  final bool _debug = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);

    // Schedule a post-frame callback to get the image size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSizes();
    });
  }

  @override
  void didUpdateWidget(ImageMaskSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the image has changed
    if (widget.child?.image != oldWidget.child?.image) {
      _log('Image changed, updating sizes and calculations');
      // Reset size-related variables
      _imageSize = null;
      _displayRect = null;
      // Schedule size update on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSizes();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Log debug information
  void _log(String message) {
    if (_debug) {
      developer.log(message, name: 'ImageMaskSelector');
    }
  }

  /// Update container and image sizes
  void _updateSizes() {
    if (!mounted) return;

    // Reset the drawing state when updating sizes
    _isDrawing = false;

    // Get the container size
    final RenderBox? containerBox = context.findRenderObject() as RenderBox?;
    if (containerBox != null) {
      _containerSize = containerBox.size;
      _log('Container size: $_containerSize');
    }

    // Get the image size
    final RenderBox? imageBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (imageBox != null) {
      final imageWidgetSize = imageBox.size;
      _log('Image widget size: $imageWidgetSize');

      // Try to get the actual image dimensions from the Image widget
      if (widget.child?.image != null) {
        // For network or memory images, we need to wait for the image to load
        widget.child!.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (!mounted) return; // Add mounted check

            setState(() {
              _imageSize = Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              );
              _log('Image size from Image widget: $_imageSize');
              _calculateDisplayRect();

              // Stop any ongoing drawing when image size changes
              _isDrawing = false;

              // Update existing polygons to maintain their relative positions
              _updatePolygonPositions();
            });
          }),
        );
      } else {
        _log('Image is null, using widget size as fallback');
        _imageSize = imageWidgetSize;
        _calculateDisplayRect();
      }
    }
  }

  /// Update polygon positions when the display rect changes
  void _updatePolygonPositions() {
    // Only needed if we're transitioning from one display rect to another
    if (_displayRect == null || widget.controller.polygons.isEmpty) return;

    _log('Updating polygon positions for resizing');

    // We don't need to manually update the positions since the PolygonPainter
    // will handle the conversion from image coordinates to screen coordinates
    // based on the new display rect
  }

  /// Calculate the rectangle where the image is displayed
  void _calculateDisplayRect() {
    if (_containerSize == null || _imageSize == null) {
      _log(
          'Cannot calculate display rect: containerSize=$_containerSize, imageSize=$_imageSize');
      return;
    }

    // Get the BoxFit from the Image if available
    BoxFit fit = BoxFit.contain;
    if (widget.child != null) {
      fit = widget.child!.fit ?? BoxFit.contain;
    }

    // Calculate the aspect ratios
    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final containerAspectRatio = _containerSize!.width / _containerSize!.height;

    double displayWidth, displayHeight;
    double offsetX = 0, offsetY = 0;

    // Calculate the display size based on the BoxFit
    if (fit == BoxFit.fill) {
      // Fill the entire container
      displayWidth = _containerSize!.width;
      displayHeight = _containerSize!.height;
    } else if (fit == BoxFit.cover) {
      // Cover the container (may crop the image)
      if (imageAspectRatio > containerAspectRatio) {
        // Image is wider than container (constrained by height)
        displayHeight = _containerSize!.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (_containerSize!.width - displayWidth) / 2;
      } else {
        // Image is taller than container (constrained by width)
        displayWidth = _containerSize!.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (_containerSize!.height - displayHeight) / 2;
      }
    } else if (fit == BoxFit.fitWidth) {
      // Fit width (may crop height)
      displayWidth = _containerSize!.width;
      displayHeight = displayWidth / imageAspectRatio;
      offsetY = (_containerSize!.height - displayHeight) / 2;
    } else if (fit == BoxFit.fitHeight) {
      // Fit height (may crop width)
      displayHeight = _containerSize!.height;
      displayWidth = displayHeight * imageAspectRatio;
      offsetX = (_containerSize!.width - displayWidth) / 2;
    } else {
      // Default to contain (BoxFit.contain)
      if (imageAspectRatio > containerAspectRatio) {
        // Image is wider than container (constrained by width)
        displayWidth = _containerSize!.width;
        displayHeight = displayWidth / imageAspectRatio;
        offsetY = (_containerSize!.height - displayHeight) / 2;
      } else {
        // Image is taller than container (constrained by height)
        displayHeight = _containerSize!.height;
        displayWidth = displayHeight * imageAspectRatio;
        offsetX = (_containerSize!.width - displayWidth) / 2;
      }
    }

    final newRect =
        Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight);
    _log('Display rect: $newRect');

    setState(() {
      _displayRect = newRect;
    });
  }

  /// Handle controller changes
  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Calculate distance between two points
  double _calculateDistance(Offset p1, Offset p2) {
    return (p1 - p2).distance;
  }

  /// Convert screen coordinates to image coordinates
  Offset _screenToImageCoordinates(Offset screenPoint) {
    if (_displayRect == null || _imageSize == null) {
      _log(
          'Cannot convert coordinates: displayRect=$_displayRect, imageSize=$_imageSize');
      return screenPoint;
    }

    // Check if the point is within the image bounds
    if (!_displayRect!.contains(screenPoint)) {
      _log('Point outside image bounds: $screenPoint');
      return Offset(-1, -1); // Return invalid coordinates
    }

    // Calculate the relative position within the displayed image (0.0 to 1.0)
    final relativeX =
        (screenPoint.dx - _displayRect!.left) / _displayRect!.width;
    final relativeY =
        (screenPoint.dy - _displayRect!.top) / _displayRect!.height;

    // Convert to image coordinates
    final imageX = relativeX * _imageSize!.width;
    final imageY = relativeY * _imageSize!.height;

    return Offset(imageX, imageY);
  }

  /// Check if a point is within the image bounds
  bool _isPointInImage(Offset point) {
    if (_displayRect == null) return false;
    return _displayRect!.contains(point);
  }

  /// Handle pointer down events
  void _onPointerDown(PointerDownEvent event) {
    if (widget.controller.drawingMode != DrawingMode.draw) return;

    // Don't allow drawing if image size or display rect isn't calculated yet
    if (_imageSize == null || _displayRect == null) {
      _log('Cannot start drawing: image size or display rect not ready');
      return;
    }

    // Only start drawing if the point is within the image bounds
    if (!_isPointInImage(event.localPosition)) {
      _log('Pointer down outside image bounds: ${event.localPosition}');
      return;
    }

    final imagePoint = _screenToImageCoordinates(event.localPosition);

    // Only start drawing if the point is valid
    if (imagePoint.dx >= 0 && imagePoint.dy >= 0) {
      _isDrawing = true;
      widget.controller.startPolygon(imagePoint);
      _log('Started polygon at $imagePoint');
    }
  }

  /// Handle pointer move events
  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDrawing || widget.controller.drawingMode != DrawingMode.draw) {
      return;
    }

    // Only continue drawing if the point is within the image bounds
    if (!_isPointInImage(event.localPosition)) {
      _log('Pointer move outside image bounds: ${event.localPosition}');
      return;
    }

    final imagePoint = _screenToImageCoordinates(event.localPosition);

    // Only continue drawing if the point is valid
    if (imagePoint.dx >= 0 && imagePoint.dy >= 0) {
      // Only add a point if it's far enough from the last point
      final activePolygon = widget.controller.activePolygon;
      if (activePolygon != null && activePolygon.points.isNotEmpty) {
        final lastPoint = activePolygon.points.last;
        final distance = _calculateDistance(lastPoint, imagePoint);

        if (distance >= widget.minDistance) {
          widget.controller.addPoint(imagePoint);
          _log('Added point at $imagePoint, distance=$distance');
        }
      }
    }
  }

  /// Handle pointer up events
  void _onPointerUp(PointerUpEvent event) {
    if (!_isDrawing) return;

    _isDrawing = false;

    // Auto-close the polygon if enabled
    if (widget.autoCloseOnPointerUp) {
      widget.controller.closePolygon();
      _log('Closed polygon');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);

        // If the size changed, update the sizes
        if (_containerSize != currentSize) {
          _log('Container size changed from $_containerSize to $currentSize');
          _containerSize = currentSize;
          // Schedule an update after the layout is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateSizes();
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // The image widget (if provided)
            if (widget.child != null)
              Center(
                child: KeyedSubtree(
                  key: _imageKey,
                  child: _buildImageWithFullSize(widget.child!),
                ),
              ),

            // The polygon drawing layer
            if (_displayRect != null && _imageSize != null)
              Positioned.fill(
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  child: CustomPaint(
                    painter: PolygonPainter(
                      polygons: widget.controller.polygons,
                      activePolygon: widget.controller.activePolygon,
                      imageSize: _imageSize!,
                      displayRect: _displayRect!,
                      debug: _debug,
                    ),
                    size: currentSize,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build an image with full size (width and height set to double.infinity)
  Widget _buildImageWithFullSize(Image image) {
    // Create a new image with the same properties but with width and height set to double.infinity
    return Image(
      image: image.image,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      alignment: image.alignment,
      color: image.color,
      colorBlendMode: image.colorBlendMode,
      semanticLabel: image.semanticLabel,
      excludeFromSemantics: image.excludeFromSemantics,
      filterQuality: image.filterQuality,
      isAntiAlias: image.isAntiAlias,
      repeat: image.repeat,
      centerSlice: image.centerSlice,
      matchTextDirection: image.matchTextDirection,
      gaplessPlayback: image.gaplessPlayback,
      frameBuilder: image.frameBuilder,
      loadingBuilder: image.loadingBuilder,
      errorBuilder: image.errorBuilder,
    );
  }
}
