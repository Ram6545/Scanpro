import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/data/models/page_filter.dart';

/// Quality feedback metrics computed from a captured image frame.
class ImageQualityReport {
  const ImageQualityReport({
    required this.averageBrightness,
    required this.sharpnessScore,
  });

  /// Normalized average luminance in [0.0, 1.0].
  final double averageBrightness;

  /// Edge sharpness score (higher means sharper).
  final double sharpnessScore;

  bool get isLowLight => averageBrightness < 0.20;
  bool get isOverExposed => averageBrightness > 0.94;
  bool get isBlurry => sharpnessScore < 7.5;

  String get guidanceMessage {
    if (isLowLight) {
      return 'Low lighting detected — shadows removed automatically by Magic Scan.';
    }
    if (isBlurry) {
      return 'Slightly soft focus — hold steady or retake for sharper OCR text.';
    }
    if (isOverExposed) {
      return 'High glare detected — tilt slightly if text is washed out.';
    }
    return 'Document scanned, perspective-rectified & shadow-cleaned.';
  }
}

class _ProcessPagePayload {
  const _ProcessPagePayload({
    required this.sourcePath,
    required this.destinationPath,
    required this.rotationQuarterTurns,
    required this.brightness,
    required this.contrast,
    required this.filterName,
    required this.corners,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final String sourcePath;
  final String destinationPath;
  final int rotationQuarterTurns;
  final double brightness;
  final double contrast;
  final String filterName;
  final List<Map<String, double>> corners;
  final int maxDimension;
  final int jpegQuality;
}

/// Result of automatic document scanning (edge detection + perspective crop + scan filter).
class AutoScanResult {
  const AutoScanResult({
    required this.detectedCorners,
    required this.appliedSettings,
    required this.processedFileSizeBytes,
  });

  final List<Offset> detectedCorners;
  final PageEditSettings appliedSettings;
  final int processedFileSizeBytes;
}

/// Service that executes document boundary detection, 4-corner perspective
/// rectification, shadow removal (local illumination normalization), and scan
/// filters in background isolates.
class ImageProcessingService {
  const ImageProcessingService();

  /// Automatically turns a raw camera photo at [originalImagePath] into a
  /// cropped, perspective-rectified, shadow-cleaned scanned document at
  /// [processedImagePath].
  Future<AutoScanResult> autoScanDocument({
    required String originalImagePath,
    required String processedImagePath,
    ScanFilterType defaultFilter = ScanFilterType.enhancedColor,
    bool autoCropEdges = true,
  }) async {
    try {
      final detectedCorners = autoCropEdges
          ? await detectDocumentCorners(originalImagePath)
          : PageEditSettings.defaultCorners;

      final settings = PageEditSettings(
        rotationQuarterTurns: 0,
        brightness: 0.0,
        contrast: 1.0,
        filter: defaultFilter,
        corners: detectedCorners,
      );

      final sizeBytes = await processPageImage(
        originalImagePath: originalImagePath,
        processedImagePath: processedImagePath,
        settings: settings,
      );

      return AutoScanResult(
        detectedCorners: detectedCorners,
        appliedSettings: settings,
        processedFileSizeBytes: sizeBytes,
      );
    } catch (e) {
      throw ImageProcessingException(
        userMessage: 'Failed to auto-scan document image.',
        cause: e,
      );
    }
  }

  /// Applies [settings] to [originalImagePath] and writes the result to [processedImagePath].
  /// Returns the size in bytes of the newly written file.
  Future<int> processPageImage({
    required String originalImagePath,
    required String processedImagePath,
    required PageEditSettings settings,
    int maxDimension = 2200,
    int jpegQuality = 90,
  }) async {
    try {
      final payload = _ProcessPagePayload(
        sourcePath: originalImagePath,
        destinationPath: processedImagePath,
        rotationQuarterTurns: settings.rotationQuarterTurns,
        brightness: settings.brightness,
        contrast: settings.contrast,
        filterName: settings.filter.name,
        corners: settings.corners
            .map((c) => {'dx': c.dx, 'dy': c.dy})
            .toList(),
        maxDimension: maxDimension,
        jpegQuality: jpegQuality,
      );

      return await compute(_processImageIsolate, payload);
    } catch (e) {
      throw ImageProcessingException(
        userMessage: 'Failed to apply image adjustments to page.',
        cause: e,
      );
    }
  }

  /// Automatically estimates the 4 corners of a document sheet in [imagePath]
  /// in normalized coordinates `[0.0, 1.0]`.
  Future<List<Offset>> detectDocumentCorners(String imagePath) async {
    try {
      final rawPoints = await compute(_detectCornersIsolate, imagePath);
      return rawPoints
          .map((m) => Offset(m['dx']!, m['dy']!))
          .toList(growable: false);
    } catch (_) {
      return PageEditSettings.defaultCorners;
    }
  }

  /// Evaluates lighting and sharpness of a captured image on a background isolate.
  Future<ImageQualityReport> analyzeImageQuality(String imagePath) async {
    try {
      final metrics = await compute(_analyzeQualityIsolate, imagePath);
      return ImageQualityReport(
        averageBrightness: metrics['brightness'] ?? 0.55,
        sharpnessScore: metrics['sharpness'] ?? 15.0,
      );
    } catch (_) {
      return const ImageQualityReport(
        averageBrightness: 0.55,
        sharpnessScore: 16.0,
      );
    }
  }
}

int _processImageIsolate(_ProcessPagePayload payload) {
  final srcBytes = File(payload.sourcePath).readAsBytesSync();
  var image = img.decodeImage(srcBytes);
  if (image == null) {
    throw Exception('Unable to decode source image');
  }

  image = img.bakeOrientation(image);

  // Downscale excessively large images to save memory while preserving print clarity
  if (image.width > payload.maxDimension ||
      image.height > payload.maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: payload.maxDimension)
        : img.copyResize(image, height: payload.maxDimension);
  }

  // 1. Perspective correction / 4-corner quad warp
  final corners = payload.corners;
  final isFullRect =
      corners.length == 4 &&
      (corners[0]['dx']! - 0.0).abs() < 0.005 &&
      (corners[0]['dy']! - 0.0).abs() < 0.005 &&
      (corners[1]['dx']! - 1.0).abs() < 0.005 &&
      (corners[1]['dy']! - 0.0).abs() < 0.005 &&
      (corners[2]['dx']! - 1.0).abs() < 0.005 &&
      (corners[2]['dy']! - 1.0).abs() < 0.005 &&
      (corners[3]['dx']! - 0.0).abs() < 0.005 &&
      (corners[3]['dy']! - 1.0).abs() < 0.005;

  if (!isFullRect && corners.length == 4) {
    image = _warpPerspectiveBilinear(image, corners);
  }

  // 2. 90-degree rotation increments
  final turns = payload.rotationQuarterTurns % 4;
  if (turns == 1) {
    image = img.copyRotate(image, angle: 90);
  } else if (turns == 2) {
    image = img.copyRotate(image, angle: 180);
  } else if (turns == 3) {
    image = img.copyRotate(image, angle: 270);
  }

  // 3. True Document Scan Enhancement (Local Illumination Normalization + Shadow Removal)
  final filter = ScanFilterType.fromName(payload.filterName);
  final hasToneAdjustment =
      payload.brightness.abs() > 0.005 || (payload.contrast - 1.0).abs() > 0.005;

  if (filter != ScanFilterType.original || hasToneAdjustment) {
    _applyDocumentScanEnhancement(
      image,
      filter: filter,
      brightness: payload.brightness,
      contrast: payload.contrast,
    );
  }

  final outBytes = img.encodeJpg(image, quality: payload.jpegQuality);
  final outFile = File(payload.destinationPath);
  outFile.writeAsBytesSync(outBytes, flush: true);
  return outBytes.length;
}

/// Applies real document-scanner illumination normalization (shadow removal &
/// paper background whitening) and crisp ink contrast enhancement.
void _applyDocumentScanEnhancement(
  img.Image image, {
  required ScanFilterType filter,
  required double brightness,
  required double contrast,
}) {
  final w = image.width;
  final h = image.height;

  // Build a coarse 24x24 local background illumination map (dilated max luminance)
  // so shadows cast across the page are normalized to pure white paper!
  const gridW = 24;
  const gridH = 24;
  final cellMaxLuma = List<double>.filled(gridW * gridH, 210.0);

  if (filter != ScanFilterType.original) {
    for (var gy = 0; gy < gridH; gy++) {
      final yStart = (gy * h) ~/ gridH;
      final yEnd = math.min(h, ((gy + 1) * h) ~/ gridH);
      final stepY = math.max(1, (yEnd - yStart) ~/ 6);

      for (var gx = 0; gx < gridW; gx++) {
        final xStart = (gx * w) ~/ gridW;
        final xEnd = math.min(w, ((gx + 1) * w) ~/ gridW);
        final stepX = math.max(1, (xEnd - xStart) ~/ 6);

        var maxL = 85.0;
        for (var y = yStart; y < yEnd; y += stepY) {
          for (var x = xStart; x < xEnd; x += stepX) {
            final p = image.getPixel(x, y);
            final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
            if (luma > maxL) maxL = luma;
          }
        }
        cellMaxLuma[gy * gridW + gx] = maxL;
      }
    }

    // Smooth the illumination grid with a 3x3 box pass to avoid block artifacts
    final smoothed = List<double>.from(cellMaxLuma);
    for (var gy = 0; gy < gridH; gy++) {
      for (var gx = 0; gx < gridW; gx++) {
        var sum = 0.0;
        var cnt = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final ny = (gy + dy).clamp(0, gridH - 1);
            final nx = (gx + dx).clamp(0, gridW - 1);
            sum += cellMaxLuma[ny * gridW + nx];
            cnt++;
          }
        }
        smoothed[gy * gridW + gx] = sum / cnt;
      }
    }
    for (var i = 0; i < cellMaxLuma.length; i++) {
      cellMaxLuma[i] = smoothed[i];
    }
  }

  final brightnessOffset = brightness * 255.0;

  for (var y = 0; y < h; y++) {
    final gy = ((y / h) * (gridH - 1)).floor().clamp(0, gridH - 1);
    for (var x = 0; x < w; x++) {
      final gx = ((x / w) * (gridW - 1)).floor().clamp(0, gridW - 1);
      final localWhite = cellMaxLuma[gy * gridW + gx];

      final pixel = image.getPixel(x, y);
      var r = pixel.r.toDouble();
      var g = pixel.g.toDouble();
      var b = pixel.b.toDouble();

      if (filter == ScanFilterType.enhancedColor) {
        // Normalize against local paper illumination (removes shadows!)
        final scale = 250.0 / math.max(95.0, localWhite);
        r = (r * scale).clamp(0.0, 255.0);
        g = (g * scale).clamp(0.0, 255.0);
        b = (b * scale).clamp(0.0, 255.0);

        final luma = 0.299 * r + 0.587 * g + 0.114 * b;
        if (luma > 205.0) {
          // Whiten paper background cleanly
          final factor = ((luma - 205.0) / 50.0).clamp(0.0, 1.0);
          r = r + (255.0 - r) * factor * 0.85;
          g = g + (255.0 - g) * factor * 0.85;
          b = b + (255.0 - b) * factor * 0.85;
        } else {
          // Deepen ink & text contrast
          r = ((r - 128.0) * 1.25 + 122.0);
          g = ((g - 128.0) * 1.25 + 122.0);
          b = ((b - 128.0) * 1.25 + 122.0);
        }
      } else if (filter == ScanFilterType.grayscale) {
        final rawLuma = 0.299 * r + 0.587 * g + 0.114 * b;
        final normalized = (rawLuma * (250.0 / math.max(95.0, localWhite)))
            .clamp(0.0, 255.0);
        final stretched = normalized > 210.0
            ? 255.0
            : ((normalized - 128.0) * 1.22 + 126.0);
        r = stretched;
        g = stretched;
        b = stretched;
      } else if (filter == ScanFilterType.blackAndWhite) {
        // Adaptive local threshold (Sauvola/Bradley style using localWhite)
        final rawLuma = 0.299 * r + 0.587 * g + 0.114 * b;
        final threshold = localWhite * 0.78;
        final bw = rawLuma >= threshold
            ? 255.0
            : math.max(0.0, (rawLuma / math.max(1.0, threshold)) * 45.0);
        r = bw;
        g = bw;
        b = bw;
      }

      if (brightness.abs() > 0.005 || (contrast - 1.0).abs() > 0.005) {
        r = (r - 128.0) * contrast + 128.0 + brightnessOffset;
        g = (g - 128.0) * contrast + 128.0 + brightnessOffset;
        b = (b - 128.0) * contrast + 128.0 + brightnessOffset;
      }

      pixel
        ..r = r.clamp(0.0, 255.0).round()
        ..g = g.clamp(0.0, 255.0).round()
        ..b = b.clamp(0.0, 255.0).round();
    }
  }
}

