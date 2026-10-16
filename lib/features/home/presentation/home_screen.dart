import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/theme/app_colors.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';
import 'package:scanpro/shared/widgets/app_shell_scaffold.dart';
import 'package:scanpro/shared/widgets/document_card_widgets.dart';

/// Screen 3: Home Dashboard.
///
/// Provides quick actions for Camera Scanning and Gallery Import, search bar,
/// document count & storage overview, folder categories, view mode toggle
/// (Grid/List), sorting (Date, Name, Size), and recent documents.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  Future<void> _startCameraScan(BuildContext context) async {
    final notifier = ref.read(scanSessionProvider.notifier);
    notifier.startNewSession();
    await context.push(AppRoutes.scanner);
  }

  Future<void> _importFromGallery(BuildContext context) async {
    try {
      final sessionNotifier = ref.read(scanSessionProvider.notifier);
      sessionNotifier.startNewSession();
      final count = await sessionNotifier.pickMultipleFromGallery();
      if (count > 0 && context.mounted) {
        await context.push(AppRoutes.capturedPreview);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final foldersAsync = ref.watch(foldersProvider);
    final displayPrefs = ref.watch(documentDisplayPrefsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final documents = docsAsync.value ?? const <ScannedDocument>[];
    final sortedDocs = ref
        .read(documentDisplayPrefsProvider.notifier)
        .sortDocuments(documents);
    final folders = foldersAsync.value ?? DocumentFolder.defaultFolders();
    final totalBytes = documents.fold<int>(
      0,
      (sum, doc) => sum + doc.fileSizeBytes,
    );

    final selectedDocs = sortedDocs
        .where((doc) => _selectedDocIds.contains(doc.id))
        .toList();

    return AppShellScaffold(
      currentIndex: 0,
      titleWidget: _isSelectionMode
          ? Text('${_selectedDocIds.length} Selected')
          : null,
      actions: _isSelectionMode
          ? [
              IconButton(
                tooltip: _selectedDocIds.length == sortedDocs.length
                    ? 'Deselect All'
                    : 'Select All',
                onPressed: () {
                  setState(() {
                    if (_selectedDocIds.length == sortedDocs.length) {
                      _selectedDocIds.clear();
                    } else {
                      _selectedDocIds
                        ..clear()
                        ..addAll(sortedDocs.map((d) => d.id));
                    }
                  });
                },
                icon: const Icon(Icons.select_all_rounded),
              ),
              if (selectedDocs.isNotEmpty)
                IconButton(
                  tooltip: 'Share Selected Documents',
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
            ]
          : null,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(documentsProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search trigger bar
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => context.push(AppRoutes.search),
                            child: IgnorePointer(
                              child: TextField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search documents by title or OCR text...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${documents.length} docs',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Hero Action Cards: Scan Document & Import from Gallery
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionHeroButton(
                                  icon: Icons.camera_alt_rounded,
                                  title: 'Scan Document',
                                  subtitle: 'Camera & Edge Frame',
                                  gradientColors: const [
                                    AppColors.primaryDeepBlue,
                                    Color(0xFF1976D2),
                                  ],
                                  onTap: () => _startCameraScan(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickActionHeroButton(
                                  icon: Icons.photo_library_rounded,
                                  title: 'Import Gallery',
                                  subtitle: 'Multi-photo to PDF',
                                  gradientColors: const [
                                    AppColors.secondaryTeal,
                                    Color(0xFF26A69A),
                                  ],
                                  onTap: () => _importFromGallery(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Stats summary bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(
                                    alpha: 0.55,
                                  ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 20,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Offline Private Vault • ${documents.length} ${documents.length == 1 ? "Document" : "Documents"}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  FormatUtils.formatBytes(totalBytes),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Categories / Folders Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Categories & Folders',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    showCreateFolderDialog(context, ref),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                ),
                                label: const Text('New Folder'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Horizontal Folders List
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 94,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: folders.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          final folderDocCount = documents
                              .where((d) => d.folderId == folder.id)
                              .length;
                          return _FolderChipCard(
                            folder: folder,
                            documentCount: folderDocCount,
                            onTap: () => context.push(
                              AppRoutes.folderDetailsPath(folder.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Recent Documents Header + Select, Sort & Grid/List controls
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent Documents (${sortedDocs.length})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (sortedDocs.isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () {
                                if (_isSelectionMode) {
                                  _exitSelectionMode();
                                } else {
                                  setState(() => _manualSelectionMode = true);
                                }
                              },
                              icon: Icon(
                                _isSelectionMode
                                    ? Icons.close_rounded
                                    : Icons.checklist_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _isSelectionMode ? 'Done' : 'Select',
                              ),
                            ),
                          PopupMenuButton<DocumentSortField>(
                            tooltip: 'Sort Documents',
                            initialValue: displayPrefs.sortField,
                            onSelected: (field) {
                              ref
                                  .read(documentDisplayPrefsProvider.notifier)
                                  .setSortField(field);
                            },
                            itemBuilder: (context) => [
                              for (final field in DocumentSortField.values)
                                PopupMenuItem(
                                  value: field,
                                  child: Row(
                                    children: [
                                      Icon(
                                        displayPrefs.sortField == field
                                            ? (displayPrefs.sortAscending
                                                  ? Icons.arrow_upward_rounded
                                                  : Icons
                                                        .arrow_downward_rounded)
                                            : Icons.sort_rounded,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(field.label),
                                    ],
                                  ),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sort_rounded, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    displayPrefs.sortField.label,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: displayPrefs.isGridView
                                ? 'Switch to List View'
                                : 'Switch to Grid View',
                            onPressed: () {
                              ref
                                  .read(documentDisplayPrefsProvider.notifier)
                                  .toggleViewMode();
                            },
                            icon: Icon(
                              displayPrefs.isGridView
                                  ? Icons.view_list_rounded
                                  : Icons.grid_view_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Empty State or Documents Grid/List
                  if (docsAsync.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (sortedDocs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        child: _EmptyHomeStateCard(
                          onScanTap: () => _startCameraScan(context),
                          onImportTap: () => _importFromGallery(context),
                        ),
                      ),
                    )
                  else if (displayPrefs.isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 210,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.74,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = sortedDocs[index];
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
                          childCount: sortedDocs.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: sortedDocs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = sortedDocs[index];
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
                ],
              ),
            ),
          ),
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: MultiDocumentSelectionBar(
                selectedDocuments: selectedDocs,
                totalAvailableCount: sortedDocs.length,
                onSelectAllToggle: () {
                  setState(() {
                    if (_selectedDocIds.length == sortedDocs.length) {
                      _selectedDocIds.clear();
                    } else {
                      _selectedDocIds
                        ..clear()
                        ..addAll(sortedDocs.map((d) => d.id));
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

class _QuickActionHeroButton extends StatelessWidget {
  const _QuickActionHeroButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderChipCard extends StatelessWidget {
  const _FolderChipCard({
    required this.folder,
    required this.documentCount,
    required this.onTap,
  });

  final DocumentFolder folder;
  final int documentCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: folder.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        folder.icon,
                        size: 20,
                        color: folder.color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$documentCount',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHomeStateCard extends StatelessWidget {
  const _EmptyHomeStateCard({
    required this.onScanTap,
    required this.onImportTap,
  });

  final VoidCallback onScanTap;
  final VoidCallback onImportTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 38,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Scanned Documents Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a document with your camera or import existing photos from your gallery to create multi-page PDFs and extract text offline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onScanTap,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Scan with Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: onImportTap,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Import Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a new custom folder/category.
Future<void> showCreateFolderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = TextEditingController();
  var selectedColor = AppColors.folderColors.first.toARGB32();
  var selectedIconKey = 'folder';

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Create New Folder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    hintText: 'e.g. Tax 2026, Medical, Passports',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Folder Color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final c in AppColors.folderColors)
                      GestureDetector(
                        onTap: () => setDialogState(
                          () => selectedColor = c.toARGB32(),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: c,
                          child: selectedColor == c.toARGB32()
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Folder Icon',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in DocumentFolder.availableIcons.entries)
                      ChoiceChip(
                        label: Icon(entry.value, size: 18),
                        selected: selectedIconKey == entry.key,
                        onSelected: (_) => setDialogState(
                          () => selectedIconKey = entry.key,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogCtx);
                await ref
                    .read(foldersProvider.notifier)
                    .createFolder(
                      name: name,
                      iconKey: selectedIconKey,
                      colorValue: selectedColor,
                    );
                if (context.mounted) {
                  ErrorHandler.showSuccessSnackBar(
                    context,
                    'Folder "$name" created.',
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );
}

