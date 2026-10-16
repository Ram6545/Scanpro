/// Base class for all typed exceptions in ScanPro.
///
/// Never include raw document text or personal content in exception messages
/// to uphold user privacy.
sealed class AppException implements Exception {
  const AppException({
    required this.userMessage,
    this.code,
    this.cause,
  });

  /// Safe, human-readable message suitable for displaying in the UI.
  final String userMessage;

  /// Optional error code for diagnostics.
  final String? code;

  /// Underlying exception or error object, if any.
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType(code: ${code ?? "NONE"}, message: $userMessage)';
}

/// Thrown when a required runtime permission (Camera, Photos) is denied.
final class PermissionDeniedException extends AppException {
  const PermissionDeniedException({
    required super.userMessage,
    this.isPermanentlyDenied = false,
    super.code = 'PERMISSION_DENIED',
    super.cause,
  });

  final bool isPermanentlyDenied;
}

/// Thrown when app-private file read/write or disk space check fails.
final class StorageException extends AppException {
  const StorageException({
    required super.userMessage,
    super.code = 'STORAGE_ERROR',
    super.cause,
  });
}

/// Thrown when the camera hardware or preview controller encounters an error.
final class CameraScanException extends AppException {
  const CameraScanException({
    required super.userMessage,
    super.code = 'CAMERA_ERROR',
    super.cause,
  });
}

/// Thrown when cropping, perspective transformation, or filter rendering fails.
final class ImageProcessingException extends AppException {
  const ImageProcessingException({
    required super.userMessage,
    super.code = 'IMAGE_PROCESSING_ERROR',
    super.cause,
  });
}

/// Thrown when multi-page PDF creation or preview fails.
final class PdfGenerationException extends AppException {
  const PdfGenerationException({
    required super.userMessage,
    super.code = 'PDF_GENERATION_ERROR',
    super.cause,
  });
}

/// Thrown when on-device OCR text recognition fails.
final class OcrProcessingException extends AppException {
  const OcrProcessingException({
    required super.userMessage,
    super.code = 'OCR_ERROR',
    super.cause,
  });
}

/// Thrown when local metadata persistence fails.
final class DatabaseException extends AppException {
  const DatabaseException({
    required super.userMessage,
    super.code = 'DATABASE_ERROR',
    super.cause,
  });
}

