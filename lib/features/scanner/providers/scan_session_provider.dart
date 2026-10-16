import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/core/services/image_processing_service.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/repositories/document_repository.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:uuid/uuid.dart';

/// Holds a single captured or imported page in the active scan session,
/// including both the raw capture (`originalImagePath`) and the perspective-cropped,
/// shadow-cleaned scanned output (`scannedImagePath`).
class DraftCapturedPage {
  const DraftCapturedPage({
    required this.originalImagePath,
    required this.scannedImagePath,
    this.editSettings = const PageEditSettings(
      filter: ScanFilterType.enhancedColor,
    ),
    this.qualityReport,
  });

  /// Path to the uncropped raw photo (used for non-destructive re-cropping).
  final String originalImagePath;

  /// Path to the cropped, perspective-rectified, shadow-cleaned scanned image.
  final String scannedImagePath;

  /// Active crop corners, filter, and rotation for this draft page.
  final PageEditSettings editSettings;

  final ImageQualityReport? qualityReport;

  /// Compatibility getter returning the processed scan image path.
  String get imagePath => scannedImagePath;

  int get rotationQuarterTurns => editSettings.rotationQuarterTurns;

  DraftCapturedPage copyWith({
    String? originalImagePath,
    String? scannedImagePath,
    PageEditSettings? editSettings,
    ImageQualityReport? qualityReport,
  }) {
    return DraftCapturedPage(
      originalImagePath: originalImagePath ?? this.originalImagePath,
      scannedImagePath: scannedImagePath ?? this.scannedImagePath,
      editSettings: editSettings ?? this.editSettings,
      qualityReport: qualityReport ?? this.qualityReport,
    );
  }
}

/// State of the active multi-page camera capture or gallery import session.
class ScanSessionState {
  const ScanSessionState({
    this.pages = const [],
    this.targetDocumentId,
    this.targetFolderId,
    this.selectedIndex = 0,
    this.isSaving = false,
    this.isProcessingScan = false,
  });

  final List<DraftCapturedPage> pages;

  /// If non-null, new pages will be appended to this existing document.
  final String? targetDocumentId;

  /// If non-null, a newly created document will be placed in this folder.
  final String? targetFolderId;

  final int selectedIndex;
  final bool isSaving;
  final bool isProcessingScan;

  DraftCapturedPage? get currentPage =>
      (selectedIndex >= 0 && selectedIndex < pages.length)
      ? pages[selectedIndex]
      : null;

  ScanSessionState copyWith({
    List<DraftCapturedPage>? pages,
    String? targetDocumentId,
    bool clearTargetDocumentId = false,
    String? targetFolderId,
    bool clearTargetFolderId = false,
    int? selectedIndex,
    bool? isSaving,
    bool? isProcessingScan,
  }) {
    return ScanSessionState(
      pages: pages ?? List<DraftCapturedPage>.from(this.pages),
      targetDocumentId: clearTargetDocumentId
          ? null
          : (targetDocumentId ?? this.targetDocumentId),
      targetFolderId: clearTargetFolderId
          ? null
          : (targetFolderId ?? this.targetFolderId),
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isSaving: isSaving ?? this.isSaving,
      isProcessingScan: isProcessingScan ?? this.isProcessingScan,
    );
  }
}

/// Notifier managing AI Edge-Detection scanning, camera captures, gallery imports,
/// automatic perspective rectification, shadow removal, and committing to SQLite.
class ScanSessionNotifier extends Notifier<ScanSessionState> {
  final ImagePicker _imagePicker = ImagePicker();
  static const Uuid _uuid = Uuid();

  @override
  ScanSessionState build() => const ScanSessionState();

  /// Starts a fresh scan session, optionally targeting an existing document or folder.
  void startNewSession({String? targetDocumentId, String? targetFolderId}) {
    state = ScanSessionState(
      pages: const [],
      targetDocumentId: targetDocumentId,
      targetFolderId: targetFolderId,
      selectedIndex: 0,
    );
  }

