import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/core/services/image_processing_service.dart';
import 'package:scanpro/core/services/storage_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/local_database/database_helper.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:uuid/uuid.dart';

/// Input descriptor for creating or appending a scanned page.
class NewScannedPageInput {
  const NewScannedPageInput({
    required this.originalSourcePath,
    this.processedSourcePath,
    this.editSettings = const PageEditSettings(
      filter: ScanFilterType.enhancedColor,
    ),
  });

  final String originalSourcePath;
  final String? processedSourcePath;
  final PageEditSettings editSettings;
}

/// Repository coordinating SQLite metadata persistence and app-private file storage.
class DocumentRepository {
  DocumentRepository({
    required this._dbHelper,
    required this._storageService,
    required this._imageProcessor,
  });

  final DatabaseHelper _dbHelper;
  final StorageService _storageService;
  final ImageProcessingService _imageProcessor;
  static const Uuid _uuid = Uuid();

  // -------------------- FOLDERS --------------------

  Future<List<DocumentFolder>> getAllFolders() {
    return _dbHelper.getAllFolders();
  }

  Future<DocumentFolder> createFolder({
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final folder = DocumentFolder(
      id: 'folder_${_uuid.v4()}',
      name: name.trim(),
      iconKey: iconKey,
      colorValue: colorValue,
      createdAt: DateTime.now(),
      isDefault: false,
    );
    await _dbHelper.insertOrUpdateFolder(folder);
    return folder;
  }

  Future<void> deleteFolder(String folderId) {
    return _dbHelper.deleteFolder(folderId);
  }

  // -------------------- DOCUMENTS --------------------

  Future<List<ScannedDocument>> getAllDocuments() {
    return _dbHelper.getAllDocuments();
  }

  Future<ScannedDocument?> getDocumentById(String id) {
    return _dbHelper.getDocumentById(id);
  }

  /// Creates a new [ScannedDocument] from [pageInputs] (preserving both raw
  /// original image and perspective-cropped/enhanced scanned image).
  Future<ScannedDocument> createDocumentFromPageInputs({
    required List<NewScannedPageInput> pageInputs,
    String? title,
    String? folderId,
  }) async {
    if (pageInputs.isEmpty) {
      throw const StorageException(
        userMessage: 'At least one page image is required to create a document.',
      );
    }

    final now = DateTime.now();
    final docId = _uuid.v4();
    final origDir = await _storageService.getOriginalPagesDir();
    final procDir = await _storageService.getProcessedPagesDir();

    final pages = <ScannedPage>[];
    var totalBytes = 0;

    for (var i = 0; i < pageInputs.length; i++) {
      final input = pageInputs[i];
      final origSrc = File(input.originalSourcePath);
      if (!await origSrc.exists()) continue;

      final pageId = _uuid.v4();
      final ext = p.extension(origSrc.path).isNotEmpty
          ? p.extension(origSrc.path)
          : '.jpg';
      final origDestPath = p.join(origDir.path, '${pageId}_orig$ext');
      final procDestPath = p.join(procDir.path, '${pageId}_proc.jpg');

      await origSrc.copy(origDestPath);

      int fileSize;
      PageEditSettings appliedSettings = input.editSettings;

      if (input.processedSourcePath != null &&
          await File(input.processedSourcePath!).exists()) {
        final copiedProc = await File(
          input.processedSourcePath!,
        ).copy(procDestPath);
        fileSize = await copiedProc.length();
      } else {
        // Automatically run document edge detection + perspective warp + Magic Scan filter
        final scanResult = await _imageProcessor.autoScanDocument(
          originalImagePath: origDestPath,
          processedImagePath: procDestPath,
          defaultFilter: input.editSettings.filter,
        );
        appliedSettings = scanResult.appliedSettings;
        fileSize = scanResult.processedFileSizeBytes;
      }

      totalBytes += fileSize;

      pages.add(
        ScannedPage(
          id: pageId,
          documentId: docId,
          pageNumber: pages.length + 1,
          originalImagePath: origDestPath,
          processedImagePath: procDestPath,
          createdAt: now,
          fileSizeBytes: fileSize,
          editSettings: appliedSettings,
        ),
      );
    }

    if (pages.isEmpty) {
      throw const StorageException(
        userMessage: 'Could not read the selected image files.',
      );
    }

    final document = ScannedDocument(
      id: docId,
      title: (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : FormatUtils.generateDefaultScanTitle(now),
      folderId: folderId,
      pages: pages,
      thumbnailPath: pages.first.displayImagePath,
      fileSizeBytes: totalBytes,
      createdAt: now,
      updatedAt: now,
    );

    await _dbHelper.saveDocumentWithPages(document);
    return document;
  }

  /// Creates a new [ScannedDocument] by copying and auto-scanning [sourceImagePaths].
  Future<ScannedDocument> createDocumentFromImages({
    required List<String> sourceImagePaths,
    String? title,
    String? folderId,
  }) {
    return createDocumentFromPageInputs(
      pageInputs: sourceImagePaths
          .map((path) => NewScannedPageInput(originalSourcePath: path))
          .toList(),
      title: title,
      folderId: folderId,
    );
  }

  /// Appends new [pageInputs] to an existing [ScannedDocument].
  Future<ScannedDocument> addPageInputsToDocument({
    required String documentId,
    required List<NewScannedPageInput> pageInputs,
  }) async {
    final existing = await _dbHelper.getDocumentById(documentId);
    if (existing == null) {
      throw const DatabaseException(userMessage: 'Document not found.');
    }

    final origDir = await _storageService.getOriginalPagesDir();
    final procDir = await _storageService.getProcessedPagesDir();
    final now = DateTime.now();

    final updatedPages = List<ScannedPage>.from(existing.pages);
    for (final input in pageInputs) {
      final origSrc = File(input.originalSourcePath);
      if (!await origSrc.exists()) continue;

      final pageId = _uuid.v4();
      final ext = p.extension(origSrc.path).isNotEmpty
          ? p.extension(origSrc.path)
          : '.jpg';
      final origDestPath = p.join(origDir.path, '${pageId}_orig$ext');
      final procDestPath = p.join(procDir.path, '${pageId}_proc.jpg');

      await origSrc.copy(origDestPath);

      int fileSize;
      PageEditSettings appliedSettings = input.editSettings;

      if (input.processedSourcePath != null &&
          await File(input.processedSourcePath!).exists()) {
        final copiedProc = await File(
          input.processedSourcePath!,
        ).copy(procDestPath);
        fileSize = await copiedProc.length();
      } else {
        final scanResult = await _imageProcessor.autoScanDocument(
          originalImagePath: origDestPath,
          processedImagePath: procDestPath,
          defaultFilter: input.editSettings.filter,
        );
        appliedSettings = scanResult.appliedSettings;
        fileSize = scanResult.processedFileSizeBytes;
      }

      updatedPages.add(
        ScannedPage(
          id: pageId,
          documentId: documentId,
          pageNumber: updatedPages.length + 1,
          originalImagePath: origDestPath,
          processedImagePath: procDestPath,
          createdAt: now,
          fileSizeBytes: fileSize,
          editSettings: appliedSettings,
        ),
      );
    }

    return saveUpdatedDocument(existing.copyWith(pages: updatedPages));
  }

  /// Appends new page images to an existing [ScannedDocument].
  Future<ScannedDocument> addPagesToDocument({
    required String documentId,
    required List<String> sourceImagePaths,
  }) {
    return addPageInputsToDocument(
      documentId: documentId,
      pageInputs: sourceImagePaths
          .map((path) => NewScannedPageInput(originalSourcePath: path))
          .toList(),
    );
  }

  /// Saves changes to a [ScannedDocument] (title, folder, page order, PDF path, etc.)
  /// and recalculates total byte size and cover thumbnail.
  Future<ScannedDocument> saveUpdatedDocument(ScannedDocument document) async {
    final reindexedPages = <ScannedPage>[];
    var totalBytes = 0;

    for (var i = 0; i < document.pages.length; i++) {
      final page = document.pages[i].copyWith(pageNumber: i + 1);
      reindexedPages.add(page);
      totalBytes += page.fileSizeBytes;
    }

    if (document.pdfPath != null && document.pdfPath!.isNotEmpty) {
      final pdfFile = File(document.pdfPath!);
      if (await pdfFile.exists()) {
        totalBytes += await pdfFile.length();
      }
    }

    final updated = document.copyWith(
      pages: reindexedPages,
      thumbnailPath: reindexedPages.isNotEmpty
          ? reindexedPages.first.displayImagePath
          : null,
      fileSizeBytes: totalBytes,
      updatedAt: DateTime.now(),
    );

    await _dbHelper.saveDocumentWithPages(updated);
    return updated;
  }

  /// Duplicates an existing document and all its underlying page files.
  Future<ScannedDocument> duplicateDocument(String documentId) async {
    final source = await _dbHelper.getDocumentById(documentId);
    if (source == null) {
      throw const DatabaseException(userMessage: 'Document not found.');
    }

    final now = DateTime.now();
    final newDocId = _uuid.v4();
    final origDir = await _storageService.getOriginalPagesDir();
    final procDir = await _storageService.getProcessedPagesDir();

    final copiedPages = <ScannedPage>[];
    var totalBytes = 0;

    for (var i = 0; i < source.pages.length; i++) {
      final srcPage = source.pages[i];
      final newPageId = _uuid.v4();
      final ext = p.extension(srcPage.originalImagePath).isNotEmpty
          ? p.extension(srcPage.originalImagePath)
          : '.jpg';
      final origDestPath = p.join(origDir.path, '${newPageId}_orig$ext');
      final procDestPath = p.join(procDir.path, '${newPageId}_proc$ext');

      final origFile = File(srcPage.originalImagePath);
      final procFile = File(srcPage.processedImagePath);

      if (await origFile.exists()) {
        await origFile.copy(origDestPath);
      }
      var size = srcPage.fileSizeBytes;
      if (await procFile.exists()) {
        final f = await procFile.copy(procDestPath);
        size = await f.length();
      }
      totalBytes += size;

      copiedPages.add(
        srcPage.copyWith(
          id: newPageId,
          documentId: newDocId,
          pageNumber: i + 1,
          originalImagePath: origDestPath,
          processedImagePath: procDestPath,
          fileSizeBytes: size,
          createdAt: now,
        ),
      );
    }

    final duplicated = ScannedDocument(
      id: newDocId,
      title: '${source.title} (Copy)',
      folderId: source.folderId,
      pages: copiedPages,
      thumbnailPath: copiedPages.isNotEmpty
          ? copiedPages.first.displayImagePath
          : null,
      fileSizeBytes: totalBytes,
      createdAt: now,
      updatedAt: now,
      isFavorite: source.isFavorite,
    );

    await _dbHelper.saveDocumentWithPages(duplicated);
    return duplicated;
  }

  /// Deletes one or more documents and removes their image and PDF files from storage.
  Future<void> deleteDocuments(List<String> documentIds) async {
    for (final id in documentIds) {
      final doc = await _dbHelper.getDocumentById(id);
      if (doc != null) {
        for (final page in doc.pages) {
          await _storageService.deleteFileIfExists(page.originalImagePath);
          await _storageService.deleteFileIfExists(page.processedImagePath);
        }
        await _storageService.deleteFileIfExists(doc.pdfPath);
      }
      await _dbHelper.deleteDocumentById(id);
    }
  }
}

/// Riverpod provider for [DocumentRepository].
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    dbHelper: ref.watch(databaseHelperProvider),
    storageService: ref.watch(storageServiceProvider),
    imageProcessor: ref.watch(imageProcessingServiceProvider),
  );
});
