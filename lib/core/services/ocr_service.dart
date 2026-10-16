import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:scanpro/core/errors/app_exception.dart';

/// On-device OCR service powered by Google ML Kit Text Recognition.
///
/// Works offline once the model is initialized on the Android device and never
/// transmits document text to external servers.
class OcrService {
  OcrService();

  TextRecognizer? _recognizer;

  TextRecognizer _getRecognizer() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Extracts text from the image at [imagePath].
  Future<String> extractTextFromImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const OcrProcessingException(
        userMessage: 'Scanned page image file could not be found for OCR.',
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _getRecognizer().processImage(inputImage);
      return recognizedText.text.trim();
    } catch (e) {
      throw OcrProcessingException(
        userMessage:
            'Could not extract text from this image. Ensure the document is well-lit and in focus.',
        cause: e,
      );
    }
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// Riverpod provider for [OcrService].
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

