import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/theme/theme_provider.dart';
import 'package:scanpro/core/utils/format_utils.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/features/documents/providers/documents_provider.dart';
import 'package:scanpro/shared/widgets/app_shell_scaffold.dart';

/// Screen 15: App Settings & Privacy Screen.
///
/// Controls theme mode, view preferences, offline storage cleanup, privacy
/// disclosures, and architecture readiness for future optional features.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final displayPrefs = ref.watch(documentDisplayPrefsProvider);
    final docs =
        ref.watch(documentsProvider).value ?? const <ScannedDocument>[];
    final totalBytes = docs.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppShellScaffold(
      currentIndex: 2,
      titleWidget: const Text('Settings & Privacy'),
      showScanFab: false,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          Text(
            'Appearance & Display',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('App Theme'),
                  subtitle: Text(switch (themeMode) {
                    ThemeMode.light => 'Light Mode',
                    ThemeMode.dark => 'Dark Mode',
                    ThemeMode.system => 'System Default',
                  }),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (set) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(set.first);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.grid_view_rounded),
                  title: const Text('Default to Grid View'),
                  subtitle: const Text(
                    'Display document thumbnails in a multi-column grid',
                  ),
                  value: displayPrefs.isGridView,
                  onChanged: (_) {
                    ref
                        .read(documentDisplayPrefsProvider.notifier)
                        .toggleViewMode();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Offline Storage & Data Privacy
          Text(
            'Local Storage & Privacy Controls',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined),
                  title: const Text('App-Private Document Vault'),
                  subtitle: Text(
                    '${docs.length} document(s) stored locally • ${FormatUtils.formatBytes(totalBytes)} used',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.slideshow_rounded),
                  title: const Text('Replay Welcome Onboarding'),
                  subtitle: const Text(
                    'View the ScanPro feature walkthrough again',
                  ),
                  onTap: () => context.push(AppRoutes.onboarding),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Delete All Documents & OCR Data',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Permanently wipe all scanned images, PDFs, and extracted text from this device',
                  ),
                  onTap: docs.isEmpty
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Wipe All Local Documents?'),
                              content: Text(
                                'This will permanently delete all ${docs.length} document(s), PDFs, and OCR text from your device. This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.error,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete Everything'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(documentsProvider.notifier)
                                .deleteDocuments(
                                  docs.map((d) => d.id).toList(),
                                );
                            if (context.mounted) {
                              ErrorHandler.showSuccessSnackBar(
                                context,
                                'All documents and OCR data deleted.',
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Privacy Policy & Security Disclosures
          Text(
            'Privacy & Security',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '100% Offline Document Processing',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Camera and photo permissions are requested only when capturing or importing pages.\n'
                    '• All scanned images, perspective edits, PDFs, and OCR text are stored inside Android app-private storage by default.\n'
                    '• ScanPro never uploads your documents or extracted text to external servers.\n'
                    '• On-device OCR uses Google ML Kit Text Recognition locally on your phone.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text(AppConstants.appName),
              subtitle: const Text(
                'Version ${AppConstants.appVersion} • Core Offline Edition (No Ads / Watermark-Free)',
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

