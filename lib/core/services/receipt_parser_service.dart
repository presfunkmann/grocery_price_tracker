import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../database/database.dart';

/// A parsed item from a receipt
class ParsedReceiptItem {
  final String rawText;
  final String productName;
  final int? matchedProductId;
  final String? variant;
  final String? brand;
  final double quantity;
  final String unit;
  final double price;
  final String currency;
  bool isSelected;

  ParsedReceiptItem({
    required this.rawText,
    required this.productName,
    this.matchedProductId,
    this.variant,
    this.brand,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.currency,
    this.isSelected = true,
  });

  factory ParsedReceiptItem.fromJson(Map<String, dynamic> json) {
    return ParsedReceiptItem(
      rawText: json['raw_text'] as String? ?? '',
      productName: json['product_name'] as String? ?? 'Unknown Item',
      matchedProductId: json['matched_product_id'] as int?,
      variant: json['variant'] as String?,
      brand: json['brand'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'unit',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'MXN',
    );
  }

  ParsedReceiptItem copyWith({
    String? rawText,
    String? productName,
    int? matchedProductId,
    String? variant,
    String? brand,
    double? quantity,
    String? unit,
    double? price,
    String? currency,
    bool? isSelected,
  }) {
    return ParsedReceiptItem(
      rawText: rawText ?? this.rawText,
      productName: productName ?? this.productName,
      matchedProductId: matchedProductId ?? this.matchedProductId,
      variant: variant ?? this.variant,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Result from parsing a receipt
class ParsedReceipt {
  final String? storeName;
  final List<ParsedReceiptItem> items;
  final double? total;
  final String? currency;
  final bool success;
  final String? error;

  ParsedReceipt({
    this.storeName,
    required this.items,
    this.total,
    this.currency,
    this.success = true,
    this.error,
  });

  factory ParsedReceipt.error(String message) {
    return ParsedReceipt(
      items: [],
      success: false,
      error: message,
    );
  }

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return ParsedReceipt(
      storeName: json['store_name'] as String?,
      items: itemsList
          .map((item) => ParsedReceiptItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }
}

/// Service for parsing receipts using Claude API
class ReceiptParserService {
  static const String _apiKeyStorageKey = 'claude_api_key';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';

  final FlutterSecureStorage _secureStorage;

  ReceiptParserService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final key = await _secureStorage.read(key: _apiKeyStorageKey);
    return key != null && key.isNotEmpty;
  }

  /// Get the stored API key
  Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyStorageKey);
  }

  /// Store the API key
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
  }

  /// Remove the stored API key
  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
  }

  /// Test if the API key is valid
  /// Returns (isValid, errorMessage)
  Future<(bool, String?)> testApiKey(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        }),
      );

      if (response.statusCode == 200) {
        return (true, null);
      } else {
        // Try to get error message from response
        try {
          final body = jsonDecode(response.body);
          final errorMsg = body['error']?['message'] ?? 'Unknown error';
          return (false, 'API error (${response.statusCode}): $errorMsg');
        } catch (_) {
          return (false, 'API error: ${response.statusCode}');
        }
      }
    } catch (e) {
      return (false, 'Network error: $e');
    }
  }

  /// Build compact product context for the prompt
  String _buildProductContext(List<Product> products) {
    if (products.isEmpty) {
      return 'No existing products in database.';
    }

    // Compact format: id|name|category|unit
    final lines = products.map((p) {
      final category = p.category ?? 'Other';
      return '${p.id}|${p.name}|$category|${p.defaultUnit}';
    }).join('\n');

    return 'Existing products (id|name|category|unit):\n$lines';
  }

  /// Build the prompt for Claude
  String _buildPrompt({
    required String ocrText,
    required List<Product> existingProducts,
    required List<String> existingBrands,
    required List<String> existingVariants,
  }) {
    final productContext = _buildProductContext(existingProducts);

    final brandsContext = existingBrands.isNotEmpty
        ? 'Known brands: ${existingBrands.join(', ')}'
        : '';

    final variantsContext = existingVariants.isNotEmpty
        ? 'Known variants: ${existingVariants.join(', ')}'
        : 'Common variants: Organic, Regular, Free-range, Grass-fed, Whole wheat, Gluten-free';

    return '''You are a receipt parser. Extract grocery items from this receipt OCR text.

$productContext

$brandsContext
$variantsContext

RECEIPT TEXT:
$ocrText

Parse each item and return JSON with this exact structure:
{
  "store_name": "Store Name or null",
  "currency": "MXN or USD",
  "items": [
    {
      "raw_text": "original text from receipt",
      "product_name": "Standardized product name in English",
      "matched_product_id": 123 or null if new product,
      "variant": "Organic/Regular/etc or null",
      "brand": "Brand name or null",
      "quantity": 1.5,
      "unit": "kg/lb/L/unit/etc",
      "price": 245.50
    }
  ],
  "total": 1523.40 or null
}

Rules:
1. Match products to existing ones by name similarity (Spanish/English)
2. Extract weight/quantity from item description (e.g., "1.5kg", "2 LB")
3. Detect organic/variant keywords: ORG, ORGANICO, ORGANIC
4. Price is the total for that line item
5. Use "unit" for countable items without weight
6. Standardize names to English (PECHUGA = Chicken Breast)
7. Only return valid JSON, no explanation''';
  }

  /// Parse a receipt using Claude API
  Future<ParsedReceipt> parseReceipt({
    required String ocrText,
    required List<Product> existingProducts,
    required List<String> existingBrands,
    required List<String> existingVariants,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return ParsedReceipt.error('API key not configured. Please add your Claude API key in Settings.');
    }

    try {
      final prompt = _buildPrompt(
        ocrText: ocrText,
        existingProducts: existingProducts,
        existingBrands: existingBrands,
        existingVariants: existingVariants,
      );

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 4096,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        return ParsedReceipt.error('API error: $errorMessage');
      }

      final responseBody = jsonDecode(response.body);
      final content = responseBody['content'] as List<dynamic>;
      if (content.isEmpty) {
        return ParsedReceipt.error('Empty response from API');
      }

      final textContent = content.first['text'] as String;

      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = textContent;
      if (textContent.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(textContent);
        if (match != null) {
          jsonStr = match.group(1)!.trim();
        }
      }

      final parsedJson = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ParsedReceipt.fromJson(parsedJson);
    } catch (e) {
      return ParsedReceipt.error('Failed to parse receipt: $e');
    }
  }
}
