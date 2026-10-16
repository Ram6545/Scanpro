import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';
import 'package:scanpro/shared/widgets/document_card_widgets.dart';

/// Screen 12: Folder Details Screen.
///
/// Displays all documents inside a specific folder/category and allows scanning
/// or importing new documents directly into that folder.
class FolderDetailsScreen extends ConsumerStatefulWidget {
  const FolderDetailsScreen({
    super.key,
    required this.folderId,
  });

  final String folderId;

  @override
  ConsumerState<FolderDetailsScreen> createState() =>
      _FolderDetailsScreenState();
}

class _FolderDetailsScreenState extends ConsumerState<FolderDetailsScreen> {
  final Set<String> _selectedDocIds = {};
  bool _manualSelectionMode = false;

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
    final folders =
        ref.watch(foldersProvider).value ?? DocumentFolder.defaultFolders();
    final folder = folders.firstWhere(
      (f) => f.id == widget.folderId,
      orElse: () => DocumentFolder(
        id: widget.folderId,
        name: 'Folder',
        iconKey: 'folder',
        colorValue: 0xFF1565C0,
        createdAt: DateTime.now(),
      ),
    );

    final allDocs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final folderDocs = allDocs
        .where((d) => d.folderId == widget.folderId)
        .toList();
    final selectedDocs = folderDocs
        .where((d) => _selectedDocIds.contains(d.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedDocIds.length} Selected')
            : Row(
                children: [
                  Icon(folder.icon, color: folder.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(folder.name)),
                ],
              ),
        actions: [
          if (_isSelectionMode) ...[
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
              tooltip: 'Cancel Selection',
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.close_rounded),
            ),
          ] else ...[
            if (folderDocs.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _manualSelectionMode = true),
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: const Text('Select'),
              ),
            if (!folder.isDefault)
              IconButton(
                tooltip: 'Delete Folder',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete "${folder.name}"?'),
                      content: const Text(
                        'Documents inside this folder will be kept safely in your library as uncategorized.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete Folder'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(foldersProvider.notifier)
                        .deleteFolder(widget.folderId);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: folderDocs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: folder.color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              folder.icon,
                              size: 48,
                              color: folder.color,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Documents in "${folder.name}"',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan a new document directly into this folder or move existing documents here from your library.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  ref
                                      .read(scanSessionProvider.notifier)
                                      .startNewSession(
                                        targetFolderId: widget.folderId,
                                      );
                                  context.push(AppRoutes.scanner);
                                },
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text('Scan into Folder'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    final notifier = ref.read(
                                      scanSessionProvider.notifier,
                                    );
                                    notifier.startNewSession(
                                      targetFolderId: widget.folderId,
                                    );
                                    final count = await notifier
                                        .pickMultipleFromGallery();
                                    if (count > 0 && context.mounted) {
                                      await context.push(
                                        AppRoutes.capturedPreview,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ErrorHandler.showErrorSnackBar(
                                        context,
                                        e,
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Import Gallery'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: folderDocs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = folderDocs[index];
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
                totalAvailableCount: folderDocs.length,
                onSelectAllToggle: () {
                  setState(() {
                    if (_selectedDocIds.length == folderDocs.length) {
                      _selectedDocIds.clear();
                    } else {
                      _selectedDocIds
                        ..clear()
                        ..addAll(folderDocs.map((d) => d.id));
                    }
                  });
                },
                onClearSelection: _exitSelectionMode,
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                ref
                    .read(scanSessionProvider.notifier)
                    .startNewSession(targetFolderId: widget.folderId);
                context.push(AppRoutes.scanner);
              },
              icon: const Icon(Icons.add_a_photo_rounded),
              label: Text('Scan to ${folder.name}'),
            ),
    );
  }
}

