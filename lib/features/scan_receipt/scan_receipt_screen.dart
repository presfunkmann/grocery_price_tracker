import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/ocr_service.dart';
import '../../core/services/receipt_parser_service.dart';
import '../../providers/database_provider.dart';
import 'review_items_screen.dart';

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final ReceiptParserService _parserService = ReceiptParserService();

  bool _isProcessing = false;
  String _statusMessage = '';
  File? _selectedImage;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (image == null) return;

      setState(() {
        _selectedImage = File(image.path);
        _isProcessing = true;
        _statusMessage = 'Processing image...';
      });

      await _processReceipt(File(image.path));
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _processReceipt(File imageFile) async {
    // Step 1: OCR
    setState(() {
      _statusMessage = 'Extracting text from receipt...';
    });

    final ocrResult = await _ocrService.processImage(imageFile);

    if (!ocrResult.success) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'OCR failed: ${ocrResult.error}';
      });
      return;
    }

    if (ocrResult.fullText.isEmpty) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'No text found in image. Try a clearer photo.';
      });
      return;
    }

    // Step 2: Check for API key
    final hasKey = await _parserService.hasApiKey();
    if (!hasKey) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        _showApiKeyDialog(ocrResult.fullText, imageFile.path);
      }
      return;
    }

    // Step 3: Parse with Claude
    setState(() {
      _statusMessage = 'Parsing receipt with AI...';
    });

    final db = ref.read(databaseProvider);
    final products = await db.getAllProducts();
    final brands = await db.getDistinctBrands();
    final variants = await db.getDistinctVariants();

    final parsedReceipt = await _parserService.parseReceipt(
      ocrText: ocrResult.fullText,
      existingProducts: products,
      existingBrands: brands,
      existingVariants: variants,
    );

    setState(() {
      _isProcessing = false;
    });

    if (!parsedReceipt.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parsedReceipt.error ?? 'Parsing failed')),
        );
      }
      return;
    }

    // Step 4: Navigate to review screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReviewItemsScreen(
            parsedReceipt: parsedReceipt,
            receiptImagePath: imageFile.path,
            rawOcrText: ocrResult.fullText,
          ),
        ),
      );
    }
  }

  void _showApiKeyDialog(String ocrText, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
          'To parse receipts with AI, you need to add your Claude API key in Settings.\n\n'
          'Would you like to go to Settings now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
              // User should navigate to Settings tab
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isProcessing
                ? _buildProcessingView()
                : _selectedImage != null
                    ? _buildImagePreview()
                    : _buildPlaceholder(),
          ),
          if (!_isProcessing) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 100,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Take a photo or select an image\nof your receipt',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
