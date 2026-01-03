import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result from OCR processing
class OcrResult {
  final String fullText;
  final List<OcrTextBlock> blocks;
  final bool success;
  final String? error;

  OcrResult({
    required this.fullText,
    required this.blocks,
    this.success = true,
    this.error,
  });

  factory OcrResult.error(String message) {
    return OcrResult(
      fullText: '',
      blocks: [],
      success: false,
      error: message,
    );
  }
}

/// A block of text with position info
class OcrTextBlock {
  final String text;
  final List<OcrTextLine> lines;

  OcrTextBlock({required this.text, required this.lines});
}

/// A line of text within a block
class OcrTextLine {
  final String text;

  OcrTextLine({required this.text});
}

/// Service for on-device OCR using Google ML Kit
class OcrService {
  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Process an image file and extract text
  Future<OcrResult> processImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return OcrResult.error('Image file does not exist');
      }

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);

      final blocks = recognizedText.blocks.map((block) {
        return OcrTextBlock(
          text: block.text,
          lines: block.lines.map((line) {
            return OcrTextLine(text: line.text);
          }).toList(),
        );
      }).toList();

      return OcrResult(
        fullText: recognizedText.text,
        blocks: blocks,
      );
    } catch (e) {
      return OcrResult.error('OCR processing failed: $e');
    }
  }

  /// Process an image from path
  Future<OcrResult> processImagePath(String path) async {
    return processImage(File(path));
  }

  /// Clean up resources
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}
