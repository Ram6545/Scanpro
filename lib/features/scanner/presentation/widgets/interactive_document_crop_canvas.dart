import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The active handle or element being manipulated by the user.
enum CropHandleType {
  topLeftCorner,
  topRightCorner,
  bottomRightCorner,
  bottomLeftCorner,
  topEdge,
  rightEdge,
  bottomEdge,
  leftEdge,
  wholeQuad,
}

/// A high-precision, touch-friendly 4-corner & 4-edge document cropping canvas.
///
/// Features:
/// - Generous hit targets (corners, edge midpoints, and proximity line snapping)
///   so users can easily "catch" any edge or corner with large fingers.
/// - Edge dragging: dragging an edge moves both adjacent corners in unison.
/// - Real-time floating Magnifier Loupe: 2.2x zoom above the user's finger with
///   crosshairs for pixel-perfect edge alignment without obstruction.
/// - True aspect-ratio rendering (no image squashing/stretching).
/// - Haptic feedback upon catching and releasing handles.
class InteractiveDocumentCropCanvas extends StatefulWidget {
  const InteractiveDocumentCropCanvas({
    super.key,
    required this.imagePath,
    required this.corners,
    required this.onCornersChanged,
    this.accentColor = const Color(0xFF00897B),
  });

  final String imagePath;
  final List<Offset> corners;
  final ValueChanged<List<Offset>> onCornersChanged;
  final Color accentColor;

  @override
  State<InteractiveDocumentCropCanvas> createState() =>
      _InteractiveDocumentCropCanvasState();
}

