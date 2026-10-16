import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/core/services/storage_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/scanned_document.dart';

/// Supported PDF page size presets.
enum PdfPageSizePreset {
  a4('A4', '210 × 297 mm (International Standard)'),
  letter('Letter', '8.5 × 11 in (North America)'),
  original('Original Size', 'Matches each scanned page aspect ratio');

  const PdfPageSizePreset(this.label, this.description);
  final String label;
  final String description;
}

/// Supported PDF page orientations.
enum PdfOrientationPreset {
  portrait('Portrait'),
  landscape('Landscape');

  const PdfOrientationPreset(this.label);
  final String label;
}

/// Supported PDF output compression / quality levels.
enum PdfQualityPreset {
  high('High Quality', 'Best clarity for printing (larger file size)', 92, 2200),
  medium('Balanced', 'Crisp text with moderate file size', 78, 1600),
  compressed('Compressed', 'Smallest file size for email/messaging', 56, 1150);

  const PdfQualityPreset(
    this.label,
    this.description,
    this.jpegQuality,
    this.maxDimension,
  );

  final String label;
  final String description;
  final int jpegQuality;
  final int maxDimension;
}

/// User-selected configuration for generating a PDF document.
class PdfExportConfig {
  const PdfExportConfig({
    this.pageSize = PdfPageSizePreset.a4,
    this.orientation = PdfOrientationPreset.portrait,
    this.quality = PdfQualityPreset.high,
    this.customFileName = '',
    this.marginPoints = 16.0,
  });

  final PdfPageSizePreset pageSize;
  final PdfOrientationPreset orientation;
  final PdfQualityPreset quality;
  final String customFileName;
  final double marginPoints;

  PdfExportConfig copyWith({
    PdfPageSizePreset? pageSize,
    PdfOrientationPreset? orientation,
    PdfQualityPreset? quality,
    String? customFileName,
    double? marginPoints,
  }) {
    return PdfExportConfig(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      quality: quality ?? this.quality,
      customFileName: customFileName ?? this.customFileName,
      marginPoints: marginPoints ?? this.marginPoints,
    );
  }
}

class _PdfBuildIsolatePayload {
  const _PdfBuildIsolatePayload({
    required this.imagePaths,
    required this.pageSizeName,
    required this.isLandscape,
    required this.jpegQuality,
    required this.maxDimension,
    required this.marginPoints,
    required this.documentTitle,
  });

  final List<String> imagePaths;
  final String pageSizeName;
  final bool isLandscape;
  final int jpegQuality;
  final int maxDimension;
  final double marginPoints;
  final String documentTitle;
}

/// Service that builds multi-page PDF documents and saves them to app-private storage.
class PdfGeneratorService {
  const PdfGeneratorService(this._storageService);

  final StorageService _storageService;

  /// Generates raw PDF bytes for [document] using [config] in a background isolate.
  Future<Uint8List> buildPdfBytes({
    required ScannedDocument document,
    required PdfExportConfig config,
  }) async {
    if (document.pages.isEmpty) {
      throw const PdfGenerationException(
        userMessage: 'Cannot generate a PDF for a document with no pages.',
      );
    }

    try {
      final imagePaths = document.pages
          .map((page) => page.displayImagePath)
          .toList();

      final payload = _PdfBuildIsolatePayload(
        imagePaths: imagePaths,
        pageSizeName: config.pageSize.name,
        isLandscape: config.orientation == PdfOrientationPreset.landscape,
        jpegQuality: config.quality.jpegQuality,
        maxDimension: config.quality.maxDimension,
        marginPoints: config.marginPoints,
        documentTitle: document.title,
      );

      return await compute(_generatePdfBytesIsolate, payload);
    } catch (e) {
      if (e is PdfGenerationException) rethrow;
      throw PdfGenerationException(
        userMessage: 'Failed to generate PDF document.',
        cause: e,
      );
    }
  }

  /// Generates and writes the PDF file into app-private `generated_pdfs` storage,
  /// returning the saved [File].
  Future<File> generateAndSavePdf({
    required ScannedDocument document,
    required PdfExportConfig config,
  }) async {
    final pdfBytes = await buildPdfBytes(document: document, config: config);
    final pdfDir = await _storageService.getGeneratedPdfsDir();

    final baseName = config.customFileName.trim().isNotEmpty
        ? FormatUtils.sanitizeFileName(config.customFileName)
        : FormatUtils.sanitizeFileName(document.title);
    final fileName = baseName.toLowerCase().endsWith('.pdf')
        ? baseName
        : '$baseName.pdf';

    final outPath = p.join(pdfDir.path, '${document.id}_$fileName');
    final file = File(outPath);
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }
}

Future<Uint8List> _generatePdfBytesIsolate(
  _PdfBuildIsolatePayload payload,
) async {
  final pdf = pw.Document(
    title: payload.documentTitle,
    creator: 'ScanPro Smart Document Scanner',
  );

  for (final path in payload.imagePaths) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final rawBytes = file.readAsBytesSync();
    var decoded = img.decodeImage(rawBytes);
    if (decoded == null) continue;

    decoded = img.bakeOrientation(decoded);

    if (decoded.width > payload.maxDimension ||
        decoded.height > payload.maxDimension) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: payload.maxDimension)
          : img.copyResize(decoded, height: payload.maxDimension);
    }

    final compressedBytes = Uint8List.fromList(
      img.encodeJpg(decoded, quality: payload.jpegQuality),
    );
    final pdfImage = pw.MemoryImage(compressedBytes);

    PdfPageFormat format;
    if (payload.pageSizeName == PdfPageSizePreset.letter.name) {
      format = payload.isLandscape
          ? PdfPageFormat.letter.landscape
          : PdfPageFormat.letter.portrait;
    } else if (payload.pageSizeName == PdfPageSizePreset.original.name) {
      final wPt = decoded.width.toDouble() * 72.0 / 150.0;
      final hPt = decoded.height.toDouble() * 72.0 / 150.0;
      final customFormat = PdfPageFormat(wPt, hPt);
      format = payload.isLandscape
          ? customFormat.landscape
          : customFormat.portrait;
    } else {
      format = payload.isLandscape
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4.portrait;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(payload.marginPoints),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              pdfImage,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );
  }

  return pdf.save();
}

/// Riverpod provider for [PdfGeneratorService].
final pdfGeneratorServiceProvider = Provider<PdfGeneratorService>((ref) {
  return PdfGeneratorService(ref.watch(storageServiceProvider));
});

