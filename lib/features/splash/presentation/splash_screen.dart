import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/services/preferences_service.dart';
import 'package:scanpro/shared/widgets/scanpro_logo.dart';

/// Screen 1: Splash Screen.
///
/// Displays the full-screen R SCANNER branded splash screen matching the user's
/// logo design (dark slate top with bold "R" + "SCANNER", mint teal bottom band,
/// and folded-corner document with camera icon straddling the horizon).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.autoNavigateDelay = const Duration(milliseconds: 900),
  });

  final Duration autoNavigateDelay;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _navigationTimer = Timer(widget.autoNavigateDelay, _navigateNext);
  }

  void _navigateNext() {
    if (!mounted) return;
    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.isOnboardingCompleted) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RScannerBrandColors.darkSlate,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          final splitY = totalH * 0.72;
          const docWidth = 116.0;
          const docHeight = 148.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Two-tone background: Dark Slate top (72%) + Mint Teal bottom (28%)
              Column(
                children: [
                  Expanded(
                    flex: 72,
                    child: Container(color: RScannerBrandColors.darkSlate),
                  ),
                  Expanded(
                    flex: 28,
                    child: Container(color: RScannerBrandColors.mintTeal),
                  ),
                ],
              ),

              // 2. Upper typography: Giant "R" + "SCANNER"
              Positioned(
                top: totalH * 0.16,
                left: 24,
                right: 24,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'R',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 136,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                offset: const Offset(8, 10),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SCANNER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                offset: const Offset(4, 6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Centerpiece Folded Document + Camera Icon straddling the horizon line
              Positioned(
                top: splitY - (docHeight * 0.68),
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Center(
                      child: RScannerDocumentCameraIcon(
                        width: docWidth,
                        height: docHeight,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Tagline & subtle progress indicator in the Mint Teal bottom band
              Positioned(
                bottom: 28,
                left: 24,
                right: 24,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppConstants.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RScannerBrandColors.darkSlate.withValues(
                            alpha: 0.85,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
