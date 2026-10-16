import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/pdf_generator_service.dart';
import 'package:scanpro/core/services/share_export_service.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';

/// Holds the active [PdfExportConfig] selected by the user for PDF generation/preview.
class ActivePdfConfigNotifier extends Notifier<PdfExportConfig> {
  @override
  PdfExportConfig build() => const PdfExportConfig();

  void updateConfig(PdfExportConfig config) {
    state = config;
  }
}

final activePdfConfigProvider =
    NotifierProvider<ActivePdfConfigNotifier, PdfExportConfig>(
      ActivePdfConfigNotifier.new,
    );

/// Screen 9: PDF Export Settings.
///
/// Configures PDF filename, page size (A4, Letter, Original), orientation
/// (Portrait, Landscape), quality/compression, and page margins before
/// previewing, saving, or sharing.
class PdfExportSettingsScreen extends ConsumerStatefulWidget {
  const PdfExportSettingsScreen({
    super.key,
    required this.documentId,
  });

  final String documentId;

  @override
  ConsumerState<PdfExportSettingsScreen> createState() =>
      _PdfExportSettingsScreenState();
}

class _PdfExportSettingsScreenState
    extends ConsumerState<PdfExportSettingsScreen> {
  late final TextEditingController _fileNameController;
  PdfPageSizePreset _pageSize = PdfPageSizePreset.a4;
  PdfOrientationPreset _orientation = PdfOrientationPreset.portrait;
  PdfQualityPreset _quality = PdfQualityPreset.high;
  double _marginPoints = 16.0;
  bool _initialized = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  PdfExportConfig _currentConfig() {
    return PdfExportConfig(
      pageSize: _pageSize,
      orientation: _orientation,
      quality: _quality,
      customFileName: _fileNameController.text.trim(),
      marginPoints: _marginPoints,
    );
  }

  Future<void> _generateAndOpenPreview(ScannedDocument doc) async {
    final config = _currentConfig();
    ref.read(activePdfConfigProvider.notifier).updateConfig(config);

    setState(() => _isGenerating = true);
    try {
      final pdfFile = await ref
          .read(pdfGeneratorServiceProvider)
          .generateAndSavePdf(
            document: doc,
            config: config,
          );
      await ref
          .read(documentsProvider.notifier)
          .updateGeneratedPdfPath(
            documentId: doc.id,
            pdfPath: pdfFile.path,
          );
      if (!mounted) return;
      context.push(AppRoutes.pdfPreviewPath(doc.id));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _saveViaSystemPicker(ScannedDocument doc) async {
    final config = _currentConfig();
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await ref
          .read(pdfGeneratorServiceProvider)
          .buildPdfBytes(
            document: doc,
            config: config,
          );
      final baseName = FormatUtils.sanitizeFileName(
        config.customFileName.isNotEmpty ? config.customFileName : doc.title,
      );
      final fileName = baseName.toLowerCase().endsWith('.pdf')
          ? baseName
          : '$baseName.pdf';

      final savedPath = await ref
          .read(shareExportServiceProvider)
          .saveFileToSystemPicker(
            suggestedFileName: fileName,
            bytes: pdfBytes,
            allowedExtensions: const ['pdf'],
          );
      if (mounted && savedPath != null) {
        ErrorHandler.showSuccessSnackBar(
          context,
          'PDF saved ($fileName • ${FormatUtils.formatBytes(pdfBytes.length)}).',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _sharePdfDirectly(ScannedDocument doc) async {
    final config = _currentConfig();
    setState(() => _isGenerating = true);
    try {
      final pdfFile = await ref
          .read(pdfGeneratorServiceProvider)
          .generateAndSavePdf(
            document: doc,
            config: config,
          );
      await ref
          .read(documentsProvider.notifier)
          .updateGeneratedPdfPath(
            documentId: doc.id,
            pdfPath: pdfFile.path,
          );
      await ref
          .read(shareExportServiceProvider)
          .shareFiles(
            filePaths: [pdfFile.path],
            subject: doc.title,
          );
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final document = docs.where((d) => d.id == widget.documentId).firstOrNull;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (document == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PDF Export Settings')),
        body: const Center(child: Text('Document not found.')),
      );
    }

    if (!_initialized) {
      _fileNameController.text = FormatUtils.sanitizeFileName(document.title);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Export Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Document summary header
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  document.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${document.pageCount} page(s) • Source images: ${FormatUtils.formatBytes(document.fileSizeBytes)}',
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Custom Filename
            Text(
              'PDF Filename',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fileNameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.description_outlined),
                suffixText: '.pdf',
                hintText: 'Enter PDF filename',
              ),
            ),
            const SizedBox(height: 20),

            // Page Size
            Text(
              'Page Size',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<PdfPageSizePreset>(
                groupValue: _pageSize,
                onChanged: (val) {
                  if (val != null) setState(() => _pageSize = val);
                },
                child: Column(
                  children: [
                    for (final preset in PdfPageSizePreset.values)
                      RadioListTile<PdfPageSizePreset>(
                        value: preset,
                        title: Text(
                          preset.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(preset.description),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Orientation
            Text(
              'Page Orientation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PdfOrientationPreset>(
              segments: const [
                ButtonSegment(
                  value: PdfOrientationPreset.portrait,
                  icon: Icon(Icons.stay_current_portrait_rounded),
                  label: Text('Portrait'),
                ),
                ButtonSegment(
                  value: PdfOrientationPreset.landscape,
                  icon: Icon(Icons.stay_current_landscape_rounded),
                  label: Text('Landscape'),
                ),
              ],
              selected: {_orientation},
              onSelectionChanged: (set) {
                setState(() => _orientation = set.first);
              },
            ),
            const SizedBox(height: 20),

            // Compression / Output Quality
            Text(
              'Output Quality & Compression',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<PdfQualityPreset>(
                groupValue: _quality,
                onChanged: (val) {
                  if (val != null) setState(() => _quality = val);
                },
                child: Column(
                  children: [
                    for (final q in PdfQualityPreset.values)
                      RadioListTile<PdfQualityPreset>(
                        value: q,
                        title: Text(
                          q.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(q.description),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Page Margins
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page Margins',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_marginPoints.round()} pt',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: _marginPoints,
              min: 0,
              max: 36,
              divisions: 9,
              label: '${_marginPoints.round()} pt',
              onChanged: (val) => setState(() => _marginPoints = val),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            FilledButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () => _generateAndOpenPreview(document),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_rounded),
              label: const Text('Generate & Preview PDF'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating
                        ? null
                        : () => _saveViaSystemPicker(document),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save to Device'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating
                        ? null
                        : () => _sharePdfDirectly(document),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

