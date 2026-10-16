import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/services/preferences_service.dart';
import 'package:scanpro/shared/widgets/scanpro_logo.dart';

/// Data model for a single slide in the [OnboardingScreen].
class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.highlights,
  });

  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<String> highlights;
}

/// Screen 2: Onboarding Screen.
///
/// Introduces ScanPro's offline-first scanning, perspective/filter editing,
/// and multi-page PDF + on-device OCR capabilities without requiring sign-in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      badge: '100% OFFLINE & PRIVATE',
      title: 'Smart Document Capture',
      description:
          'Turn receipts, contracts, ID cards, and notes into crystal-clear digital scans right on your Android device.',
      icon: Icons.document_scanner_rounded,
      accentColor: Color(0xFF0D47A1),
      highlights: [
        'Multi-page session capture & gallery import',
        'Framing guide with lighting & alignment hints',
        'No account sign-in or cloud upload required',
      ],
    ),
    _OnboardingSlideData(
      badge: 'PRECISION STUDIO',
      title: 'Perspective & Scan Filters',
      description:
          'Correct skewed angles with 4-corner perspective warping and enhance readability with studio-grade filters.',
      icon: Icons.crop_rotate_rounded,
      accentColor: Color(0xFF00897B),
      highlights: [
        'Interactive 4-corner perspective correction',
        'Original, Magic Color, Grayscale & B&W Sharp filters',
        'Non-destructive undo & reset anytime',
      ],
    ),
    _OnboardingSlideData(
      badge: 'PDF & ON-DEVICE OCR',
      title: 'Export PDFs & Extract Text',
      description:
          'Generate multi-page A4 or Letter PDFs with customizable compression and extract searchable text offline.',
      icon: Icons.picture_as_pdf_rounded,
      accentColor: Color(0xFF3949AB),
      highlights: [
        'A4, Letter & original page sizes with quality control',
        'On-device OCR text recognition & TXT export',
        'Organize in folders, search & share effortlessly',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(preferencesServiceProvider).setOnboardingCompleted(true);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _nextSlide() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with logo and Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const ScanProLogo(
                    size: 36,
                    showWordmark: true,
                    wordmarkFontSize: 19,
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // Slide pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                slide.accentColor,
                                slide.accentColor.withValues(alpha: 0.72),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: slide.accentColor.withValues(alpha: 0.25),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            size: 72,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide.badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: slide.highlights
                                  .map(
                                    (point) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 20,
                                            color: colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              point,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom pagination indicators + CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isSelected ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _nextSlide,
                      icon: Icon(
                        isLastPage
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(isLastPage ? 'Get Started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