class _InteractiveDocumentCropCanvasState
    extends State<InteractiveDocumentCropCanvas> {
  ui.Image? _uiImage;
  Size? _imageNaturalSize;

  CropHandleType? _activeHandle;
  Offset? _dragStartPos;
  List<Offset>? _dragStartCorners;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant InteractiveDocumentCropCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _uiImage?.dispose();
      _uiImage = null;
      _imageNaturalSize = null;
      _loadImage();
    }
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
          _imageNaturalSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
        });
      }
    } catch (_) {}
  }

  /// Calculates the proportional rectangle within [boxSize] that matches
  /// the image's aspect ratio.
  Rect _calculateImageRect(Size boxSize) {
    if (_imageNaturalSize == null ||
        _imageNaturalSize!.width == 0 ||
        _imageNaturalSize!.height == 0) {
      return Rect.fromLTWH(0, 0, boxSize.width, boxSize.height);
    }

    final imgAspect = _imageNaturalSize!.width / _imageNaturalSize!.height;
    final boxAspect = boxSize.width / boxSize.height;

    if (boxAspect > imgAspect) {
      final h = boxSize.height;
      final w = h * imgAspect;
      final left = (boxSize.width - w) / 2;
      return Rect.fromLTWH(left, 0, w, h);
    } else {
      final w = boxSize.width;
      final h = w / imgAspect;
      final top = (boxSize.height - h) / 2;
      return Rect.fromLTWH(0, top, w, h);
    }
  }

  List<Offset> _toScreenPoints(Rect imgRect) {
    return widget.corners
        .map((c) => Offset(
              imgRect.left + c.dx * imgRect.width,
              imgRect.top + c.dy * imgRect.height,
            ))
        .toList();
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 < 0.0001) return (p - a).distance;
    final t = (((p.dx - a.dx) * (b.dx - a.dx) +
                (p.dy - a.dy) * (b.dy - a.dy)) /
            l2)
        .clamp(0.0, 1.0);
    final projection = Offset(
      a.dx + t * (b.dx - a.dx),
      a.dy + t * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }

  bool _isInsideQuad(Offset p, List<Offset> pts) {
    if (pts.length != 4) return false;
    var inside = false;
    for (int i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      if (((pts[i].dy > p.dy) != (pts[j].dy > p.dy)) &&
          (p.dx <
              (pts[j].dx - pts[i].dx) *
                      (p.dy - pts[i].dy) /
                      (pts[j].dy - pts[i].dy) +
                  pts[i].dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _onPanStart(Offset localPos, Rect imgRect) {
    if (widget.corners.length != 4) return;
    final screenPts = _toScreenPoints(imgRect);

    // 1. Proximity check for corners (generous 54dp radius)
    var closestCornerDist = double.infinity;
    CropHandleType? targetCorner;
    final cornerTypes = [
      CropHandleType.topLeftCorner,
      CropHandleType.topRightCorner,
      CropHandleType.bottomRightCorner,
      CropHandleType.bottomLeftCorner,
    ];

    for (var i = 0; i < 4; i++) {
      final d = (localPos - screenPts[i]).distance;
      if (d < closestCornerDist) {
        closestCornerDist = d;
        if (d <= 54.0) {
          targetCorner = cornerTypes[i];
        }
      }
    }

    if (targetCorner != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeHandle = targetCorner;
        _dragStartPos = localPos;
        _dragStartCorners = List<Offset>.from(widget.corners);
      });
      return;
    }

    // 2. Proximity check for edges (generous 44dp distance from segment)
    final edges = [
      (CropHandleType.topEdge, screenPts[0], screenPts[1]),
      (CropHandleType.rightEdge, screenPts[1], screenPts[2]),
      (CropHandleType.bottomEdge, screenPts[2], screenPts[3]),
      (CropHandleType.leftEdge, screenPts[3], screenPts[0]),
    ];

    var closestEdgeDist = double.infinity;
    CropHandleType? targetEdge;

    for (final e in edges) {
      final d = _distToSegment(localPos, e.$2, e.$3);
      if (d < closestEdgeDist) {
        closestEdgeDist = d;
        if (d <= 44.0) {
          targetEdge = e.$1;
        }
      }
    }

    if (targetEdge != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeHandle = targetEdge;
        _dragStartPos = localPos;
        _dragStartCorners = List<Offset>.from(widget.corners);
      });
      return;
    }

    // 3. Check inside quad for full frame pan
    if (_isInsideQuad(localPos, screenPts)) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeHandle = CropHandleType.wholeQuad;
        _dragStartPos = localPos;
        _dragStartCorners = List<Offset>.from(widget.corners);
      });
    }
  }

  void _onPanUpdate(Offset localPos, Rect imgRect) {
    if (_activeHandle == null ||
        _dragStartPos == null ||
        _dragStartCorners == null) {
      return;
    }

    final delta = localPos - _dragStartPos!;
    final normDx = delta.dx / imgRect.width;
    final normDy = delta.dy / imgRect.height;
    final orig = _dragStartCorners!;
    final updated = List<Offset>.from(orig);

    switch (_activeHandle!) {
      case CropHandleType.topLeftCorner:
        final nx = (orig[0].dx + normDx).clamp(0.0, orig[1].dx - 0.05);
        final ny = (orig[0].dy + normDy).clamp(0.0, orig[3].dy - 0.05);
        updated[0] = Offset(nx, ny);
        break;

      case CropHandleType.topRightCorner:
        final nx = (orig[1].dx + normDx).clamp(orig[0].dx + 0.05, 1.0);
        final ny = (orig[1].dy + normDy).clamp(0.0, orig[2].dy - 0.05);
        updated[1] = Offset(nx, ny);
        break;

      case CropHandleType.bottomRightCorner:
        final nx = (orig[2].dx + normDx).clamp(orig[3].dx + 0.05, 1.0);
        final ny = (orig[2].dy + normDy).clamp(orig[1].dy + 0.05, 1.0);
        updated[2] = Offset(nx, ny);
        break;

      case CropHandleType.bottomLeftCorner:
        final nx = (orig[3].dx + normDx).clamp(0.0, orig[2].dx - 0.05);
        final ny = (orig[3].dy + normDy).clamp(orig[0].dy + 0.05, 1.0);
        updated[3] = Offset(nx, ny);
        break;

      case CropHandleType.topEdge:
        final dy = normDy;
        final dx = normDx * 0.4;
        final y0 = (orig[0].dy + dy)
            .clamp(0.0, math.min(orig[3].dy - 0.06, 1.0).toDouble());
        final y1 = (orig[1].dy + dy)
            .clamp(0.0, math.min(orig[2].dy - 0.06, 1.0).toDouble());
        final x0 = (orig[0].dx + dx).clamp(0.0, orig[1].dx - 0.05);
        final x1 = (orig[1].dx + dx).clamp(orig[0].dx + 0.05, 1.0);
        updated[0] = Offset(x0, y0);
        updated[1] = Offset(x1, y1);
        break;

      case CropHandleType.bottomEdge:
        final dy = normDy;
        final dx = normDx * 0.4;
        final y3 = (orig[3].dy + dy)
            .clamp(math.max(orig[0].dy + 0.06, 0.0).toDouble(), 1.0);
        final y2 = (orig[2].dy + dy)
            .clamp(math.max(orig[1].dy + 0.06, 0.0).toDouble(), 1.0);
        final x3 = (orig[3].dx + dx).clamp(0.0, orig[2].dx - 0.05);
        final x2 = (orig[2].dx + dx).clamp(orig[3].dx + 0.05, 1.0);
        updated[3] = Offset(x3, y3);
        updated[2] = Offset(x2, y2);
        break;

      case CropHandleType.leftEdge:
        final dx = normDx;
        final dy = normDy * 0.4;
        final x0 = (orig[0].dx + dx)
            .clamp(0.0, math.min(orig[1].dx - 0.06, 1.0).toDouble());
        final x3 = (orig[3].dx + dx)
            .clamp(0.0, math.min(orig[2].dx - 0.06, 1.0).toDouble());
        final y0 = (orig[0].dy + dy).clamp(0.0, orig[3].dy - 0.05);
        final y3 = (orig[3].dy + dy).clamp(orig[0].dy + 0.05, 1.0);
        updated[0] = Offset(x0, y0);
        updated[3] = Offset(x3, y3);
        break;

      case CropHandleType.rightEdge:
        final dx = normDx;
        final dy = normDy * 0.4;
        final x1 = (orig[1].dx + dx)
            .clamp(math.max(orig[0].dx + 0.06, 0.0).toDouble(), 1.0);
        final x2 = (orig[2].dx + dx)
            .clamp(math.max(orig[3].dx + 0.06, 0.0).toDouble(), 1.0);
        final y1 = (orig[1].dy + dy).clamp(0.0, orig[2].dy - 0.05);
        final y2 = (orig[2].dy + dy).clamp(orig[1].dy + 0.05, 1.0);
        updated[1] = Offset(x1, y1);
        updated[2] = Offset(x2, y2);
        break;

      case CropHandleType.wholeQuad:
        final minX = orig.map((c) => c.dx).reduce(math.min);
        final maxX = orig.map((c) => c.dx).reduce(math.max);
        final minY = orig.map((c) => c.dy).reduce(math.min);
        final maxY = orig.map((c) => c.dy).reduce(math.max);

        final clampedDx = normDx.clamp(-minX, 1.0 - maxX);
        final clampedDy = normDy.clamp(-minY, 1.0 - maxY);

        for (var i = 0; i < 4; i++) {
          updated[i] = orig[i] + Offset(clampedDx, clampedDy);
        }
        break;
    }

    widget.onCornersChanged(updated);
  }

  void _onPanEnd() {
    if (_activeHandle != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _activeHandle = null;
        _dragStartPos = null;
        _dragStartCorners = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imgRect = _calculateImageRect(boxSize);
        final screenPts = _toScreenPoints(imgRect);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d.localPosition, imgRect),
          onPanUpdate: (d) => _onPanUpdate(d.localPosition, imgRect),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: () => _onPanEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Natural Proportion Image
              Positioned.fromRect(
                rect: imgRect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                  ),
                ),
              ),

              // 2. Custom Painted Overlay: Mask, Quad, Edge Grips, Corner Rings & Magnifier
              CustomPaint(
                size: boxSize,
                painter: _CropOverlayPainter(
                  imageRect: imgRect,
                  screenPts: screenPts,
                  activeHandle: _activeHandle,
                  accentColor: widget.accentColor,
                  uiImage: _uiImage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.imageRect,
    required this.screenPts,
    required this.activeHandle,
    required this.accentColor,
    required this.uiImage,
  });

  final Rect imageRect;
  final List<Offset> screenPts;
  final CropHandleType? activeHandle;
  final Color accentColor;
  final ui.Image? uiImage;

  @override
  void paint(Canvas canvas, Size size) {
    if (screenPts.length != 4) return;

    final tl = screenPts[0];
    final tr = screenPts[1];
    final br = screenPts[2];
    final bl = screenPts[3];

    // 1. Outer Darkened Mask (dims unselected area outside document quad)
    final quadPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final outerMask = Path()
      ..addRect(imageRect)
      ..addPath(quadPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      outerMask,
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    // 2. Document Quad Outline Borders
    _drawQuadBorders(canvas, tl, tr, br, bl);

    // 3. 4 Edge Midpoint Pill Grips
    _drawEdgeHandles(canvas, tl, tr, br, bl);

    // 4. 4 Corner Handles (Double Rings)
    _drawCornerHandles(canvas, [tl, tr, br, bl]);

    // 5. Floating Magnifier Loupe when dragging
    if (activeHandle != null && uiImage != null) {
      _drawMagnifierLoupe(canvas, size, tl, tr, br, bl);
    }
  }

  void _drawQuadBorders(
    Canvas canvas,
    Offset tl,
    Offset tr,
    Offset br,
    Offset bl,
  ) {
    void drawEdge(Offset p1, Offset p2, bool isActive) {
      final paint = Paint()
        ..color = isActive ? Colors.white : accentColor
        ..strokeWidth = isActive ? 3.8 : 2.5
        ..style = PaintingStyle.stroke;

      if (isActive) {
        // Subtle luminous glow under active edge
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..strokeWidth = 7.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p1, p2, glowPaint);
      }

      canvas.drawLine(p1, p2, paint);
    }

    drawEdge(tl, tr, activeHandle == CropHandleType.topEdge);
    drawEdge(tr, br, activeHandle == CropHandleType.rightEdge);
    drawEdge(br, bl, activeHandle == CropHandleType.bottomEdge);
    drawEdge(bl, tl, activeHandle == CropHandleType.leftEdge);
  }

  void _drawEdgeHandles(
    Canvas canvas,
    Offset tl,
    Offset tr,
    Offset br,
    Offset bl,
  ) {
    final topMid = (tl + tr) / 2;
    final rightMid = (tr + br) / 2;
    final bottomMid = (br + bl) / 2;
    final leftMid = (bl + tl) / 2;

    _drawPillHandle(
      canvas,
      topMid,
      isHorizontal: true,
      isActive: activeHandle == CropHandleType.topEdge,
    );
    _drawPillHandle(
      canvas,
      rightMid,
      isHorizontal: false,
      isActive: activeHandle == CropHandleType.rightEdge,
    );
    _drawPillHandle(
      canvas,
      bottomMid,
      isHorizontal: true,
      isActive: activeHandle == CropHandleType.bottomEdge,
    );
    _drawPillHandle(
      canvas,
      leftMid,
      isHorizontal: false,
      isActive: activeHandle == CropHandleType.leftEdge,
    );
  }

  void _drawPillHandle(
    Canvas canvas,
    Offset center, {
    required bool isHorizontal,
    required bool isActive,
  }) {
    final w = isHorizontal ? 34.0 : 14.0;
    final h = isHorizontal ? 14.0 : 34.0;
    final rect = Rect.fromCenter(
      center: center,
      width: isActive ? w * 1.15 : w,
      height: isActive ? h * 1.15 : h,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

    // Shadow
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black45
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Background pill fill
    canvas.drawRRect(
      rrect,
      Paint()..color = isActive ? Colors.white : accentColor,
    );

    // Pill border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isActive ? accentColor : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Grip lines inside pill
    final gripPaint = Paint()
      ..color = isActive ? accentColor : Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    if (isHorizontal) {
      canvas.drawLine(
        Offset(center.dx - 6, center.dy),
        Offset(center.dx + 6, center.dy),
        gripPaint,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx, center.dy - 6),
        Offset(center.dx, center.dy + 6),
        gripPaint,
      );
    }
  }

  void _drawCornerHandles(Canvas canvas, List<Offset> pts) {
    final types = [
      CropHandleType.topLeftCorner,
      CropHandleType.topRightCorner,
      CropHandleType.bottomRightCorner,
      CropHandleType.bottomLeftCorner,
    ];

    for (var i = 0; i < 4; i++) {
      final center = pts[i];
      final isActive = activeHandle == types[i];
      final radius = isActive ? 15.0 : 12.5;

      // Drop shadow
      canvas.drawCircle(
        center.translate(0, 2),
        radius,
        Paint()
          ..color = Colors.black54
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Active glow halo
      if (isActive) {
        canvas.drawCircle(
          center,
          radius + 5,
          Paint()
            ..color = accentColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Outer teal circle
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = accentColor,
      );

      // White ring border
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 3.5 : 2.8,
      );

      // Inner white pinpoint dot
      canvas.drawCircle(
        center,
        isActive ? 4.0 : 3.0,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawMagnifierLoupe(
    Canvas canvas,
    Size size,
    Offset tl,
    Offset tr,
    Offset br,
    Offset bl,
  ) {
    final img = uiImage!;

    // 1. Determine focus point in screen coordinates and normalized coordinates
    late final Offset focusScreen;
    late final Offset focusNorm;

    switch (activeHandle!) {
      case CropHandleType.topLeftCorner:
        focusScreen = tl;
        focusNorm = Offset(
          (tl.dx - imageRect.left) / imageRect.width,
          (tl.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.topRightCorner:
        focusScreen = tr;
        focusNorm = Offset(
          (tr.dx - imageRect.left) / imageRect.width,
          (tr.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.bottomRightCorner:
        focusScreen = br;
        focusNorm = Offset(
          (br.dx - imageRect.left) / imageRect.width,
          (br.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.bottomLeftCorner:
        focusScreen = bl;
        focusNorm = Offset(
          (bl.dx - imageRect.left) / imageRect.width,
          (bl.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.topEdge:
        focusScreen = (tl + tr) / 2;
        focusNorm = Offset(
          (focusScreen.dx - imageRect.left) / imageRect.width,
          (focusScreen.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.rightEdge:
        focusScreen = (tr + br) / 2;
        focusNorm = Offset(
          (focusScreen.dx - imageRect.left) / imageRect.width,
          (focusScreen.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.bottomEdge:
        focusScreen = (br + bl) / 2;
        focusNorm = Offset(
          (focusScreen.dx - imageRect.left) / imageRect.width,
          (focusScreen.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.leftEdge:
        focusScreen = (bl + tl) / 2;
        focusNorm = Offset(
          (focusScreen.dx - imageRect.left) / imageRect.width,
          (focusScreen.dy - imageRect.top) / imageRect.height,
        );
        break;
      case CropHandleType.wholeQuad:
        focusScreen = (tl + tr + br + bl) / 4;
        focusNorm = Offset(
          (focusScreen.dx - imageRect.left) / imageRect.width,
          (focusScreen.dy - imageRect.top) / imageRect.height,
        );
        break;
    }

    // 2. Position the loupe 80dp above finger, or below if too close to top
    const loupeRadius = 48.0;
    final loupeCenterX = focusScreen.dx.clamp(
      loupeRadius + 12.0,
      size.width - loupeRadius - 12.0,
    );
    var loupeCenterY = focusScreen.dy - 86.0;
    if (loupeCenterY - loupeRadius < 10.0) {
      // Near top of screen: shift below finger
      loupeCenterY = focusScreen.dy + 86.0;
    }

    final loupeCenter = Offset(loupeCenterX, loupeCenterY);

    // 3. Compute source image window (2.2x zoom)
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();
    final imgCenterX = (focusNorm.dx * imgW).clamp(0.0, imgW);
    final imgCenterY = (focusNorm.dy * imgH).clamp(0.0, imgH);

    final sampleW = imgW * 0.16;
    final sampleH = imgH * 0.16;
    final srcRect = Rect.fromCenter(
      center: Offset(imgCenterX, imgCenterY),
      width: sampleW,
      height: sampleH,
    );

    final dstRect = Rect.fromCircle(center: loupeCenter, radius: loupeRadius);

    // Draw Loupe Drop Shadow
    canvas.drawCircle(
      loupeCenter.translate(0, 4),
      loupeRadius,
      Paint()
        ..color = Colors.black54
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Clip to Loupe Circle
    canvas.save();
    final clipPath = Path()..addOval(dstRect);
    canvas.clipPath(clipPath);

    // Draw Loupe Background (black)
    canvas.drawRect(dstRect, Paint()..color = Colors.black);

    // Draw Magnified Sub-Image
    canvas.drawImageRect(
      img,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    // Precision Crosshairs inside Loupe
    final crossHairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;

    final darkCrossHairPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 2.4;

    // Horizontal crosshair with dark border
    canvas.drawLine(
      Offset(loupeCenter.dx - loupeRadius, loupeCenter.dy),
      Offset(loupeCenter.dx + loupeRadius, loupeCenter.dy),
      darkCrossHairPaint,
    );
    canvas.drawLine(
      Offset(loupeCenter.dx - loupeRadius, loupeCenter.dy),
      Offset(loupeCenter.dx + loupeRadius, loupeCenter.dy),
      crossHairPaint,
    );

    // Vertical crosshair with dark border
    canvas.drawLine(
      Offset(loupeCenter.dx, loupeCenter.dy - loupeRadius),
      Offset(loupeCenter.dx, loupeCenter.dy + loupeRadius),
      darkCrossHairPaint,
    );
    canvas.drawLine(
      Offset(loupeCenter.dx, loupeCenter.dy - loupeRadius),
      Offset(loupeCenter.dx, loupeCenter.dy + loupeRadius),
      crossHairPaint,
    );

    // Center focal point indicator
    canvas.drawCircle(
      loupeCenter,
      4.0,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      loupeCenter,
      4.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.restore();

    // Loupe outer ring border
    canvas.drawCircle(
      loupeCenter,
      loupeRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) => true;
}
