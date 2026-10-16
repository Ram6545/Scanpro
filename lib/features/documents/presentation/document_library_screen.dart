import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/home/presentation/home_screen.dart';
import 'package:scanpro/shared/widgets/app_shell_scaffold.dart';
import 'package:scanpro/shared/widgets/document_card_widgets.dart';

/// Screen 11: Document Library.
///
/// Full local document manager with All Documents, Favorites, and Folders tabs,
/// inline search filtering, multi-select bulk deletion, sorting, and grid/list toggle.
class DocumentLibraryScreen extends ConsumerStatefulWidget {
  const DocumentLibraryScreen({super.key});

  @override
  ConsumerState<DocumentLibraryScreen> createState() =>
      _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends ConsumerState<DocumentLibraryScreen> {
  final Set<String> _selectedDocIds = {};
  bool _manualSelectionMode = false;
  String _filterQuery = '';
  bool _onlyFavorites = false;

  bool get _isSelectionMode =>
      _manualSelectionMode || _selectedDocIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedDocIds.contains(id)) {
        _selectedDocIds.remove(id);
      } else {
        _selectedDocIds.add(id);
      }
      if (_selectedDocIds.isNotEmpty) {
        _manualSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedDocIds.clear();
      _manualSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final displayPrefs = ref.watch(documentDisplayPrefsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allDocs = docsAsync.value ?? const <ScannedDocument>[];
    final filteredDocs = ref
        .read(documentDisplayPrefsProvider.notifier)
        .sortDocuments(
          allDocs.where((doc) {
            if (_onlyFavorites && !doc.isFavorite) return false;
            return doc.matchesSearchQuery(_filterQuery);
          }).toList(),
        );
    final folders = foldersAsync.value ?? DocumentFolder.defaultFolders();
    final selectedDocs = filteredDocs
        .where((doc) => _selectedDocIds.contains(doc.id))
        .toList();

    return AppShellScaffold(
      currentIndex: 1,
      titleWidget: _isSelectionMode
          ? Text('${_selectedDocIds.length} Selected')
          : const Text('Document Library'),
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            tooltip: _selectedDocIds.length == filteredDocs.length
                ? 'Deselect All'
                : 'Select All',
            onPressed: () {
              setState(() {
                if (_selectedDocIds.length == filteredDocs.length) {
                  _selectedDocIds.clear();
                } else {
                  _selectedDocIds
                    ..clear()
                    ..addAll(filteredDocs.map((d) => d.id));
                }
              });
            },
            icon: const Icon(Icons.select_all_rounded),
          ),
          if (selectedDocs.isNotEmpty)
            IconButton(
              tooltip: 'Share Selected',
              onPressed: () => showMultiDocumentShareSheet(
                context,
                ref,
                selectedDocs,
                onCompleted: _exitSelectionMode,
              ),
              icon: const Icon(Icons.share_rounded),
            ),
          IconButton(
            tooltip: 'Delete Selected',
            onPressed: _selectedDocIds.isEmpty
                ? null
                : () async {
                    final deleted = await showDeleteDocumentConfirmation(
                      context,
                      ref,
                      _selectedDocIds.toList(),
                    );
                    if (deleted && mounted) {
                      _exitSelectionMode();
                    }
                  },
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colorScheme.error,
            ),
          ),
          IconButton(
            tooltip: 'Cancel Selection',
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close_rounded),
          ),
        ] else ...[
          if (filteredDocs.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _manualSelectionMode = true),
              icon: const Icon(Icons.checklist_rounded, size: 18),
              label: const Text('Select'),
            ),
          IconButton(
            tooltip: displayPrefs.isGridView ? 'List View' : 'Grid View',
            onPressed: () {
              ref.read(documentDisplayPrefsProvider.notifier).toggleViewMode();
            },
            icon: Icon(
              displayPrefs.isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
          ),
        ],
      ],
      body: Column(
        children: [
          // Filter bar & chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _filterQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Filter library by name or OCR content...',
                    prefixIcon: const Icon(Icons.filter_list_rounded),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () => setState(() => _filterQuery = ''),
                            icon: const Icon(Icons.clear_rounded),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('All (${allDocs.length})'),
                        selected: !_onlyFavorites,
                        onSelected: (_) =>
                            setState(() => _onlyFavorites = false),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.star_rounded, size: 16),
                        label: Text(
                          'Starred (${allDocs.where((d) => d.isFavorite).length})',
                        ),
                        selected: _onlyFavorites,
                        onSelected: (val) =>
                            setState(() => _onlyFavorites = val),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.create_new_folder_outlined,
                          size: 16,
                        ),
                        label: const Text('New Folder'),
                        onPressed: () => showCreateFolderDialog(context, ref),
                      ),
                      for (final folder in folders) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(
                            folder.icon,
                            size: 16,
                            color: folder.color,
                          ),
                          label: Text(folder.name),
                          onPressed: () => context.push(
                            AppRoutes.folderDetailsPath(folder.id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Document list / grid
          Expanded(
            child: filteredDocs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_off_outlined,
                            size: 56,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filterQuery.isNotEmpty
                                ? 'No documents match "$_filterQuery"'
                                : 'No documents in this view yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Select" or long-press any document card to multi-select and share together.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : displayPrefs.isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final selected = _selectedDocIds.contains(doc.id);
                      return DocumentGridCard(
                        document: doc,
                        isSelected: selected,
                        selectionMode: _isSelectionMode,
                        onTap: _isSelectionMode
                            ? () => _toggleSelection(doc.id)
                            : null,
                        onLongPress: () => _toggleSelection(doc.id),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final selected = _selectedDocIds.contains(doc.id);
                      return DocumentListTileCard(
                        document: doc,
                        isSelected: selected,
                        selectionMode: _isSelectionMode,
                        onTap: _isSelectionMode
                            ? () => _toggleSelection(doc.id)
                            : null,
                        onLongPress: () => _toggleSelection(doc.id),
                      );
                    },
                  ),
          ),

          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: MultiDocumentSelectionBar(
                selectedDocuments: selectedDocs,
                totalAvailableCount: filteredDocs.length,
                onSelectAllToggle: () {
                  setState(() {
                    if (_selectedDocIds.length == filteredDocs.length) {
                      _selectedDocIds.clear();
                    } else {
                      _selectedDocIds
                        ..clear()
                        ..addAll(filteredDocs.map((d) => d.id));
                    }
                  });
                },
                onClearSelection: _exitSelectionMode,
              ),
            ),
        ],
      ),
    );
  }
}

