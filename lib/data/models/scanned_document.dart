import 'package:scanpro/data/models/scanned_page.dart';

/// Represents a complete single-page or multi-page document in ScanPro.
class ScannedDocument {
  const ScannedDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.pages = const [],
    this.pdfPath,
    this.thumbnailPath,
    this.fileSizeBytes = 0,
    this.isFavorite = false,
  });

  /// Stable UUID for the document.
  final String id;

  /// User-editable document name.
  final String title;

  /// Optional folder/category ID.
  final String? folderId;

  /// Ordered list of pages in this document.
  final List<ScannedPage> pages;

  /// App-private path to the most recently generated PDF file, if any.
  final String? pdfPath;

  /// App-private path to the cover page thumbnail image.
  final String? thumbnailPath;

  /// Total size in bytes (sum of pages + generated PDF if present).
  final int fileSizeBytes;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modified timestamp.
  final DateTime updatedAt;

  /// Whether the user starred/pinned this document.
  final bool isFavorite;

  /// Total number of pages in this document.
  int get pageCount => pages.length;

  /// Concatenated OCR text across all pages in page order.
  String get fullOcrText {
    return pages
        .map((p) => p.ocrText.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n--- Page Break ---\n\n');
  }

  /// Whether any page in this document has extracted OCR text.
  bool get hasOcrText => pages.any((p) => p.ocrText.trim().isNotEmpty);

  /// Returns true if the document title or OCR text matches [query] (case-insensitive).
  bool matchesSearchQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (title.toLowerCase().contains(normalized)) return true;
    return pages.any((p) => p.ocrText.toLowerCase().contains(normalized));
  }

  ScannedDocument copyWith({
    String? id,
    String? title,
    String? folderId,
    bool clearFolderId = false,
    List<ScannedPage>? pages,
    String? pdfPath,
    bool clearPdfPath = false,
    String? thumbnailPath,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      pages: pages ?? List<ScannedPage>.from(this.pages),
      pdfPath: clearPdfPath ? null : (pdfPath ?? this.pdfPath),
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'folder_id': folderId,
      'pdf_path': pdfPath,
      'thumbnail_path': thumbnailPath,
      'file_size_bytes': fileSizeBytes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory ScannedDocument.fromMap(
    Map<String, dynamic> map, {
    List<ScannedPage> pages = const [],
  }) {
    return ScannedDocument(
      id: map['id'] as String,
      title: map['title'] as String,
      folderId: map['folder_id'] as String?,
      pages: pages,
      pdfPath: map['pdf_path'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      fileSizeBytes: map['file_size_bytes'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    );
  }
}