  /// Launches Google ML Kit's on-device AI Document Scanner (`ScannerMode.full`),
  /// providing real-time neural edge tracking, auto-shutter when steady,
  /// perspective correction, shadow/stain removal, and multi-page scanning.
  ///
  /// Returns the number of pages scanned (`0` if the user cancelled).
  Future<int> launchNativeAiDocumentScanner() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: 50,
        isGalleryImport: true,
      ),
    );

    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      if (images == null || images.isEmpty) {
        return 0;
      }

      final newDrafts = <DraftCapturedPage>[];
      for (final imgPath in images) {
        if (imgPath.isEmpty) continue;
        newDrafts.add(
          DraftCapturedPage(
            originalImagePath: imgPath,
            scannedImagePath: imgPath,
            editSettings: const PageEditSettings(
              filter: ScanFilterType.original,
            ),
          ),
        );
      }

      if (newDrafts.isEmpty) return 0;

      final updated = [...state.pages, ...newDrafts];
      state = state.copyWith(
        pages: updated,
        selectedIndex: updated.length - 1,
      );
      return newDrafts.length;
    } finally {
      await scanner.close();
    }
  }

  /// Processes a raw camera capture at [rawPath] through the document scanner
  /// pipeline (4-corner paper detection + perspective warp + shadow removal &
  /// Magic Color paper whitening).
  Future<DraftCapturedPage> _createScannedDraftFromRaw(
    String rawPath, {
    PageEditSettings? customSettings,
  }) async {
    final processor = ref.read(imageProcessingServiceProvider);
    final tempDir = await getTemporaryDirectory();
    final scannedPath = p.join(
      tempDir.path,
      'scan_${_uuid.v4()}.jpg',
    );

    final quality = await processor.analyzeImageQuality(rawPath);

    if (customSettings != null) {
      await processor.processPageImage(
        originalImagePath: rawPath,
        processedImagePath: scannedPath,
        settings: customSettings,
      );
      return DraftCapturedPage(
        originalImagePath: rawPath,
        scannedImagePath: scannedPath,
        editSettings: customSettings,
        qualityReport: quality,
      );
    }

    final autoResult = await processor.autoScanDocument(
      originalImagePath: rawPath,
      processedImagePath: scannedPath,
      defaultFilter: ScanFilterType.enhancedColor,
      autoCropEdges: true,
    );

    return DraftCapturedPage(
      originalImagePath: rawPath,
      scannedImagePath: scannedPath,
      editSettings: autoResult.appliedSettings,
      qualityReport: quality,
    );
  }

  /// Adds a newly captured camera photo and runs automatic document edge crop,
  /// perspective rectification, and Magic Scan enhancement.
  Future<void> addCapturedPage(
    String rawPath, {
    PageEditSettings? customSettings,
  }) async {
    state = state.copyWith(isProcessingScan: true);
    try {
      final draft = await _createScannedDraftFromRaw(
        rawPath,
        customSettings: customSettings,
      );
      final updated = [...state.pages, draft];
      state = state.copyWith(
        pages: updated,
        selectedIndex: updated.length - 1,
      );
    } finally {
      state = state.copyWith(isProcessingScan: false);
    }
  }

  /// Replaces the page at [index] (used when retaking a page).
  Future<void> replacePageAt(
    int index,
    String newRawPath, {
    PageEditSettings? customSettings,
  }) async {
    if (index < 0 || index >= state.pages.length) return;
    state = state.copyWith(isProcessingScan: true);
    try {
      final draft = await _createScannedDraftFromRaw(
        newRawPath,
        customSettings: customSettings,
      );
      final updated = List<DraftCapturedPage>.from(state.pages);
      updated[index] = draft;
      state = state.copyWith(pages: updated, selectedIndex: index);
    } finally {
      state = state.copyWith(isProcessingScan: false);
    }
  }

  /// Re-processes the currently selected draft page with new [settings]
  /// (e.g., changing filter between Magic Color, B&W Sharp, Grayscale, Original,
  /// or adjusting the 4 crop corners).
  Future<void> updateCurrentPageSettings(PageEditSettings settings) async {
    final idx = state.selectedIndex;
    if (idx < 0 || idx >= state.pages.length) return;
    final current = state.pages[idx];

    state = state.copyWith(isProcessingScan: true);
    try {
      final processor = ref.read(imageProcessingServiceProvider);
      final tempDir = await getTemporaryDirectory();
      final newScannedPath = p.join(
        tempDir.path,
        'scan_${_uuid.v4()}.jpg',
      );

      await processor.processPageImage(
        originalImagePath: current.originalImagePath,
        processedImagePath: newScannedPath,
        settings: settings,
      );

      final updated = List<DraftCapturedPage>.from(state.pages);
      updated[idx] = current.copyWith(
        scannedImagePath: newScannedPath,
        editSettings: settings,
      );
      state = state.copyWith(pages: updated);
    } finally {
      state = state.copyWith(isProcessingScan: false);
    }
  }

  /// Opens the Android system photo picker to import one or multiple images
  /// and automatically converts them into scanned document pages.
  Future<int> pickMultipleFromGallery() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(imageQuality: 94);
      if (pickedFiles.isEmpty) return 0;

      state = state.copyWith(isProcessingScan: true);
      final newDrafts = <DraftCapturedPage>[];
      for (final xfile in pickedFiles) {
        final draft = await _createScannedDraftFromRaw(xfile.path);
        newDrafts.add(draft);
      }

      final updated = [...state.pages, ...newDrafts];
      state = state.copyWith(
        pages: updated,
        selectedIndex: updated.length - 1,
        isProcessingScan: false,
      );
      return pickedFiles.length;
    } catch (e) {
      state = state.copyWith(isProcessingScan: false);
      throw StorageException(
        userMessage: 'Could not import images from your gallery.',
        cause: e,
      );
    }
  }

  void selectPage(int index) {
    if (index >= 0 && index < state.pages.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  Future<void> rotateCurrentPage() async {
    final current = state.currentPage;
    if (current == null) return;
    await updateCurrentPageSettings(
      current.editSettings.copyWith(
        rotationQuarterTurns: current.editSettings.rotationQuarterTurns + 1,
      ),
    );
  }

  void removePageAt(int index) {
    if (index < 0 || index >= state.pages.length) return;
    final updated = List<DraftCapturedPage>.from(state.pages)..removeAt(index);
    final nextIndex = updated.isEmpty
        ? 0
        : state.selectedIndex.clamp(0, updated.length - 1);
    state = state.copyWith(pages: updated, selectedIndex: nextIndex);
  }

  void reorderPages(int oldIndex, int newIndex) {
    final updated = List<DraftCapturedPage>.from(state.pages);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(pages: updated, selectedIndex: newIndex);
  }

  /// Commits all draft pages in the current session to a [ScannedDocument].
  Future<ScannedDocument> commitSession({String? customTitle}) async {
    if (state.pages.isEmpty) {
      throw const StorageException(
        userMessage: 'No pages to save. Capture or import at least one page.',
      );
    }

    state = state.copyWith(isSaving: true);
    try {
      final docsNotifier = ref.read(documentsProvider.notifier);
      final inputs = state.pages
          .map(
            (p) => NewScannedPageInput(
              originalSourcePath: p.originalImagePath,
              processedSourcePath: p.scannedImagePath,
              editSettings: p.editSettings,
            ),
          )
          .toList();

      ScannedDocument savedDoc;
      if (state.targetDocumentId != null) {
        savedDoc = await docsNotifier.addPageInputsToDocument(
          documentId: state.targetDocumentId!,
          pageInputs: inputs,
        );
      } else {
        savedDoc = await docsNotifier.createDocumentFromPageInputs(
          pageInputs: inputs,
          title: customTitle,
          folderId: state.targetFolderId,
        );
      }

      state = const ScanSessionState();
      return savedDoc;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final scanSessionProvider =
    NotifierProvider<ScanSessionNotifier, ScanSessionState>(
      ScanSessionNotifier.new,
    );

/// Tracks the currently selected document & page for the Crop/Perspective
/// and Filter Editor screens.
class ActivePageEditTarget {
  const ActivePageEditTarget({
    required this.documentId,
    required this.pageId,
  });

  final String documentId;
  final String pageId;
}

class ActivePageEditNotifier extends Notifier<ActivePageEditTarget?> {
  @override
  ActivePageEditTarget? build() => null;

  void setTarget({required String documentId, required String pageId}) {
    state = ActivePageEditTarget(documentId: documentId, pageId: pageId);
  }
}

final activePageEditProvider =
    NotifierProvider<ActivePageEditNotifier, ActivePageEditTarget?>(
      ActivePageEditNotifier.new,
    );
