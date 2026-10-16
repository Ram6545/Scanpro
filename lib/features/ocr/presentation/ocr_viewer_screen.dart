import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/ocr_service.dart';
import 'package:scanpro/core/services/share_export_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';

/// Screen 13: On-Device OCR Text Viewer & Editor.
///
/// Extracts text offline from scanned pages using Google ML Kit, lets users
/// search within recognized text, edit, copy to clipboard, save back to local
/// metadata without altering the original scan, and export as a `.txt` file.
class OcrViewerScreen extends ConsumerStatefulWidget {
  const OcrViewerScreen({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<OcrViewerScreen> createState() => _OcrViewerScreenState();
}

class _OcrViewerScreenState extends ConsumerState<OcrViewerScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _selectedPageIndex = 0;
  bool _isExtracting = false;
  bool _initialized = false;
  String _searchTerm = '';

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _extractCurrentPage(ScannedDocument doc) async {
    if (doc.pages.isEmpty) return;
    final page = doc.pages[_selectedPageIndex];

    setState(() => _isExtracting = true);
    try {
      final recognized = await ref
          .read(ocrServiceProvider)
          .extractTextFromImage(page.displayImagePath);

      await ref
          .read(documentsProvider.notifier)
          .updatePageOcrText(
            documentId: doc.id,
            pageId: page.id,
            ocrText: recognized,
          );

      if (!mounted) return;
      _textController.text = recognized;
      if (recognized.isEmpty) {
        ErrorHandler.showErrorSnackBar(
          context,
          'No readable text detected on this page. Ensure the scan is sharp and well-lit.',
        );
      } else {
        ErrorHandler.showSuccessSnackBar(
          context,
          'Extracted ${recognized.split(RegExp(r'\s+')).length} words on-device.',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _extractAllPages(ScannedDocument doc) async {
    if (doc.pages.isEmpty) return;
    setState(() => _isExtracting = true);
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final docsNotifier = ref.read(documentsProvider.notifier);

      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final recognized = await ocrService.extractTextFromImage(
          page.displayImagePath,
        );
        await docsNotifier.updatePageOcrText(
          documentId: doc.id,
          pageId: page.id,
          ocrText: recognized,
        );
        if (i == _selectedPageIndex && mounted) {
          _textController.text = recognized;
        }
      }
      if (mounted) {
        ErrorHandler.showSuccessSnackBar(
          context,
          'Completed OCR across all ${doc.pageCount} page(s).',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _saveEditedText(ScannedDocument doc) async {
    if (doc.pages.isEmpty) return;
    final page = doc.pages[_selectedPageIndex];
    await ref
        .read(documentsProvider.notifier)
        .updatePageOcrText(
          documentId: doc.id,
          pageId: page.id,
          ocrText: _textController.text,
        );
    if (mounted) {
      ErrorHandler.showSuccessSnackBar(context, 'Saved edited OCR text.');
    }
  }

  Future<void> _exportTxtFile(ScannedDocument doc) async {
    try {
      final content = _textController.text.trim().isNotEmpty
          ? _textController.text
          : doc.fullOcrText;
      final txtFile = await ref
          .read(shareExportServiceProvider)
          .createTextFile(
            documentTitle: doc.title,
            textContent: content,
          );
      await ref
          .read(shareExportServiceProvider)
          .shareFiles(
            filePaths: [txtFile.path],
            subject: '${doc.title} (OCR Text)',
          );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _saveTxtToSystemPicker(ScannedDocument doc) async {
    try {
      final content = _textController.text.trim().isNotEmpty
          ? _textController.text
          : doc.fullOcrText;
      if (content.trim().isEmpty) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Extract or enter text before saving a .txt file.',
        );
        return;
      }
      final bytes = Uint8List.fromList(content.codeUnits);
      final fileName = '${FormatUtils.sanitizeFileName(doc.title)}_OCR.txt';
      final path = await ref
          .read(shareExportServiceProvider)
          .saveFileToSystemPicker(
            suggestedFileName: fileName,
            bytes: bytes,
            allowedExtensions: const ['txt'],
          );
      if (mounted && path != null) {
        ErrorHandler.showSuccessSnackBar(context, 'Saved "$fileName".');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final document = docs.where((d) => d.id == widget.documentId).firstOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (document == null || document.pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('OCR Text Recognition')),
        body: const Center(child: Text('Document not found.')),
      );
    }

    final safeIdx = _selectedPageIndex.clamp(0, document.pages.length - 1);
    final currentPage = document.pages[safeIdx];

    if (!_initialized) {
      _textController.text = currentPage.ocrText;
      _initialized = true;
    }

    final matchCount = _searchTerm.trim().isEmpty
        ? 0
        : RegExp(
            RegExp.escape(_searchTerm.trim()),
            caseSensitive: false,
          ).allMatches(_textController.text).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR – Extract Text'),
        actions: [
          IconButton(
            tooltip: 'Copy All Text',
            onPressed: () async {
              final text = _textController.text.trim();
              if (text.isEmpty) return;
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ErrorHandler.showSuccessSnackBar(
                  context,
                  'Copied text to clipboard.',
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: 'Save .txt to Device',
            onPressed: () => _saveTxtToSystemPicker(document),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Share .txt File',
            onPressed: () => _exportTxtFile(document),
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info disclaimer banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'On-device OCR preserves your original scan separately. Recognition quality depends on image sharpness and supported Latin scripts.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page selector chips + Run OCR buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(document.pages.length, (index) {
                          final selected = index == safeIdx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('Page ${index + 1}'),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedPageIndex = index;
                                  _textController.text =
                                      document.pages[index].ocrText;
                                });
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isExtracting
                        ? null
                        : () => _extractCurrentPage(document),
                    icon: _isExtracting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_rounded, size: 18),
                    label: const Text('Scan Page'),
                  ),
                  if (document.pages.length > 1) ...[
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: _isExtracting
                          ? null
                          : () => _extractAllPages(document),
                      child: const Text('All Pages'),
                    ),
                  ],
                ],
              ),
            ),

            // Search within extracted text bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchTerm = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search inside extracted text...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('$matchCount matches'),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Editable OCR Text Field
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText:
                        'Tap "Scan Page" above to extract text from Page ${safeIdx + 1}, or type/edit notes here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Save Edits button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveEditedText(document),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Text Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

