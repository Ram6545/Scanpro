import 'dart:convert';
import 'dart:ui';

/// Supported non-destructive scan enhancement filters.
enum ScanFilterType {
  original('Original', 'Preserves natural camera colors'),
  enhancedColor('Magic Color', 'Boosts vibrancy and whitens paper background'),
  grayscale('Grayscale', 'Clean monochrome tones for forms and letters'),
  blackAndWhite('B&W Sharp', 'High-contrast binary threshold for crisp text');

  const ScanFilterType(this.label, this.description);

  final String label;
  final String description;

  static ScanFilterType fromName(String? name) {
    return ScanFilterType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ScanFilterType.original,
    );
  }
}

/// Non-destructive editing parameters stored per scanned page.
class PageEditSettings {
  const PageEditSettings({
    this.rotationQuarterTurns = 0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.filter = ScanFilterType.original,
    this.corners = defaultCorners,
  });

  /// Clockwise 90-degree increments (0, 1, 2, 3).
  final int rotationQuarterTurns;

  /// Brightness offset in range [-0.5, 0.5], where 0.0 is neutral.
  final double brightness;

  /// Contrast multiplier in range [0.5, 2.0], where 1.0 is neutral.
  final double contrast;

  /// Active document filter preset.
  final ScanFilterType filter;

  /// Normalized four-corner coordinates (top-left, top-right, bottom-right, bottom-left)
  /// each in [0.0, 1.0] relative to the uncropped image dimensions.
  final List<Offset> corners;

  static const List<Offset> defaultCorners = [
    Offset(0.0, 0.0),
    Offset(1.0, 0.0),
    Offset(1.0, 1.0),
    Offset(0.0, 1.0),
  ];

  bool get isDefault =>
      rotationQuarterTurns == 0 &&
      brightness == 0.0 &&
      contrast == 1.0 &&
      filter == ScanFilterType.original &&
      _areDefaultCorners(corners);

  static bool _areDefaultCorners(List<Offset> points) {
    if (points.length != 4) return false;
    for (var i = 0; i < 4; i++) {
      if ((points[i].dx - defaultCorners[i].dx).abs() > 0.001 ||
          (points[i].dy - defaultCorners[i].dy).abs() > 0.001) {
        return false;
      }
    }
    return true;
  }

  PageEditSettings copyWith({
    int? rotationQuarterTurns,
    double? brightness,
    double? contrast,
    ScanFilterType? filter,
    List<Offset>? corners,
  }) {
    return PageEditSettings(
      rotationQuarterTurns:
          (rotationQuarterTurns ?? this.rotationQuarterTurns) % 4,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      filter: filter ?? this.filter,
      corners: corners ?? List<Offset>.from(this.corners),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rotationQuarterTurns': rotationQuarterTurns,
      'brightness': brightness,
      'contrast': contrast,
      'filter': filter.name,
      'corners': corners.map((c) => {'dx': c.dx, 'dy': c.dy}).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory PageEditSettings.fromMap(Map<String, dynamic> map) {
    final rawCorners = map['corners'] as List<dynamic>?;
    final parsedCorners = rawCorners != null && rawCorners.length == 4
        ? rawCorners.map((item) {
            final m = item as Map<String, dynamic>;
            return Offset(
              (m['dx'] as num).toDouble(),
              (m['dy'] as num).toDouble(),
            );
          }).toList()
        : defaultCorners;

    return PageEditSettings(
      rotationQuarterTurns: (map['rotationQuarterTurns'] as int? ?? 0) % 4,
      brightness: (map['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (map['contrast'] as num?)?.toDouble() ?? 1.0,
      filter: ScanFilterType.fromName(map['filter'] as String?),
      corners: parsedCorners,
    );
  }

  factory PageEditSettings.fromJson(String? source) {
    if (source == null || source.isEmpty) {
      return const PageEditSettings();
    }
    try {
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      return PageEditSettings.fromMap(decoded);
    } catch (_) {
      return const PageEditSettings();
    }
  }
}

