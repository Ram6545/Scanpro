import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/image_processing_service.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';

/// Screen 6: Crop & 4-Corner Perspective Editor.
///
/// Allows interactive dragging of the 4 document corners (top-left, top-right,
/// bottom-right, bottom-left), automatic edge snapping, 90° rotation, and
/// non-destructive full-frame reset.
class CropEditorScreen extends ConsumerStatefulWidget {
  const CropEditorScreen({super.key});

  @override
  ConsumerState<CropEditorScreen> createState() => _CropEditorScreenState();
}

class _CropEditorScreenState extends ConsumerState<CropEditorScreen> {
  List<Offset> _corners = List<Offset>.from(PageEditSettings.defaultCorners);
  int _rotationQuarterTurns = 0;
  bool _initialized = false;
  bool _isProcessing = false;

  ScannedPage? _resolveTargetPage(List<ScannedDocument> docs) {
    final target = ref.watch(activePageEditProvider);
    if (target != null) {
      final doc = docs.where((d) => d.id == target.documentId).firstOrNull;
      final page = doc?.pages.where((p) => p.id == target.pageId).firstOrNull;
      if (page != null) return page;
    }
    if (docs.isNotEmpty && docs.first.pages.isNotEmpty) {
      return docs.first.pages.first;
    }
    return null;
  }

  Future<void> _autoDetectEdges(String imagePath) async {
    setState(() => _isProcessing = true);
    try {
      final detected = await ref
          .read(imageProcessingServiceProvider)
          .detectDocumentCorners(imagePath);
      if (mounted) {
        setState(() => _corners = List<Offset>.from(detected));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _applyChanges(ScannedPage page) async {
    setState(() => _isProcessing = true);
    try {
      final updatedSettings = page.editSettings.copyWith(
        corners: _corners,
        rotationQuarterTurns: _rotationQuarterTurns,
      );
      await ref
          .read(documentsProvider.notifier)
          .applyPageEditSettings(
            documentId: page.documentId,
            pageId: page.id,
            newSettings: updatedSettings,
          );
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Perspective crop & orientation applied.',
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final page = _resolveTargetPage(docs);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (page == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crop & Perspective')),
        body: const Center(
          child: Text('Select a scanned document page to edit.'),
        ),
      );
    }

    if (!_initialized) {
      _corners = List<Offset>.from(page.editSettings.corners);
      _rotationQuarterTurns = page.editSettings.rotationQuarterTurns;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Crop Page ${page.pageNumber}'),
        actions: [
          FilledButton.icon(
            onPressed: _isProcessing ? null : () => _applyChanges(page),
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Apply'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Drag the 4 corner handles to align with the document edges.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Interactive 4-Corner Perspective Canvas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxW = constraints.maxWidth;
                    final boxH = constraints.maxHeight;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: RotatedBox(
                            quarterTurns: _rotationQuarterTurns,
                            child: Image.file(
                              File(page.originalImagePath),
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),

                        // Quad Polygon Lines Overlay
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _PerspectiveQuadPainter(
                              corners: _corners,
                              accentColor: colorScheme.secondary,
                            ),
                          ),
                        ),

                        // 4 Draggable Corner Handles
                        for (var i = 0; i < 4; i++)
                          Positioned(
                            left: (_corners[i].dx * boxW) - 22,
                            top: (_corners[i].dy * boxH) - 22,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  final nextX =
                                      (_corners[i].dx + details.delta.dx / boxW)
                                          .clamp(0.0, 1.0);
                                  final nextY =
                                      (_corners[i].dy + details.delta.dy / boxH)
                                          .clamp(0.0, 1.0);
                                  _corners[i] = Offset(nextX, nextY);
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                color: Colors.transparent,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Bottom Controls: Auto Edge, Full Frame, Rotate Left, Rotate Right
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _autoDetectEdges(page.originalImagePath),
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Auto Edges'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _corners = List<Offset>.from(
                          PageEditSettings.defaultCorners,
                        );
                        _rotationQuarterTurns = 0;
                      });
                    },
                    icon: const Icon(Icons.crop_free_rounded),
                    label: const Text('Full Reset'),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Rotate Left 90°',
                    onPressed: () {
                      setState(() {
                        _rotationQuarterTurns = (_rotationQuarterTurns + 3) % 4;
                      });
                    },
                    icon: const Icon(Icons.rotate_left_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Rotate Right 90°',
                    onPressed: () {
                      setState(() {
                        _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
                      });
                    },
                    icon: const Icon(Icons.rotate_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerspectiveQuadPainter extends CustomPainter {
  const _PerspectiveQuadPainter({
    required this.corners,
    required this.accentColor,
  });

  final List<Offset> corners;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final pts = corners
        .map((c) => Offset(c.dx * size.width, c.dy * size.height))
        .toList();

    final quadPath = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    // Shade area outside the selected perspective quad
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(quadPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    // Draw quad outline
    canvas.drawPath(
      quadPath,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  @override
  bool shouldRepaint(covariant _PerspectiveQuadPainter oldDelegate) => true;
}

