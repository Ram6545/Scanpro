import 'package:intl/intl.dart';

/// Formatting helpers for file sizes, dates, and safe document filenames.
class FormatUtils {
  FormatUtils._();

  static final DateFormat _shortDateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _fileTimestampFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Formats a byte count into a human-readable string (e.g., `420 KB`, `2.4 MB`).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final formattedNumber = unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 10 ? 1 : 2);
    return '$formattedNumber ${units[unitIndex]}';
  }

  /// Formats a [DateTime] into a short date string (e.g. `Oct 11, 2026`).
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Formats a [DateTime] into a full date and time string.
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Generates a default scan document title based on the current timestamp.
  static String generateDefaultScanTitle([DateTime? now]) {
    final timestamp = _fileTimestampFormat.format(now ?? DateTime.now());
    return 'Scan_$timestamp';
  }

  /// Sanitizes a user-entered document title into a safe filename without path traversal.
  static String sanitizeFileName(String input, {String fallback = 'Document'}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return fallback;
    final sanitized = trimmed
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? fallback : sanitized;
  }
}

