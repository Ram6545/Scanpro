/// Application-wide constants for ScanPro.
class AppConstants {
  AppConstants._();

  // Branding
  static const String appName = 'ScanPro';
  static const String appTagline = 'Smart Offline Document Scanner';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.scanpro.app.scanpro';

  // Local Storage Subdirectories (inside app-private storage)
  static const String documentsDirName = 'scanpro_documents';
  static const String pagesOriginalDirName = 'pages_original';
  static const String pagesProcessedDirName = 'pages_processed';
  static const String thumbnailsDirName = 'thumbnails';
  static const String generatedPdfsDirName = 'generated_pdfs';
  static const String exportedTextDirName = 'exported_text';

  // SharedPreferences Keys
  static const String prefOnboardingCompleted = 'pref_onboarding_completed';
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefIsGridView = 'pref_is_grid_view';
  static const String prefSortOption = 'pref_sort_option';
  static const String prefSortAscending = 'pref_sort_ascending';
  static const String prefDefaultPdfPageSize = 'pref_default_pdf_page_size';
  static const String prefDefaultPdfQuality = 'pref_default_pdf_quality';

  // Database
  static const String databaseName = 'scanpro_metadata.db';
  static const int databaseVersion = 1;
}

