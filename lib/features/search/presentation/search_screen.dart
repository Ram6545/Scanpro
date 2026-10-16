import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/shared/widgets/document_card_widgets.dart';

/// Screen 14: Global Document & OCR Search Screen.
///
/// Searches across both document titles and OCR-extracted text across all pages.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String? _extractMatchingOcrSnippet(ScannedDocument doc, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final page in doc.pages) {
      final text = page.ocrText;
      final idx = text.toLowerCase().indexOf(q);
      if (idx != -1) {
        final start = (idx - 25).clamp(0, text.length);
        final end = (idx + q.length + 45).clamp(0, text.length);
        final snippet = text.substring(start, end).replaceAll('\n', ' ');
        return 'Page ${page.pageNumber}: "...$snippet..."';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final allDocs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final results = _query.trim().isEmpty
        ? allDocs
        : allDocs.where((doc) => doc.matchesSearchQuery(_query)).toList();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search document name or OCR text...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _queryController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  )
                : null,
          ),
        ),
      ),
      body: SafeArea(
        child: results.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 56,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty
                            ? 'No saved documents yet'
                            : 'No matches for "$_query"',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Search checks both document titles and OCR-extracted text.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = results[index];
                  final ocrSnippet = _extractMatchingOcrSnippet(doc, _query);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DocumentListTileCard(
                        document: doc,
                        onTap: () =>
                            context.push(AppRoutes.documentEditorPath(doc.id)),
                      ),
                      if (ocrSnippet != null)
                        Container(
                          margin: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.65,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ocrSnippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

