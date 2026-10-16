import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanpro/core/services/image_processing_service.dart';
import 'package:scanpro/core/services/preferences_service.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:scanpro/data/repositories/document_repository.dart';

/// Sort criteria for document lists.
enum DocumentSortField {
  date('Date Modified'),
  name('Document Name'),
  size('File Size');

  const DocumentSortField(this.label);
  final String label;

  static DocumentSortField fromName(String? raw) {
    return DocumentSortField.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DocumentSortField.date,
    );
  }
}

/// Manages the list of folders/categories.
class FoldersNotifier extends AsyncNotifier<List<DocumentFolder>> {
  @override
  Future<List<DocumentFolder>> build() async {
    return ref.watch(documentRepositoryProvider).getAllFolders();
  }

  Future<DocumentFolder> createFolder({
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final created = await repo.createFolder(
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
    );
    state = AsyncData(await repo.getAllFolders());
    return created;
  }

  Future<void> deleteFolder(String folderId) async {
    final repo = ref.read(documentRepositoryProvider);
    await repo.deleteFolder(folderId);
    state = AsyncData(await repo.getAllFolders());
    ref.invalidate(documentsProvider);
  }
}

final foldersProvider =
    AsyncNotifierProvider<FoldersNotifier, List<DocumentFolder>>(
      FoldersNotifier.new,
    );

/// Manages the persistent list of [ScannedDocument] items.
class DocumentsNotifier extends AsyncNotifier<List<ScannedDocument>> {
  @override
  Future<List<ScannedDocument>> build() async {
    return ref.watch(documentRepositoryProvider).getAllDocuments();
  }

  Future<void> refresh() async {
    final repo = ref.read(documentRepositoryProvider);
    state = AsyncData(await repo.getAllDocuments());
  }

  Future<ScannedDocument> createDocumentFromPageInputs({
    required List<NewScannedPageInput> pageInputs,
    String? title,
    String? folderId,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.createDocumentFromPageInputs(
      pageInputs: pageInputs,
      title: title,
      folderId: folderId,
    );
    await refresh();
    return doc;
  }

  Future<ScannedDocument> createDocumentFromImages({
    required List<String> imagePaths,
    String? title,
    String? folderId,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.createDocumentFromImages(
      sourceImagePaths: imagePaths,
      title: title,
      folderId: folderId,
    );
    await refresh();
    return doc;
  }

  Future<ScannedDocument> addPageInputsToDocument({
    required String documentId,
    required List<NewScannedPageInput> pageInputs,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final updated = await repo.addPageInputsToDocument(
      documentId: documentId,
      pageInputs: pageInputs,
    );
    await refresh();
    return updated;
  }

  Future<ScannedDocument> addPagesToDocument({
    required String documentId,
    required List<String> imagePaths,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final updated = await repo.addPagesToDocument(
      documentId: documentId,
      sourceImagePaths: imagePaths,
    );
    await refresh();
    return updated;
  }

  Future<ScannedDocument> renameDocument(
    String documentId,
    String newTitle,
  ) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');
    final updated = await repo.saveUpdatedDocument(
      doc.copyWith(title: newTitle.trim()),
    );
    await refresh();
    return updated;
  }

  Future<ScannedDocument> moveDocumentToFolder(
    String documentId,
    String? folderId,
  ) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');
    final updated = await repo.saveUpdatedDocument(
      doc.copyWith(
        folderId: folderId,
        clearFolderId: folderId == null,
      ),
    );
    await refresh();
    return updated;
  }

  Future<ScannedDocument> toggleFavorite(String documentId) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');
    final updated = await repo.saveUpdatedDocument(
      doc.copyWith(isFavorite: !doc.isFavorite),
    );
    await refresh();
    return updated;
  }

  Future<ScannedDocument> reorderPages(
    String documentId,
    int oldIndex,
    int newIndex,
  ) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');

    final pages = List<ScannedPage>.from(doc.pages);
    final moved = pages.removeAt(oldIndex);
    pages.insert(newIndex, moved);

    final updated = await repo.saveUpdatedDocument(doc.copyWith(pages: pages));
    await refresh();
    return updated;
  }

  Future<ScannedDocument> deletePageFromDocument(
    String documentId,
    String pageId,
  ) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');
    if (doc.pages.length <= 1) {
      throw Exception(
        'A document must have at least one page. Delete the document instead.',
      );
    }

    final pages = doc.pages.where((p) => p.id != pageId).toList();
    final updated = await repo.saveUpdatedDocument(doc.copyWith(pages: pages));
    await refresh();
    return updated;
  }

