import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/pdf_generator_service.dart';
import 'package:scanpro/core/services/share_export_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:scanpro/data/repositories/document_repository.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';

/// Displays a [ScannedDocument] in a Material 3 list tile card with thumbnail,
/// metadata badges, and context actions.
class DocumentListTileCard extends ConsumerWidget {
  const DocumentListTileCard({
    super.key,
    required this.document,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final ScannedDocument document;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            onTap ??
            () => context.push(AppRoutes.documentEditorPath(document.id)),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap?.call(),
                ),
                const SizedBox(width: 4),
              ],
              DocumentThumbnailBox(
                imagePath: document.thumbnailPath,
                width: 62,
                height: 78,
                pageCount: document.pageCount,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (document.isFavorite) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            document.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      FormatUtils.formatDateTime(document.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _MetaBadge(
                          icon: Icons.layers_outlined,
                          label:
                              '${document.pageCount} ${document.pageCount == 1 ? "page" : "pages"}',
                        ),
                        _MetaBadge(
                          icon: Icons.sd_storage_outlined,
                          label: FormatUtils.formatBytes(
                            document.fileSizeBytes,
                          ),
                        ),
                        if (document.hasOcrText)
                          _MetaBadge(
                            icon: Icons.text_snippet_outlined,
                            label: 'OCR',
                            highlight: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                IconButton(
                  tooltip: 'Document Actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () =>
                      showDocumentActionsSheet(context, ref, document),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays a [ScannedDocument] in a responsive Grid card.
class DocumentGridCard extends ConsumerWidget {
  const DocumentGridCard({
    super.key,
    required this.document,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final ScannedDocument document;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2.2 : 1.0,
        ),
      ),
      child: InkWell(
        onTap:
            onTap ??
            () => context.push(AppRoutes.documentEditorPath(document.id)),
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DocumentThumbnailBox(
                    imagePath: document.thumbnailPath,
                    pageCount: document.pageCount,
                    borderRadius: 0,
                  ),
                  if (selectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : Colors.black54,
                        child: Icon(
                          isSelected
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (document.isFavorite)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${FormatUtils.formatShortDate(document.updatedAt)} • ${FormatUtils.formatBytes(document.fileSizeBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!selectionMode)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      onPressed: () =>
                          showDocumentActionsSheet(context, ref, document),
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

/// Floating multi-document selection bar shown when selecting 1 or more documents
/// on the Home Dashboard, Document Library, or Folder Details screen.
class MultiDocumentSelectionBar extends ConsumerWidget {
  const MultiDocumentSelectionBar({
    super.key,
    required this.selectedDocuments,
    required this.totalAvailableCount,
    required this.onSelectAllToggle,
    required this.onClearSelection,
  });

  final List<ScannedDocument> selectedDocuments;
  final int totalAvailableCount;
  final VoidCallback onSelectAllToggle;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = selectedDocuments.length;
    final allSelected =
        count == totalAvailableCount && totalAvailableCount > 0;

    return Card(
      elevation: 4,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Cancel Selection',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearSelection,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? "Document" : "Documents"} Selected',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onSelectAllToggle,
                  icon: Icon(
                    allSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 18,
                  ),
                  label: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: count == 0
                        ? null
                        : () => showMultiDocumentShareSheet(
                            context,
                            ref,
                            selectedDocuments,
                            onCompleted: onClearSelection,
                          ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text('Share ($count)'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: count == 0
                      ? null
                      : () async {
                          final deleted = await showDeleteDocumentConfirmation(
                            context,
                            ref,
                            selectedDocuments.map((d) => d.id).toList(),
                          );
                          if (deleted) {
                            onClearSelection();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a bottom sheet allowing the user to share multiple selected documents:
/// 1. Share as 1 Combined PDF (merges all selected documents' pages into a single PDF)
/// 2. Share as Separate PDF Files (1 PDF per selected document)
/// 3. Share All Scanned Images (JPG)
/// 4. Merge into 1 Saved Document in ScanPro Library
Future<void> showMultiDocumentShareSheet(
  BuildContext context,
  WidgetRef ref,
  List<ScannedDocument> selectedDocs, {
  VoidCallback? onCompleted,
}) async {
  if (selectedDocs.isEmpty) return;

  final totalPages = selectedDocs.fold<int>(
    0,
    (sum, doc) => sum + doc.pageCount,
  );

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final colorScheme = theme.colorScheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.share_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share ${selectedDocs.length} Selected ${selectedDocs.length == 1 ? "Document" : "Documents"}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$totalPages total scanned page(s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),

              // Option 1: Share as Separate PDF Files
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(
                  selectedDocs.length == 1
                      ? 'Share as PDF'
                      : 'Share as ${selectedDocs.length} Separate PDF Files',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Generates individual PDF files for each selected document and shares them together',
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _shareMultipleSeparatePdfs(context, ref, selectedDocs);
                  onCompleted?.call();
                },
              ),

              // Option 2: Share as 1 Combined/Merged PDF
              if (selectedDocs.length > 1)
                ListTile(
                  leading: Icon(
                    Icons.merge_type_rounded,
                    color: colorScheme.secondary,
                  ),
                  title: Text(
                    'Share as 1 Combined PDF ($totalPages Pages)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Combines all selected documents into a single multi-page PDF file to share',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _shareCombinedSinglePdf(context, ref, selectedDocs);
                    onCompleted?.call();
                  },
                ),

              // Option 3: Share All Scanned Images (JPG)
              ListTile(
                leading: const Icon(Icons.collections_outlined),
                title: Text(
                  'Share All Scanned Images ($totalPages JPGs)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Shares all scanned page images directly via WhatsApp, Email, Drive, etc.',
                ),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    final allImagePaths = <String>[];
                    for (final doc in selectedDocs) {
                      for (final page in doc.pages) {
                        allImagePaths.add(page.displayImagePath);
                      }
                    }
                    await ref
                        .read(shareExportServiceProvider)
                        .shareFiles(
                          filePaths: allImagePaths,
                          subject:
                              '${selectedDocs.length} Scanned Documents (ScanPro)',
                        );
                    onCompleted?.call();
                  } catch (e) {
                    if (context.mounted) {
                      ErrorHandler.showErrorSnackBar(context, e);
                    }
                  }
                },
              ),

              // Option 4: Merge into 1 Document in Library
              if (selectedDocs.length > 1)
                ListTile(
                  leading: const Icon(Icons.library_add_check_outlined),
                  title: const Text(
                    'Merge into 1 Document in Library',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Creates a new multi-page document combining all selected documents',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _mergeDocumentsIntoNew(context, ref, selectedDocs);
                    onCompleted?.call();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _shareMultipleSeparatePdfs(
  BuildContext context,
  WidgetRef ref,
  List<ScannedDocument> docs,
) async {
  try {
    final pdfGenerator = ref.read(pdfGeneratorServiceProvider);
    final docsNotifier = ref.read(documentsProvider.notifier);
    final pdfPaths = <String>[];

    for (final doc in docs) {
      final pdfFile = await pdfGenerator.generateAndSavePdf(
        document: doc,
        config: PdfExportConfig(customFileName: doc.title),
      );
      await docsNotifier.updateGeneratedPdfPath(
        documentId: doc.id,
        pdfPath: pdfFile.path,
      );
      pdfPaths.add(pdfFile.path);
    }

    await ref
        .read(shareExportServiceProvider)
        .shareFiles(
          filePaths: pdfPaths,
          subject: docs.length == 1
              ? docs.first.title
              : '${docs.length} Scanned Documents',
        );
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

Future<void> _shareCombinedSinglePdf(
  BuildContext context,
  WidgetRef ref,
  List<ScannedDocument> docs,
) async {
  try {
    final now = DateTime.now();
    final combinedPages = <ScannedPage>[];
    for (final doc in docs) {
      for (final page in doc.pages) {
        combinedPages.add(
          page.copyWith(pageNumber: combinedPages.length + 1),
        );
      }
    }

    final mergedTitle =
        'Combined_${FormatUtils.sanitizeFileName(docs.first.title)}_${docs.length}docs';
    final tempCombinedDoc = ScannedDocument(
      id: 'combined_${now.millisecondsSinceEpoch}',
      title: mergedTitle,
      pages: combinedPages,
      createdAt: now,
      updatedAt: now,
    );

    final pdfFile = await ref
        .read(pdfGeneratorServiceProvider)
        .generateAndSavePdf(
          document: tempCombinedDoc,
          config: PdfExportConfig(customFileName: mergedTitle),
        );

    await ref
        .read(shareExportServiceProvider)
        .shareFiles(
          filePaths: [pdfFile.path],
          subject: mergedTitle,
        );
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

Future<void> _mergeDocumentsIntoNew(
  BuildContext context,
  WidgetRef ref,
  List<ScannedDocument> docs,
) async {
  try {
    final inputs = <NewScannedPageInput>[];
    for (final doc in docs) {
      for (final page in doc.pages) {
        inputs.add(
          NewScannedPageInput(
            originalSourcePath: page.originalImagePath,
            processedSourcePath: page.processedImagePath,
            editSettings: page.editSettings,
          ),
        );
      }
    }

    final mergedDoc = await ref
        .read(documentsProvider.notifier)
        .createDocumentFromPageInputs(
          pageInputs: inputs,
          title: '${docs.first.title} + ${docs.length - 1} more',
          folderId: docs.first.folderId,
        );

    if (context.mounted) {
      ErrorHandler.showSuccessSnackBar(
        context,
        'Merged into "${mergedDoc.title}" (${mergedDoc.pageCount} pages).',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Renders a local file thumbnail safely with a fallback icon if missing.
class DocumentThumbnailBox extends StatelessWidget {
  const DocumentThumbnailBox({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.pageCount = 1,
    this.borderRadius = 10,
  });

  final String? imagePath;
  final double? width;
  final double? height;
  final int pageCount;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValidFile =
        imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasValidFile)
            Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              cacheWidth: 360,
              errorBuilder: (_, _, _) => Icon(
                Icons.description_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Icon(
              Icons.description_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
          if (pageCount > 1)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$pageCount',
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
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = highlight
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHighest;
    final fg = highlight
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a bottom sheet with full document management actions:
/// Open, PDF Export/Preview, OCR Extract Text, Share PDF, Share Images,
/// Rename, Move to Folder, Duplicate, Favorite, and Delete.
Future<void> showDocumentActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: DocumentThumbnailBox(
                  imagePath: document.thumbnailPath,
                  width: 44,
                  height: 54,
                  pageCount: document.pageCount,
                ),
                title: Text(
                  document.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${document.pageCount} page(s) • ${FormatUtils.formatBytes(document.fileSizeBytes)}',
                ),
                trailing: IconButton(
                  icon: Icon(
                    document.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: document.isFavorite ? Colors.amber : null,
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await ref
                        .read(documentsProvider.notifier)
                        .toggleFavorite(document.id);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_document),
                title: const Text('Open & Edit Pages'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push(AppRoutes.documentEditorPath(document.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text('PDF Settings & Preview'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push(AppRoutes.pdfExportSettingsPath(document.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet_rounded),
                title: const Text('OCR – Extract & Search Text'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push(AppRoutes.ocrViewerPath(document.id));
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share as PDF'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _quickSharePdf(context, ref, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Share Scanned Images (JPG)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    final paths = document.pages
                        .map((p) => p.displayImagePath)
                        .toList();
                    await ref
                        .read(shareExportServiceProvider)
                        .shareFiles(filePaths: paths, subject: document.title);
                  } catch (e) {
                    if (context.mounted) {
                      ErrorHandler.showErrorSnackBar(context, e);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename Document'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showRenameDocumentDialog(context, ref, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: const Text('Move to Folder'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showMoveToFolderDialog(context, ref, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Duplicate Document'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    await ref
                        .read(documentsProvider.notifier)
                        .duplicateDocument(document.id);
                    if (context.mounted) {
                      ErrorHandler.showSuccessSnackBar(
                        context,
                        'Created copy of "${document.title}".',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ErrorHandler.showErrorSnackBar(context, e);
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Document',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showDeleteDocumentConfirmation(context, ref, [document.id]);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _quickSharePdf(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) async {
  try {
    final pdfFile = await ref
        .read(pdfGeneratorServiceProvider)
        .generateAndSavePdf(
          document: document,
          config: PdfExportConfig(customFileName: document.title),
        );
    await ref
        .read(documentsProvider.notifier)
        .updateGeneratedPdfPath(
          documentId: document.id,
          pdfPath: pdfFile.path,
        );
    await ref
        .read(shareExportServiceProvider)
        .shareFiles(
          filePaths: [pdfFile.path],
          subject: document.title,
        );
  } catch (e) {
    if (context.mounted) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }
}

/// Shows a dialog to rename a [ScannedDocument].
Future<void> showRenameDocumentDialog(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) async {
  final controller = TextEditingController(text: document.title);
  final confirmed = await showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Rename Document'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Document Name',
          hintText: 'Enter document title',
        ),
        onSubmitted: (val) => Navigator.pop(dialogCtx, val),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogCtx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed != null && confirmed.trim().isNotEmpty) {
    try {
      await ref
          .read(documentsProvider.notifier)
          .renameDocument(document.id, confirmed.trim());
      if (context.mounted) {
        ErrorHandler.showSuccessSnackBar(context, 'Document renamed.');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }
}

/// Shows a dialog to assign a [ScannedDocument] to a folder or remove it from a folder.
Future<void> showMoveToFolderDialog(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument document,
) async {
  final folders =
      ref.read(foldersProvider).value ?? DocumentFolder.defaultFolders();

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => SimpleDialog(
      title: const Text('Move to Folder'),
      children: [
        SimpleDialogOption(
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await ref
                .read(documentsProvider.notifier)
                .moveDocumentToFolder(document.id, null);
            if (context.mounted) {
              ErrorHandler.showSuccessSnackBar(
                context,
                'Removed from folder.',
              );
            }
          },
          child: const Row(
            children: [
              Icon(Icons.folder_off_outlined),
              SizedBox(width: 12),
              Text('None (Uncategorized)'),
            ],
          ),
        ),
        for (final folder in folders)
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(documentsProvider.notifier)
                  .moveDocumentToFolder(document.id, folder.id);
              if (context.mounted) {
                ErrorHandler.showSuccessSnackBar(
                  context,
                  'Moved to "${folder.name}".',
                );
              }
            },
            child: Row(
              children: [
                Icon(folder.icon, color: folder.color),
                const SizedBox(width: 12),
                Expanded(child: Text(folder.name)),
                if (document.folderId == folder.id)
                  const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Shows a confirmation dialog before permanently deleting documents and their OCR/PDF files.
Future<bool> showDeleteDocumentConfirmation(
  BuildContext context,
  WidgetRef ref,
  List<String> documentIds,
) async {
  if (documentIds.isEmpty) return false;
  final count = documentIds.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(count == 1 ? 'Delete Document?' : 'Delete $count Documents?'),
      content: Text(
        count == 1
            ? 'This will permanently delete the scanned pages, generated PDF, and extracted OCR text from your device.'
            : 'This will permanently delete all $count selected documents and their associated files from your device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await ref.read(documentsProvider.notifier).deleteDocuments(documentIds);
      if (context.mounted) {
        ErrorHandler.showSuccessSnackBar(
          context,
          count == 1 ? 'Document deleted.' : '$count documents deleted.',
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }
  return false;
}
