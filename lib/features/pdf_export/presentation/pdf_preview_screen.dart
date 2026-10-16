import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/pdf_generator_service.dart';
import 'package:scanpro/core/services/share_export_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/features/pdf_export/presentation/pdf_export_settings_screen.dart';

/// Screen 10: PDF Preview Screen.
///
/// Renders an interactive multi-page PDF preview and provides actions to
/// print, share, or export the generated PDF to device storage.
class PdfPreviewScreen extends ConsumerWidget {
  const PdfPreviewScreen({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final document = docs.where((d) => d.id == documentId).firstOrNull;
    final config = ref.watch(activePdfConfigProvider);

    if (document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Preview')),
        body: const Center(child: Text('Document not found.')),
      );
    }

    final pdfFileName = FormatUtils.sanitizeFileName(
      config.customFileName.isNotEmpty ? config.customFileName : document.title,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$pdfFileName.pdf'),
        actions: [
          IconButton(
            tooltip: 'Save PDF to Device',
            onPressed: () async {
              try {
                final bytes = await ref
                    .read(pdfGeneratorServiceProvider)
                    .buildPdfBytes(document: document, config: config);
                final savedPath = await ref
                    .read(shareExportServiceProvider)
                    .saveFileToSystemPicker(
                      suggestedFileName: '$pdfFileName.pdf',
                      bytes: bytes,
                      allowedExtensions: const ['pdf'],
                    );
                if (context.mounted && savedPath != null) {
                  ErrorHandler.showSuccessSnackBar(
                    context,
                    'Saved "$pdfFileName.pdf" (${FormatUtils.formatBytes(bytes.length)}).',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.showErrorSnackBar(context, e);
                }
              }
            },
            icon: const Icon(Icons.save_alt_rounded),
          ),
        ],
      ),
      body: PdfPreview(
        pdfFileName: '$pdfFileName.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        build: (_) => ref
            .read(pdfGeneratorServiceProvider)
            .buildPdfBytes(document: document, config: config),
      ),
    );
  }
}

