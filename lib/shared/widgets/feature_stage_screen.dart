import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/shared/widgets/app_shell_scaffold.dart';

/// Interactive route shell used during Phase 1 to verify navigation across
/// all 15 screens in the ScanPro architecture.
class FeatureStageScreen extends StatelessWidget {
  const FeatureStageScreen({
    super.key,
    required this.screenNumber,
    required this.title,
    required this.subtitle,
    required this.phaseLabel,
    required this.icon,
    this.shellTabIndex,
    this.routeParameterInfo,
  });

  final int screenNumber;
  final String title;
  final String subtitle;
  final String phaseLabel;
  final IconData icon;
  final int? shellTabIndex;
  final String? routeParameterInfo;

  @override
  Widget build(BuildContext context) {
    final content = _FeatureStageBody(
      screenNumber: screenNumber,
      title: title,
      subtitle: subtitle,
      phaseLabel: phaseLabel,
      icon: icon,
      routeParameterInfo: routeParameterInfo,
    );

    if (shellTabIndex != null) {
      return AppShellScaffold(
        currentIndex: shellTabIndex!,
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(child: content),
    );
  }
}

class _FeatureStageBody extends StatelessWidget {
  const _FeatureStageBody({
    required this.screenNumber,
    required this.title,
    required this.subtitle,
    required this.phaseLabel,
    required this.icon,
    this.routeParameterInfo,
  });

  final int screenNumber;
  final String title;
  final String subtitle;
  final String phaseLabel;
  final IconData icon;
  final String? routeParameterInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Screen #$screenNumber • $phaseLabel',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (routeParameterInfo != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      routeParameterInfo!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Architecture Route Explorer (All 15 Screens)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap any destination below to test GoRouter navigation and route transitions.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RouteChip(
              label: '1. Splash',
              onTap: () => context.push(AppRoutes.splash),
            ),
            _RouteChip(
              label: '2. Onboarding',
              onTap: () => context.push(AppRoutes.onboarding),
            ),
            _RouteChip(
              label: '3. Home Dashboard',
              onTap: () => context.go(AppRoutes.home),
            ),
            _RouteChip(
              label: '4. Camera Scanner',
              onTap: () => context.push(AppRoutes.scanner),
            ),
            _RouteChip(
              label: '5. Captured Preview',
              onTap: () => context.push(AppRoutes.capturedPreview),
            ),
            _RouteChip(
              label: '6. Crop & Perspective',
              onTap: () => context.push(AppRoutes.cropEditor),
            ),
            _RouteChip(
              label: '7. Filter Studio',
              onTap: () => context.push(AppRoutes.filterEditor),
            ),
            _RouteChip(
              label: '8. Multi-Page Editor',
              onTap: () =>
                  context.push(AppRoutes.documentEditorPath('demo-doc-01')),
            ),
            _RouteChip(
              label: '9. PDF Export Settings',
              onTap: () =>
                  context.push(AppRoutes.pdfExportSettingsPath('demo-doc-01')),
            ),
            _RouteChip(
              label: '10. PDF Preview',
              onTap: () =>
                  context.push(AppRoutes.pdfPreviewPath('demo-doc-01')),
            ),
            _RouteChip(
              label: '11. Document Library',
              onTap: () => context.go(AppRoutes.library),
            ),
            _RouteChip(
              label: '12. Folder Details',
              onTap: () =>
                  context.push(AppRoutes.folderDetailsPath('folder_receipts')),
            ),
            _RouteChip(
              label: '13. OCR Text Viewer',
              onTap: () => context.push(AppRoutes.ocrViewerPath('demo-doc-01')),
            ),
            _RouteChip(
              label: '14. Search',
              onTap: () => context.push(AppRoutes.search),
            ),
            _RouteChip(
              label: '15. Settings',
              onTap: () => context.go(AppRoutes.settings),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.arrow_outward_rounded, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
