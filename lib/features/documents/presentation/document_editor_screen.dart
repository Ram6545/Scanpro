import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';
import 'package:scanpro/shared/widgets/document_card_widgets.dart';

/// Screen 8: Multi-Page Document Editor.
///
/// Central workspace for viewing a saved document, reordering its pages,
/// adding new scans or gallery imports, launching Crop/Perspective or Filter
/// editors on any page, extracting OCR text, and generating/sharing PDFs.
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  int _selectedPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final docs = docsAsync.value ?? const <ScannedDocument>[];
    final document = docs.where((d) => d.id == widget.documentId).firstOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document Editor')),
        body: Center(
          child: docsAsync.isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.find_in_page_outlined, size: 54),
                    const SizedBox(height: 12),
                    const Text('Document not found.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Return to Home'),
                    ),
                  ],
                ),
        ),
      );
    }

    final safeIndex = _selectedPageIndex.clamp(
      0,
      (document.pages.length - 1).clamp(0, 9999),
    );
    final currentPage = document.pages.isNotEmpty
        ? document.pages[safeIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showRenameDocumentDialog(context, ref, document),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  document.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'OCR Text',
            onPressed: () =>
                context.push(AppRoutes.ocrViewerPath(document.id)),
            icon: const Icon(Icons.text_snippet_outlined),
          ),
          IconButton(
            tooltip: 'PDF Export & Preview',
            onPressed: () =>
                context.push(AppRoutes.pdfExportSettingsPath(document.id)),
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            tooltip: 'More Options',
            onPressed: () => showDocumentActionsSheet(context, ref, document),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selected Page Large Preview
            Expanded(
              child: currentPage == null
                  ? const Center(child: Text('No pages in document'))
                  : Container(
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
                            maxScale: 4.5,
                            child: Center(
                              child: Image.file(
                                File(currentPage.displayImagePath),
                                key: ValueKey(
                                  '${currentPage.id}_${currentPage.fileSizeBytes}_${document.updatedAt.millisecondsSinceEpoch}',
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Page ${safeIndex + 1} of ${document.pageCount} • ${currentPage.editSettings.filter.label}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Page-Level Editing Tools Bar (Crop, Filter, Rotate, OCR, Delete Page)
            if (currentPage != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.crop_rotate_rounded, size: 18),
                        label: const Text('Crop & Perspective'),
                        onPressed: () {
                          ref
                              .read(activePageEditProvider.notifier)
                              .setTarget(
                                documentId: document.id,
                                pageId: currentPage.id,
                              );
                          context.push(AppRoutes.cropEditor);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Filters & Tone'),
                        onPressed: () {
                          ref
                              .read(activePageEditProvider.notifier)
                              .setTarget(
                                documentId: document.id,
                                pageId: currentPage.id,
                              );
                          context.push(AppRoutes.filterEditor);
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.rotate_right_rounded,
                          size: 18,
                        ),
                        label: const Text('Rotate 90°'),
                        onPressed: () async {
                          final nextSettings = currentPage.editSettings
                              .copyWith(
                                rotationQuarterTurns:
                                    currentPage
                                        .editSettings
                                        .rotationQuarterTurns +
                                    1,
                              );
                          await ref
                              .read(documentsProvider.notifier)
                              .applyPageEditSettings(
                                documentId: document.id,
                                pageId: currentPage.id,
                                newSettings: nextSettings,
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.document_scanner_outlined,
                          size: 18,
                        ),
                        label: const Text('Extract Text (OCR)'),
                        onPressed: () =>
                            context.push(AppRoutes.ocrViewerPath(document.id)),
                      ),
                      if (document.pages.length > 1) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          label: Text(
                            'Remove Page',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          onPressed: () async {
                            await ref
                                .read(documentsProvider.notifier)
                                .deletePageFromDocument(
                                  document.id,
                                  currentPage.id,
                                );
                            if (mounted && _selectedPageIndex > 0) {
                              setState(() => _selectedPageIndex--);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Reorderable Multi-Page Strip
            SizedBox(
              height: 88,
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: document.pages.length,
                onReorderItem: (oldIndex, newIndex) {
                  ref
                      .read(documentsProvider.notifier)
                      .reorderPages(document.id, oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final page = document.pages[index];
                  final isSelected = index == safeIndex;
                  return GestureDetector(
                    key: ValueKey(page.id),
                    onTap: () => setState(() => _selectedPageIndex = index),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(page.displayImagePath),
                            key: ValueKey(
                              'thumb_${page.id}_${page.fileSizeBytes}',
                            ),
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                          ),
                          Positioned(
                            bottom: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(4),
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

            // Bottom Bar: Add Scan, Import Gallery, Create PDF
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(scanSessionProvider.notifier)
                          .startNewSession(targetDocumentId: document.id);
                      context.push(AppRoutes.scanner);
                    },
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: const Text('Add Scan'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final sessionNotifier = ref.read(
                          scanSessionProvider.notifier,
                        );
                        sessionNotifier.startNewSession(
                          targetDocumentId: document.id,
                        );
                        final count = await sessionNotifier
                            .pickMultipleFromGallery();
                        if (count > 0 && context.mounted) {
                          await sessionNotifier.commitSession();
                          if (context.mounted) {
                            ErrorHandler.showSuccessSnackBar(
                              context,
                              'Added $count page(s) to document.',
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ErrorHandler.showErrorSnackBar(context, e);
                        }
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        AppRoutes.pdfExportSettingsPath(document.id),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Create PDF'),
                    ),
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

