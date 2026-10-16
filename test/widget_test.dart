import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanpro/app.dart';
import 'package:scanpro/core/services/preferences_service.dart';
import 'package:scanpro/core/theme/theme_provider.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDocumentsNotifier extends DocumentsNotifier {
  @override
  Future<List<ScannedDocument>> build() async => const [];
}

class _FakeFoldersNotifier extends FoldersNotifier {
  @override
  Future<List<DocumentFolder>> build() async =>
      DocumentFolder.defaultFolders();
}

void main() {
  group('ScanPro Unit Tests – Utilities & Data Models', () {
    test('FormatUtils formats byte counts and sanitizes filenames', () {
      expect(FormatUtils.formatBytes(0), '0 B');
      expect(FormatUtils.formatBytes(512), '512 B');
      expect(FormatUtils.formatBytes(2048), '2.00 KB');
      expect(FormatUtils.formatBytes(1572864), '1.50 MB');

      expect(
        FormatUtils.sanitizeFileName('Tax Invoice: 2026/10*'),
        'Tax_Invoice__2026_10_',
      );
      expect(FormatUtils.sanitizeFileName('   '), 'Document');
    });

    test('ScannedDocument & ScannedPage serialize and match OCR search', () {
      final now = DateTime.utc(2026, 10, 11, 12, 0);
      final page = ScannedPage(
        id: 'page_1',
        documentId: 'doc_1',
        pageNumber: 1,
        originalImagePath: '/data/orig_1.jpg',
        processedImagePath: '/data/proc_1.jpg',
        createdAt: now,
        ocrText: 'Total Amount Due: USD 249.00',
        fileSizeBytes: 120000,
        editSettings: const PageEditSettings(
          rotationQuarterTurns: 1,
          brightness: 0.1,
          contrast: 1.2,
          filter: ScanFilterType.enhancedColor,
        ),
      );

      final pageRestored = ScannedPage.fromMap(page.toMap());
      expect(pageRestored.id, 'page_1');
      expect(pageRestored.editSettings.filter, ScanFilterType.enhancedColor);
      expect(pageRestored.editSettings.rotationQuarterTurns, 1);

      final doc = ScannedDocument(
        id: 'doc_1',
        title: 'Hotel Receipt',
        folderId: 'folder_receipts',
        pages: [pageRestored],
        fileSizeBytes: 120000,
        createdAt: now,
        updatedAt: now,
      );

      expect(doc.pageCount, 1);
      expect(doc.hasOcrText, isTrue);
      expect(doc.matchesSearchQuery('hotel'), isTrue);
      expect(doc.matchesSearchQuery('249.00'), isTrue);
      expect(doc.matchesSearchQuery('passport'), isFalse);

      final defaultFolders = DocumentFolder.defaultFolders(now);
      expect(defaultFolders.length, 5);
    });
  });

  group('ScanPro Widget Tests – Full App Navigation & Screens', () {
    testWidgets(
      'First launch shows Splash -> Onboarding -> Home Dashboard -> Library -> Settings',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              documentsProvider.overrideWith(_FakeDocumentsNotifier.new),
              foldersProvider.overrideWith(_FakeFoldersNotifier.new),
            ],
            child: const ScanProApp(),
          ),
        );

        // Verify Splash Screen renders initially
        expect(find.text('Smart Offline Document Scanner'), findsOneWidget);

        // Advance timer past Splash autoNavigateDelay (900ms) and settle animations
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pumpAndSettle();

        // Verify Onboarding Screen slide 1 is visible
        expect(find.text('Smart Document Capture'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        // Tap Continue twice to reach slide 3, then tap Get Started
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Perspective & Scan Filters'), findsOneWidget);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Export PDFs & Extract Text'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();

        // Verify we landed on the real HomeScreen with Scan Document & Import Gallery
        expect(prefs.getBool('pref_onboarding_completed'), isTrue);
        expect(find.text('Scan Document'), findsOneWidget);
        expect(find.text('Import Gallery'), findsWidgets);
        expect(find.text('Categories & Folders'), findsOneWidget);

        // Navigate to Library tab via bottom NavigationBar
        await tester.tap(find.text('Library'));
        await tester.pumpAndSettle();
        expect(find.text('Document Library'), findsOneWidget);

        // Navigate to Settings tab via bottom NavigationBar
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Settings & Privacy'), findsOneWidget);
        expect(find.text('App-Private Document Vault'), findsOneWidget);
      },
    );

    testWidgets('ThemeModeNotifier toggles between Light and Dark mode', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'pref_onboarding_completed': true,
      });
      final prefs = await SharedPreferences.getInstance();

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            documentsProvider.overrideWith(_FakeDocumentsNotifier.new),
            foldersProvider.overrideWith(_FakeFoldersNotifier.new),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const ScanProApp();
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(capturedRef.read(themeModeProvider), ThemeMode.system);

      await capturedRef
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(capturedRef.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('pref_theme_mode'), 'dark');
    });
  });
}
