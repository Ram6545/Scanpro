import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:scanpro/core/errors/app_exception.dart';

/// Manages app-private directories for storing scanned pages, thumbnails,
/// generated PDFs, and exported OCR text files safely offline.
class StorageService {
  StorageService();

  Directory? _rootDocDir;

  /// Ensures all required app-private subdirectories exist and returns the root directory.
  Future<Directory> ensureInitialized() async {
    if (_rootDocDir != null) return _rootDocDir!;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final root = Directory(
        p.join(appDocDir.path, AppConstants.documentsDirName),
      );
      if (!await root.exists()) {
        await root.create(recursive: true);
      }

      for (final subDir in [
        AppConstants.pagesOriginalDirName,
        AppConstants.pagesProcessedDirName,
        AppConstants.thumbnailsDirName,
        AppConstants.generatedPdfsDirName,
        AppConstants.exportedTextDirName,
      ]) {
        final dir = Directory(p.join(root.path, subDir));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      _rootDocDir = root;
      return root;
    } catch (e) {
      throw StorageException(
        userMessage: 'Unable to initialize local document storage.',
        cause: e,
      );
    }
  }

  /// Resolves the directory used for original unedited page captures.
  Future<Directory> getOriginalPagesDir() async {
    final root = await ensureInitialized();
    return Directory(p.join(root.path, AppConstants.pagesOriginalDirName));
  }

  /// Resolves the directory used for cropped/filtered page images.
  Future<Directory> getProcessedPagesDir() async {
    final root = await ensureInitialized();
    return Directory(p.join(root.path, AppConstants.pagesProcessedDirName));
  }

  /// Resolves the directory used for document thumbnails.
  Future<Directory> getThumbnailsDir() async {
    final root = await ensureInitialized();
    return Directory(p.join(root.path, AppConstants.thumbnailsDirName));
  }

  /// Resolves the directory used for generated PDF files.
  Future<Directory> getGeneratedPdfsDir() async {
    final root = await ensureInitialized();
    return Directory(p.join(root.path, AppConstants.generatedPdfsDirName));
  }

  /// Resolves the directory used for exported OCR text files.
  Future<Directory> getExportedTextDir() async {
    final root = await ensureInitialized();
    return Directory(p.join(root.path, AppConstants.exportedTextDirName));
  }

  /// Safely deletes a file at [filePath] if it exists.
  Future<void> deleteFileIfExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors for already-removed temporary files.
    }
  }
}

/// Riverpod provider for [StorageService].
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

