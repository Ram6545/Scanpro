import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';

/// Screen 7: Filter & Enhancement Studio.
///
/// Provides live preview and non-destructive application of Original, Magic Color,
/// Grayscale, and B&W Sharp filters along with Brightness & Contrast sliders,
/// Undo history, and Reset to Original.
class FilterEditorScreen extends ConsumerStatefulWidget {
  const FilterEditorScreen({super.key});

  @override
  ConsumerState<FilterEditorScreen> createState() => _FilterEditorScreenState();
}

class _FilterEditorScreenState extends ConsumerState<FilterEditorScreen> {
  final List<PageEditSettings> _undoStack = [];
  PageEditSettings _currentSettings = const PageEditSettings();
  bool _initialized = false;
  bool _isSaving = false;

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

  void _pushStateAndModify(PageEditSettings next) {
    setState(() {
      _undoStack.add(_currentSettings);
      _currentSettings = next;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _currentSettings = _undoStack.removeLast();
    });
  }

  void _resetToOriginal() {
    _pushStateAndModify(
      _currentSettings.copyWith(
        filter: ScanFilterType.original,
        brightness: 0.0,
        contrast: 1.0,
      ),
    );
  }

  /// Builds a live GPU [ColorFilter] matrix approximating the selected filter,
  /// brightness, and contrast for instant 60fps preview before saving.
  ColorFilter _buildLiveColorFilter() {
    final b = _currentSettings.brightness * 255.0;
    final c = _currentSettings.contrast;
    final t = (1.0 - c) * 128.0 + b;

    switch (_currentSettings.filter) {
      case ScanFilterType.original:
        return ColorFilter.matrix([
          c, 0, 0, 0, t,
          0, c, 0, 0, t,
          0, 0, c, 0, t,
          0, 0, 0, 1, 0,
        ]);
      case ScanFilterType.enhancedColor:
        final ec = c * 1.25;
        final et = (1.0 - ec) * 128.0 + b + 10.0;
        return ColorFilter.matrix([
          ec, 0, 0, 0, et,
          0, ec, 0, 0, et,
          0, 0, ec, 0, et,
          0, 0, 0, 1, 0,
        ]);
      case ScanFilterType.grayscale:
        final r = 0.299 * c;
        final g = 0.587 * c;
        final bl = 0.114 * c;
        return ColorFilter.matrix([
          r, g, bl, 0, t,
          r, g, bl, 0, t,
          r, g, bl, 0, t,
          0, 0, 0, 1, 0,
        ]);
      case ScanFilterType.blackAndWhite:
        final bwContrast = c * 2.2;
        final bwOffset = (1.0 - bwContrast) * 135.0 + b;
        final r = 0.299 * bwContrast;
        final g = 0.587 * bwContrast;
        final bl = 0.114 * bwContrast;
        return ColorFilter.matrix([
          r, g, bl, 0, bwOffset,
          r, g, bl, 0, bwOffset,
          r, g, bl, 0, bwOffset,
          0, 0, 0, 1, 0,
        ]);
    }
  }

  Future<void> _saveEnhancements(ScannedPage page) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(documentsProvider.notifier)
          .applyPageEditSettings(
            documentId: page.documentId,
            pageId: page.id,
            newSettings: _currentSettings,
          );
      if (!mounted) return;
      ErrorHandler.showSuccessSnackBar(
        context,
        'Applied "${_currentSettings.filter.label}" filter.',
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
        appBar: AppBar(title: const Text('Filter Studio')),
        body: const Center(
          child: Text('Select a scanned document page to apply filters.'),
        ),
      );
    }

    if (!_initialized) {
      _currentSettings = page.editSettings;
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Enhance Page ${page.pageNumber}'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Reset to Original',
            onPressed: _resetToOriginal,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _isSaving ? null : () => _saveEnhancements(page),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live Filtered Page Viewport
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: _buildLiveColorFilter(),
                      child: Image.file(
                        File(page.originalImagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Filter Preset Selector Chips
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ScanFilterType.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = ScanFilterType.values[index];
                  final isSelected = _currentSettings.filter == preset;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: isSelected,
                    onSelected: (_) {
                      _pushStateAndModify(
                        _currentSettings.copyWith(filter: preset),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Brightness & Contrast Sliders
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_rounded, size: 20),
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 76,
                        child: Text(
                          'Brightness',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentSettings.brightness,
                          min: -0.4,
                          max: 0.4,
                          divisions: 16,
                          label:
                              '${(_currentSettings.brightness * 100).round()}%',
                          onChanged: (val) {
                            setState(() {
                              _currentSettings = _currentSettings.copyWith(
                                brightness: val,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.contrast_rounded, size: 20),
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 76,
                        child: Text(
                          'Contrast',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentSettings.contrast,
                          min: 0.6,
                          max: 1.8,
                          divisions: 12,
                          label:
                              '${(_currentSettings.contrast * 100).round()}%',
                          onChanged: (val) {
                            setState(() {
                              _currentSettings = _currentSettings.copyWith(
                                contrast: val,
                              );
                            });
                          },
                        ),
                      ),
                    ],
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

