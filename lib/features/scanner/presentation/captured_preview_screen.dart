import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/features/scanner/presentation/camera_scanner_screen.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';

/// Screen 5: Captured & Scanned Page Preview.
///
/// Displays the perspective-cropped, shadow-removed scanned document pages,
/// allows instant switching between scan filters (Magic Color, B&W Sharp,
/// Grayscale, Original), interactive 4-corner re-cropping, rotation, reordering,
/// and saving as a multi-page [ScannedDocument].
class CapturedPreviewScreen extends ConsumerStatefulWidget {
  const CapturedPreviewScreen({super.key});

  @override
  ConsumerState<CapturedPreviewScreen> createState() =>
      _CapturedPreviewScreenState();
}

class _CapturedPreviewScreenState extends ConsumerState<CapturedPreviewScreen> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: FormatUtils.generateDefaultScanTitle(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveAndOpenDocument() async {
    final sessionNotifier = ref.read(scanSessionProvider.notifier);
    try {
      final savedDoc = await sessionNotifier.commitSession(
        customTitle: _titleController.text.trim(),
      );
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Saved "${savedDoc.title}" (${savedDoc.pageCount} scanned page(s)).',
      );
      context.pushReplacement(AppRoutes.documentEditorPath(savedDoc.id));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _recropCurrentPage(DraftCapturedPage draft) async {
    final newSettings = await showModalBottomSheet<PageEditSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => PostCaptureEdgeCropSheet(
        rawImagePath: draft.originalImagePath,
        initialCorners: draft.editSettings.corners,
        initialFilter: draft.editSettings.filter,
      ),
    );

    if (newSettings != null && mounted) {
      await ref
          .read(scanSessionProvider.notifier)
          .updateCurrentPageSettings(newSettings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final notifier = ref.read(scanSessionProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (session.pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanned Pages')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_size_select_actual_outlined, size: 54),
                const SizedBox(height: 16),
                const Text('No pages in the current scan session.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      context.pushReplacement(AppRoutes.scanner),
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: const Text('Open Document Scanner'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentDraft = session.currentPage!;
    final quality = currentDraft.qualityReport;

    return Scaffold(
      appBar: AppBar(
        title: session.targetDocumentId == null
            ? TextField(
                controller: _titleController,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Document Title',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  suffixIcon: Icon(Icons.edit_outlined, size: 18),
                ),
              )
            : const Text('Add Scanned Pages'),
        actions: [
          FilledButton.icon(
            onPressed: (session.isSaving || session.isProcessingScan)
                ? null
                : _saveAndOpenDocument,
            icon: session.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save Scan'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quality Feedback Banner
            if (quality != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: (quality.isLowLight || quality.isBlurry)
                      ? colorScheme.errorContainer
                      : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      (quality.isLowLight || quality.isBlurry)
                          ? Icons.info_outline_rounded
                          : Icons.verified_rounded,
                      size: 18,
                      color: (quality.isLowLight || quality.isBlurry)
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quality.guidanceMessage,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: (quality.isLowLight || quality.isBlurry)
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Interactive Scanned Document Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.file(
                          File(currentDraft.scannedImagePath),
                          key: ValueKey(currentDraft.scannedImagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    if (session.isProcessingScan)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF4DB6AC),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Enhancing document scan...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Live Scan Filter Bar (Magic Color / B&W Sharp / Grayscale / Original)
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ScanFilterType.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = ScanFilterType.values[index];
                  final isSelected =
                      currentDraft.editSettings.filter == filter;
                  return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: session.isProcessingScan
                        ? null
                        : (_) {
                            notifier.updateCurrentPageSettings(
                              currentDraft.editSettings.copyWith(
                                filter: filter,
                              ),
                            );
                          },
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // Reorderable Thumbnail Strip
            SizedBox(
              height: 84,
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: session.pages.length,
                onReorderItem: notifier.reorderPages,
                itemBuilder: (context, index) {
                  final page = session.pages[index];
                  final isSelected = index == session.selectedIndex;
                  return GestureDetector(
                    key: ValueKey('${page.scannedImagePath}_$index'),
                    onTap: () => notifier.selectPage(index),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2.8 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(page.scannedImagePath),
                            key: ValueKey('thumb_${page.scannedImagePath}'),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Bottom Action Bar: Add Scan, Crop Edges, Rotate 90°, Retake, Delete
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PreviewActionButton(
                    icon: Icons.add_a_photo_rounded,
                    label: 'Add Scan',
                    onTap: () => context.push(AppRoutes.scanner),
                  ),
                  _PreviewActionButton(
                    icon: Icons.crop_rotate_rounded,
                    label: 'Crop Edges',
                    onTap: () => _recropCurrentPage(currentDraft),
                  ),
                  _PreviewActionButton(
                    icon: Icons.rotate_right_rounded,
                    label: 'Rotate 90°',
                    onTap: notifier.rotateCurrentPage,
                  ),
                  _PreviewActionButton(
                    icon: Icons.cameraswitch_outlined,
                    label: 'Retake',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CameraScannerScreen(
                            retakePageIndex: session.selectedIndex,
                          ),
                        ),
                      );
                    },
                  ),
                  _PreviewActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    isDestructive: true,
                    onTap: () => notifier.removePageAt(session.selectedIndex),
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

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
