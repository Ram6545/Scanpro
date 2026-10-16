import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/core/services/storage_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:share_plus/share_plus.dart';

/// Handles sharing PDFs, scanned page images, and exported OCR text files,
/// as well as saving files via Android's system file picker (SAF).
class ShareExportService {
  const ShareExportService(this._storageService);

  final StorageService _storageService;

  /// Shares one or more files (PDF, JPG, TXT) using Android's system share sheet.
  Future<void> shareFiles({
    required List<String> filePaths,
    String? subject,
    String? text,
  }) async {
    final validFiles = <XFile>[];
    for (final path in filePaths) {
      if (path.isNotEmpty && await File(path).exists()) {
        validFiles.add(XFile(path));
      }
    }

    if (validFiles.isEmpty) {
      throw const StorageException(
        userMessage: 'The file to share could not be found on your device.',
      );
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: validFiles,
          subject: subject,
          text: text,
        ),
      );
    } catch (e) {
      throw StorageException(
        userMessage: 'Unable to open the system share sheet.',
        cause: e,
      );
    }
  }

  /// Writes [textContent] to an app-private `.txt` file and opens the share sheet.
  Future<File> createTextFile({
    required String documentTitle,
    required String textContent,
  }) async {
    if (textContent.trim().isEmpty) {
      throw const StorageException(
        userMessage: 'There is no extracted text to export.',
      );
    }

    final textDir = await _storageService.getExportedTextDir();
    final safeName = FormatUtils.sanitizeFileName(documentTitle);
    final file = File(p.join(textDir.path, '${safeName}_OCR.txt'));
    await file.writeAsString(textContent, flush: true);
    return file;
  }

  /// Prompts the user to save a file (PDF or TXT) to a user-chosen location
  /// using Android's Storage Access Framework (system file picker).
  Future<String?> saveFileToSystemPicker({
    required String suggestedFileName,
    required Uint8List bytes,
    required List<String> allowedExtensions,
  }) async {
    try {
      final outputUri = await FilePicker.saveFile(
        dialogTitle: 'Save Document',
        fileName: suggestedFileName,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        bytes: bytes,
      );
      return outputUri?.toString();
    } catch (e) {
      throw StorageException(
        userMessage: 'Unable to save file to the selected location.',
        cause: e,
      );
    }
  }
}

/// Riverpod provider for [ShareExportService].
final shareExportServiceProvider = Provider<ShareExportService>((ref) {
  return ShareExportService(ref.watch(storageServiceProvider));
});