/// Performs a 4-corner perspective transformation from normalized quad [corners]
/// (TL, TR, BR, BL) into a rectified rectangular page image.
img.Image _warpPerspectiveBilinear(
  img.Image src,
  List<Map<String, double>> corners,
) {
  final w = src.width.toDouble();
  final h = src.height.toDouble();

  final tlX = corners[0]['dx']!.clamp(0.0, 1.0) * (w - 1);
  final tlY = corners[0]['dy']!.clamp(0.0, 1.0) * (h - 1);
  final trX = corners[1]['dx']!.clamp(0.0, 1.0) * (w - 1);
  final trY = corners[1]['dy']!.clamp(0.0, 1.0) * (h - 1);
  final brX = corners[2]['dx']!.clamp(0.0, 1.0) * (w - 1);
  final brY = corners[2]['dy']!.clamp(0.0, 1.0) * (h - 1);
  final blX = corners[3]['dx']!.clamp(0.0, 1.0) * (w - 1);
  final blY = corners[3]['dy']!.clamp(0.0, 1.0) * (h - 1);

  final topWidth = math.sqrt(math.pow(trX - tlX, 2) + math.pow(trY - tlY, 2));
  final bottomWidth = math.sqrt(
    math.pow(brX - blX, 2) + math.pow(brY - blY, 2),
  );
  final leftHeight = math.sqrt(
    math.pow(blX - tlX, 2) + math.pow(blY - tlY, 2),
  );
  final rightHeight = math.sqrt(
    math.pow(brX - trX, 2) + math.pow(brY - trY, 2),
  );

  final dstWidth = math.max(64, math.max(topWidth, bottomWidth).round());
  final dstHeight = math.max(64, math.max(leftHeight, rightHeight).round());

  final dst = img.Image(width: dstWidth, height: dstHeight);

  for (var y = 0; y < dstHeight; y++) {
    final v = dstHeight > 1 ? y / (dstHeight - 1) : 0.0;
    for (var x = 0; x < dstWidth; x++) {
      final u = dstWidth > 1 ? x / (dstWidth - 1) : 0.0;

      final srcX =
          (1 - u) * (1 - v) * tlX +
          u * (1 - v) * trX +
          u * v * brX +
          (1 - u) * v * blX;
      final srcY =
          (1 - u) * (1 - v) * tlY +
          u * (1 - v) * trY +
          u * v * brY +
          (1 - u) * v * blY;

      final px = src.getPixel(
        srcX.round().clamp(0, src.width - 1),
        srcY.round().clamp(0, src.height - 1),
      );
      dst.setPixelRgb(x, y, px.r, px.g, px.b);
    }
  }

  return dst;
}

