import 'package:flutter/material.dart';
import 'package:scanpro/core/constants/app_constants.dart';

/// Brand colors from the R SCANNER logo design.
class RScannerBrandColors {
  RScannerBrandColors._();

  static const Color darkSlate = Color(0xFF39464E);
  static const Color darkSlateShadow = Color(0xFF2E3940);
  static const Color mintTeal = Color(0xFF2CD5B4);
  static const Color mintTealShadow = Color(0xFF20B89A);
  static const Color paperWhite = Color(0xFFF6F9FB);
  static const Color paperFold = Color(0xFFC7D2D9);
}

/// Custom-painted brand icon and wordmark for R SCANNER (ScanPro).
class ScanProLogo extends StatelessWidget {
  const ScanProLogo({
    super.key,
    this.size = 48,
    this.showWordmark = false,
    this.wordmarkFontSize = 20,
  });

  final double size;
  final bool showWordmark;
  final double wordmarkFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: RScannerBrandColors.darkSlate,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _RScannerBadgePainter(),
      ),
    );

    if (!showWordmark) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: wordmarkFontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
                children: const [
                  TextSpan(
                    text: 'R ',
                    style: TextStyle(color: RScannerBrandColors.mintTeal),
                  ),
                  TextSpan(text: 'SCANNER'),
                ],
              ),
            ),
            Text(
              AppConstants.appTagline,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Standalone white folded-corner document icon with dark slate camera inside,
/// matching the centerpiece icon from the R SCANNER splash design.
class RScannerDocumentCameraIcon extends StatelessWidget {
  const RScannerDocumentCameraIcon({
    super.key,
    this.width = 116,
    this.height = 148,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _FoldedDocumentWithCameraPainter(),
      ),
    );
  }
}

class _RScannerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Dark slate upper background
    final topPaint = Paint()..color = RScannerBrandColors.darkSlate;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), topPaint);

    // 2. Mint teal lower band (bottom 34%)
    final splitY = h * 0.66;
    final bottomPaint = Paint()..color = RScannerBrandColors.mintTeal;
    canvas.drawRect(Rect.fromLTWH(0, splitY, w, h - splitY), bottomPaint);

    // 3. Bold white "R" in the upper half
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'R',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.36,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, h * 0.08),
    );

    // 4. Mini folded-corner document with camera straddling the split line
    canvas.save();
    final docW = w * 0.42;
    final docH = h * 0.44;
    canvas.translate((w - docW) / 2, h * 0.46);
    _FoldedDocumentWithCameraPainter.drawDocumentWithCamera(
      canvas,
      Size(docW, docH),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FoldedDocumentWithCameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    drawDocumentWithCamera(canvas, size);
  }

  static void drawDocumentWithCamera(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fold = w * 0.30;
    final radius = w * 0.11;

    // Document outline path with top-right folded corner
    final docPath = Path()
      ..moveTo(radius, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w, h - radius)
      ..quadraticBezierTo(w, h, w - radius, h)
      ..lineTo(radius, h)
      ..quadraticBezierTo(0, h, 0, h - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();

    // Soft drop shadow beneath the document
    canvas.save();
    canvas.translate(w * 0.04, h * 0.05);
    canvas.drawPath(
      docPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
    );
    canvas.restore();

    // Main paper body fill with subtle vertical gradient
    final paperPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Color(0xFFE4ECF0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(docPath, paperPaint);

    // Diagonal shadow cast by the folded corner onto the paper
    final foldShadowPath = Path()
      ..moveTo(w - fold, fold)
      ..lineTo(w, fold)
      ..lineTo(w, fold + fold * 0.65)
      ..close();
    canvas.drawPath(
      foldShadowPath,
      Paint()..color = Colors.black.withValues(alpha: 0.09),
    );

    // Folded corner flap (top-right)
    final flapRadius = radius * 0.55;
    final flapPath = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w - fold + flapRadius, fold)
      ..quadraticBezierTo(w - fold, fold, w - fold, fold - flapRadius)
      ..close();
    canvas.drawPath(
      flapPath,
      Paint()..color = RScannerBrandColors.paperFold,
    );

    // Camera icon centered in the lower-middle of the document page
    final camW = w * 0.52;
    final camH = camW * 0.68;
    final camLeft = (w - camW) / 2;
    final camTop = h * 0.49;
    final camPaint = Paint()..color = RScannerBrandColors.darkSlate;

    // Camera body rounded rectangle
    final camBodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(camLeft, camTop + camH * 0.16, camW, camH * 0.84),
      Radius.circular(camW * 0.14),
    );
    canvas.drawRRect(camBodyRect, camPaint);

    // Camera top viewfinder hump
    final humpW = camW * 0.42;
    final humpPath = Path()
      ..moveTo(camLeft + (camW - humpW) / 2 - humpW * 0.12, camTop + camH * 0.2)
      ..lineTo(camLeft + (camW - humpW) / 2 + humpW * 0.08, camTop)
      ..lineTo(camLeft + (camW + humpW) / 2 - humpW * 0.08, camTop)
      ..lineTo(camLeft + (camW + humpW) / 2 + humpW * 0.12, camTop + camH * 0.2)
      ..close();
    canvas.drawPath(humpPath, camPaint);

    // Camera lens circle (light grey/white)
    final lensCenter = Offset(w / 2, camTop + camH * 0.58);
    final lensRadius = camW * 0.21;
    canvas.drawCircle(
      lensCenter,
      lensRadius,
      Paint()..color = const Color(0xFFEFF4F7),
    );

    // Small flash dot in top-right of camera body
    canvas.drawCircle(
      Offset(camLeft + camW * 0.80, camTop + camH * 0.36),
      camW * 0.055,
      Paint()..color = const Color(0xFFEFF4F7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
