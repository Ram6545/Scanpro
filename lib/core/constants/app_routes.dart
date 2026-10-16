/// Centralized route definitions and helper builders for all 15 ScanPro screens.
class AppRoutes {
  AppRoutes._();

  // 1. Splash screen
  static const String splash = '/splash';

  // 2. Onboarding screen
  static const String onboarding = '/onboarding';

  // 3. Home dashboard
  static const String home = '/';

  // 4. Camera scanner
  static const String scanner = '/scanner';

  // 5. Captured page preview
  static const String capturedPreview = '/scanner/preview';

  // 6. Crop and perspective editor
  static const String cropEditor = '/editor/crop';

  // 7. Filter editor
  static const String filterEditor = '/editor/filter';

  // 8. Multi-page document editor
  static const String documentEditor = '/document/:id/edit';
  static String documentEditorPath(String documentId) =>
      '/document/$documentId/edit';

  // 9. PDF export settings
  static const String pdfExportSettings = '/document/:id/pdf-settings';
  static String pdfExportSettingsPath(String documentId) =>
      '/document/$documentId/pdf-settings';

  // 10. PDF preview
  static const String pdfPreview = '/document/:id/pdf-preview';
  static String pdfPreviewPath(String documentId) =>
      '/document/$documentId/pdf-preview';

  // 11. Document library
  static const String library = '/library';

  // 12. Folder details
  static const String folderDetails = '/folder/:id';
  static String folderDetailsPath(String folderId) => '/folder/$folderId';

  // 13. OCR text viewer
  static const String ocrViewer = '/document/:id/ocr';
  static String ocrViewerPath(String documentId) => '/document/$documentId/ocr';

  // 14. Search screen
  static const String search = '/search';

  // 15. App settings
  static const String settings = '/settings';
}