/// Detects the 4 corners of a paper document inside the image by comparing
/// center paper luminance against border background and finding extreme corner
/// coordinates `(x + y)` and `(x - y)`.
List<Map<String, double>> _detectCornersIsolate(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  var decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const [
      {'dx': 0.0, 'dy': 0.0},
      {'dx': 1.0, 'dy': 0.0},
      {'dx': 1.0, 'dy': 1.0},
      {'dx': 0.0, 'dy': 1.0},
    ];
  }

  decoded = img.bakeOrientation(decoded);
  const grid = 200;
  final small = img.copyResize(decoded, width: grid, height: grid);

  // Measure center region luminance (assumed to lie on the document sheet)
  var centerLumaSum = 0.0;
  var centerCount = 0;
  for (var y = 65; y < 135; y += 2) {
    for (var x = 65; x < 135; x += 2) {
      centerLumaSum += small.getPixel(x, y).luminanceNormalized;
      centerCount++;
    }
  }
  final centerMeanLuma = centerCount > 0
      ? centerLumaSum / centerCount
      : 0.65;

  // Measure outer border luminance
  var borderLumaSum = 0.0;
  var borderCount = 0;
  for (var i = 0; i < grid; i += 2) {
    borderLumaSum += small.getPixel(i, 4).luminanceNormalized;
    borderLumaSum += small.getPixel(i, grid - 5).luminanceNormalized;
    borderLumaSum += small.getPixel(4, i).luminanceNormalized;
    borderLumaSum += small.getPixel(grid - 5, i).luminanceNormalized;
    borderCount += 4;
  }
  final borderMeanLuma = borderCount > 0 ? borderLumaSum / borderCount : 0.3;

  // If the paper is significantly brighter than the desk/background, find the
  // 4 extreme corners of the bright paper region!
  final lumaContrast = centerMeanLuma - borderMeanLuma;
  if (lumaContrast > 0.12) {
    final threshold = borderMeanLuma + lumaContrast * 0.45;

    var minSum = 999999; // Top-Left: min(x + y)
    var maxSum = -999999; // Bottom-Right: max(x + y)
    var maxDiff = -999999; // Top-Right: max(x - y)
    var minDiff = 999999; // Bottom-Left: min(x - y)

    var tlX = 16, tlY = 14;
    var trX = grid - 16, trY = 14;
    var brX = grid - 16, brY = grid - 14;
    var blX = 16, blY = grid - 14;
    var paperPixels = 0;

    for (var y = 8; y < grid - 8; y++) {
      for (var x = 8; x < grid - 8; x++) {
        final l = small.getPixel(x, y).luminanceNormalized;
        if (l >= threshold) {
          paperPixels++;
          final sum = x + y;
          final diff = x - y;
          if (sum < minSum) {
            minSum = sum;
            tlX = x;
            tlY = y;
          }
          if (sum > maxSum) {
            maxSum = sum;
            brX = x;
            brY = y;
          }
          if (diff > maxDiff) {
            maxDiff = diff;
            trX = x;
            trY = y;
          }
          if (diff < minDiff) {
            minDiff = diff;
            blX = x;
            blY = y;
          }
        }
      }
    }

    // Ensure the detected quad covers a reasonable area of the frame (at least 18%)
    if (paperPixels > (grid * grid * 0.18)) {
      return [
        {
          'dx': (tlX / grid).clamp(0.02, 0.42),
          'dy': (tlY / grid).clamp(0.02, 0.42),
        },
        {
          'dx': (trX / grid).clamp(0.58, 0.98),
          'dy': (trY / grid).clamp(0.02, 0.42),
        },
        {
          'dx': (brX / grid).clamp(0.58, 0.98),
          'dy': (brY / grid).clamp(0.58, 0.98),
        },
        {
          'dx': (blX / grid).clamp(0.02, 0.42),
          'dy': (blY / grid).clamp(0.58, 0.98),
        },
      ];
    }
  }

  // Fallback: crop to the camera scanner framing guide (8% horizontal, 7% vertical inset)
  return const [
    {'dx': 0.08, 'dy': 0.07},
    {'dx': 0.92, 'dy': 0.07},
    {'dx': 0.92, 'dy': 0.93},
    {'dx': 0.08, 'dy': 0.93},
  ];
}

Map<String, double> _analyzeQualityIsolate(String imagePath) {
  final bytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {'brightness': 0.55, 'sharpness': 15.0};
  }

  final sample = img.copyResize(decoded, width: 160, height: 160);
  var totalLuma = 0.0;
  var totalGradient = 0.0;
  var count = 0;

  for (var y = 1; y < sample.height - 1; y++) {
    for (var x = 1; x < sample.width - 1; x++) {
      final luma = sample.getPixel(x, y).luminanceNormalized;
      final gx =
          (sample.getPixel(x + 1, y).luminanceNormalized -
                  sample.getPixel(x - 1, y).luminanceNormalized)
              .abs();
      final gy =
          (sample.getPixel(x, y + 1).luminanceNormalized -
                  sample.getPixel(x, y - 1).luminanceNormalized)
              .abs();
      totalLuma += luma;
      totalGradient += (gx + gy) * 100.0;
      count++;
    }
  }

  if (count == 0) {
    return {'brightness': 0.55, 'sharpness': 15.0};
  }

  return {
    'brightness': totalLuma / count,
    'sharpness': totalGradient / count,
  };
}

/// Riverpod provider for [ImageProcessingService].
final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return const ImageProcessingService();
});