  /// Applies non-destructive [newSettings] to a specific page, re-renders its
  /// processed image on a background isolate, and updates SQLite metadata.
  Future<ScannedDocument> applyPageEditSettings({
    required String documentId,
    required String pageId,
    required PageEditSettings newSettings,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final imageProcessor = ref.read(imageProcessingServiceProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');

    final pageIndex = doc.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) throw Exception('Page not found');

    final page = doc.pages[pageIndex];
    final newSizeBytes = await imageProcessor.processPageImage(
      originalImagePath: page.originalImagePath,
      processedImagePath: page.processedImagePath,
      settings: newSettings,
    );

    final updatedPages = List<ScannedPage>.from(doc.pages);
    updatedPages[pageIndex] = page.copyWith(
      editSettings: newSettings,
      fileSizeBytes: newSizeBytes,
    );

    final updatedDoc = await repo.saveUpdatedDocument(
      doc.copyWith(pages: updatedPages),
    );
    await refresh();
    return updatedDoc;
  }

  /// Updates the saved OCR text for a specific page or all pages in a document.
  Future<ScannedDocument> updatePageOcrText({
    required String documentId,
    required String pageId,
    required String ocrText,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');

    final updatedPages = doc.pages.map((p) {
      return p.id == pageId ? p.copyWith(ocrText: ocrText) : p;
    }).toList();

    final updatedDoc = await repo.saveUpdatedDocument(
      doc.copyWith(pages: updatedPages),
    );
    await refresh();
    return updatedDoc;
  }

  /// Records the generated PDF path on the document.
  Future<ScannedDocument> updateGeneratedPdfPath({
    required String documentId,
    required String? pdfPath,
  }) async {
    final repo = ref.read(documentRepositoryProvider);
    final doc = await repo.getDocumentById(documentId);
    if (doc == null) throw Exception('Document not found');

    final updatedDoc = await repo.saveUpdatedDocument(
      doc.copyWith(
        pdfPath: pdfPath,
        clearPdfPath: pdfPath == null,
      ),
    );
    await refresh();
    return updatedDoc;
  }

  Future<ScannedDocument> duplicateDocument(String documentId) async {
    final repo = ref.read(documentRepositoryProvider);
    final copy = await repo.duplicateDocument(documentId);
    await refresh();
    return copy;
  }

  Future<void> deleteDocuments(List<String> documentIds) async {
    final repo = ref.read(documentRepositoryProvider);
    await repo.deleteDocuments(documentIds);
    await refresh();
  }
}

final documentsProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<ScannedDocument>>(
      DocumentsNotifier.new,
    );

/// UI preference state for Grid vs List view and Sorting.
class DocumentDisplayPrefs {
  const DocumentDisplayPrefs({
    required this.isGridView,
    required this.sortField,
    required this.sortAscending,
  });

  final bool isGridView;
  final DocumentSortField sortField;
  final bool sortAscending;

  DocumentDisplayPrefs copyWith({
    bool? isGridView,
    DocumentSortField? sortField,
    bool? sortAscending,
  }) {
    return DocumentDisplayPrefs(
      isGridView: isGridView ?? this.isGridView,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class DocumentDisplayPrefsNotifier extends Notifier<DocumentDisplayPrefs> {
  @override
  DocumentDisplayPrefs build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return DocumentDisplayPrefs(
      isGridView: prefs.isGridView,
      sortField: DocumentSortField.fromName(prefs.sortOption),
      sortAscending: prefs.sortAscending,
    );
  }

  Future<void> toggleViewMode() async {
    final next = !state.isGridView;
    state = state.copyWith(isGridView: next);
    await ref.read(preferencesServiceProvider).setIsGridView(next);
  }

  Future<void> setSortField(DocumentSortField field) async {
    if (state.sortField == field) {
      final nextAsc = !state.sortAscending;
      state = state.copyWith(sortAscending: nextAsc);
      await ref.read(preferencesServiceProvider).setSortAscending(nextAsc);
    } else {
      state = state.copyWith(sortField: field, sortAscending: false);
      await ref.read(preferencesServiceProvider).setSortOption(field.name);
      await ref.read(preferencesServiceProvider).setSortAscending(false);
    }
  }

  List<ScannedDocument> sortDocuments(List<ScannedDocument> docs) {
    final sorted = List<ScannedDocument>.from(docs);
    sorted.sort((a, b) {
      int cmp;
      switch (state.sortField) {
        case DocumentSortField.name:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case DocumentSortField.size:
          cmp = a.fileSizeBytes.compareTo(b.fileSizeBytes);
        case DocumentSortField.date:
          cmp = a.updatedAt.compareTo(b.updatedAt);
      }
      return state.sortAscending ? cmp : -cmp;
    });
    return sorted;
  }
}

final documentDisplayPrefsProvider =
    NotifierProvider<DocumentDisplayPrefsNotifier, DocumentDisplayPrefs>(
      DocumentDisplayPrefsNotifier.new,
    );

