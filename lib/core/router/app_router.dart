import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/features/documents/presentation/document_editor_screen.dart';
import 'package:scanpro/features/documents/presentation/document_library_screen.dart';
import 'package:scanpro/features/documents/presentation/folder_details_screen.dart';
import 'package:scanpro/features/home/presentation/home_screen.dart';
import 'package:scanpro/features/image_editor/presentation/crop_editor_screen.dart';
import 'package:scanpro/features/image_editor/presentation/filter_editor_screen.dart';
import 'package:scanpro/features/ocr/presentation/ocr_viewer_screen.dart';
import 'package:scanpro/features/onboarding/presentation/onboarding_screen.dart';
import 'package:scanpro/features/pdf_export/presentation/pdf_export_settings_screen.dart';
import 'package:scanpro/features/pdf_export/presentation/pdf_preview_screen.dart';
import 'package:scanpro/features/scanner/presentation/camera_scanner_screen.dart';
import 'package:scanpro/features/scanner/presentation/captured_preview_screen.dart';
import 'package:scanpro/features/search/presentation/search_screen.dart';
import 'package:scanpro/features/settings/presentation/settings_screen.dart';
import 'package:scanpro/features/splash/presentation/splash_screen.dart';

/// Global GoRouter provider configuring all 15 production screens in ScanPro.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      // 1. Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // 2. Onboarding Screen
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 3. Home Dashboard
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // 4. Camera Document Scanner
      GoRoute(
        path: AppRoutes.scanner,
        name: 'scanner',
        builder: (context, state) => const CameraScannerScreen(),
      ),

      // 5. Captured Page Preview
      GoRoute(
        path: AppRoutes.capturedPreview,
        name: 'capturedPreview',
        builder: (context, state) => const CapturedPreviewScreen(),
      ),

      // 6. Crop and Perspective Editor
      GoRoute(
        path: AppRoutes.cropEditor,
        name: 'cropEditor',
        builder: (context, state) => const CropEditorScreen(),
      ),

      // 7. Filter Editor
      GoRoute(
        path: AppRoutes.filterEditor,
        name: 'filterEditor',
        builder: (context, state) => const FilterEditorScreen(),
      ),

      // 8. Multi-Page Document Editor
      GoRoute(
        path: AppRoutes.documentEditor,
        name: 'documentEditor',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return DocumentEditorScreen(documentId: docId);
        },
      ),

      // 9. PDF Export Settings
      GoRoute(
        path: AppRoutes.pdfExportSettings,
        name: 'pdfExportSettings',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return PdfExportSettingsScreen(documentId: docId);
        },
      ),

      // 10. PDF Preview
      GoRoute(
        path: AppRoutes.pdfPreview,
        name: 'pdfPreview',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return PdfPreviewScreen(documentId: docId);
        },
      ),

      // 11. Document Library
      GoRoute(
        path: AppRoutes.library,
        name: 'library',
        builder: (context, state) => const DocumentLibraryScreen(),
      ),

      // 12. Folder Details
      GoRoute(
        path: AppRoutes.folderDetails,
        name: 'folderDetails',
        builder: (context, state) {
          final folderId = state.pathParameters['id'] ?? '';
          return FolderDetailsScreen(folderId: folderId);
        },
      ),

      // 13. OCR Text Viewer
      GoRoute(
        path: AppRoutes.ocrViewer,
        name: 'ocrViewer',
        builder: (context, state) {
          final docId = state.pathParameters['id'] ?? '';
          return OcrViewerScreen(documentId: docId);
        },
      ),

      // 14. Search Screen
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),

      // 15. App Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Route not found: ${state.uri}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
