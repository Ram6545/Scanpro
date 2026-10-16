import 'package:scanpro/data/models/page_filter.dart';

/// Represents a single scanned page belonging to a [ScannedDocument].
class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.createdAt,
    this.ocrText = '',
    this.fileSizeBytes = 0,
    this.editSettings = const PageEditSettings(),
  });

  /// Stable UUID for this page.
  final String id;

  /// Parent document UUID.
  final String documentId;

  /// 1-based page ordering index within the document.
  final int pageNumber;

  /// App-private path to the raw captured/imported image (for non-destructive reset).
  final String originalImagePath;

  /// App-private path to the cropped, perspective-corrected, and filtered image.
  final String processedImagePath;

  /// Timestamp when the page was added.
  final DateTime createdAt;

  /// Extracted OCR text for this page, if OCR has been run.
  final String ocrText;

  /// Size of the processed image file in bytes.
  final int fileSizeBytes;

  /// Non-destructive editing settings applied to this page.
  final PageEditSettings editSettings;

  /// Returns the best available image path to display.
  String get displayImagePath =>
      processedImagePath.isNotEmpty ? processedImagePath : originalImagePath;

  ScannedPage copyWith({
    String? id,
    String? documentId,
    int? pageNumber,
    String? originalImagePath,
    String? processedImagePath,
    DateTime? createdAt,
    String? ocrText,
    int? fileSizeBytes,
    PageEditSettings? editSettings,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      createdAt: createdAt ?? this.createdAt,
      ocrText: ocrText ?? this.ocrText,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      editSettings: editSettings ?? this.editSettings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'page_number': pageNumber,
      'original_image_path': originalImagePath,
      'processed_image_path': processedImagePath,
      'created_at': createdAt.toIso8601String(),
      'ocr_text': ocrText,
      'file_size_bytes': fileSizeBytes,
      'edit_settings_json': editSettings.toJson(),
    };
  }

  factory ScannedPage.fromMap(Map<String, dynamic> map) {
    return ScannedPage(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      pageNumber: map['page_number'] as int? ?? 1,
      originalImagePath: map['original_image_path'] as String,
      processedImagePath: map['processed_image_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      ocrText: map['ocr_text'] as String? ?? '',
      fileSizeBytes: map['file_size_bytes'] as int? ?? 0,
      editSettings: PageEditSettings.fromJson(
        map['edit_settings_json'] as String?,
      ),
    );
  }
}

