import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/theme/theme_provider.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';
import 'package:scanpro/shared/widgets/scanpro_logo.dart';

/// Primary application shell with Material 3 [NavigationBar] and Quick Scan FAB.
class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.titleWidget,
    this.actions,
    this.showScanFab = true,
  });

  final int currentIndex;
  final Widget body;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showScanFab;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.library);
      case 2:
        context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: titleWidget ??
            const ScanProLogo(
              size: 36,
              showWordmark: true,
              wordmarkFontSize: 20,
            ),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Search Documents',
            onPressed: () => context.push(AppRoutes.search),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .toggleBrightness(theme.brightness);
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ), 
      body: SafeArea(child: body),
      floatingActionButton: showScanFab
          ? FloatingActionButton.extended(
              onPressed: () {
                final notifier = ref.read(scanSessionProvider.notifier);
                notifier.startNewSession();
                context.push(AppRoutes.scanner);
              },
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scan'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
