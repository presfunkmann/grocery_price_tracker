import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/receipt_parser_service.dart';
import '../../core/services/unit_converter.dart';
import '../../providers/database_provider.dart';

class ReviewItemsScreen extends ConsumerStatefulWidget {
  final ParsedReceipt parsedReceipt;
  final String receiptImagePath;
  final String rawOcrText;

  const ReviewItemsScreen({
    super.key,
    required this.parsedReceipt,
    required this.receiptImagePath,
    required this.rawOcrText,
  });

  @override
  ConsumerState<ReviewItemsScreen> createState() => _ReviewItemsScreenState();
}

class _ReviewItemsScreenState extends ConsumerState<ReviewItemsScreen> {
  late List<ParsedReceiptItem> _items;
  late String? _storeName;
  DateTime _purchaseDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.parsedReceipt.items);
    _storeName = widget.parsedReceipt.storeName;
  }

  Future<void> _saveSelectedItems() async {
    final selectedItems = _items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final db = ref.read(databaseProvider);
    int savedCount = 0;

    try {
      for (final item in selectedItems) {
        // Get or create product
        int productId;
        if (item.matchedProductId != null) {
          productId = item.matchedProductId!;
        } else {
          // Create new product
          productId = await db.insertProduct(
            ProductsCompanion.insert(
              name: item.productName,
              defaultUnit: item.unit,
            ),
          );
        }

        // Get or create store if we have one
        int? storeId;
        if (_storeName != null && _storeName!.isNotEmpty) {
          final stores = await db.getAllStores();
          final existingStore = stores.where(
            (s) => s.name.toLowerCase() == _storeName!.toLowerCase(),
          );
          if (existingStore.isNotEmpty) {
            storeId = existingStore.first.id;
          } else {
            storeId = await db.insertStore(
              StoresCompanion.insert(name: _storeName!),
            );
          }
        }

        // Calculate price per unit
        final pricePerUnit = item.price / item.quantity;

        // Create purchase
        await db.insertPurchase(
          PurchasesCompanion.insert(
            productId: productId,
            storeId: Value(storeId),
            variant: Value(item.variant),
            brand: Value(item.brand),
            price: item.price,
            currency: item.currency,
            quantity: item.quantity,
            unit: item.unit,
            pricePerUnit: pricePerUnit,
            purchaseDate: _purchaseDate,
          ),
        );

        savedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $savedCount purchases!')),
        );
        // Pop back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _editItem(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditItemSheet(
        item: _items[index],
        onSave: (updatedItem) {
          setState(() {
            _items[index] = updatedItem;
          });
        },
      ),
    );
  }

  void _showReceiptImage() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _DismissibleImageViewer(imagePath: widget.receiptImagePath);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _editStoreName() async {
    final controller = TextEditingController(text: _storeName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Store Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Store name',
            hintText: 'e.g., Costco, Walmart',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _storeName = result.isNotEmpty ? result : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _items.where((item) => item.isSelected).length;
    final totalPrice = _items
        .where((item) => item.isSelected)
        .fold(0.0, (sum, item) => sum + item.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'View receipt image',
            onPressed: _showReceiptImage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Store and date header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _editStoreName,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _storeName ?? 'Unknown Store',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_items.length} items found',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat.MMMd().format(_purchaseDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _purchaseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _purchaseDate = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No items found in receipt'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemTile(item, index);
                    },
                  ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$selectedCount items selected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '\$${totalPrice.toStringAsFixed(2)} ${widget.parsedReceipt.currency ?? 'MXN'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveSelectedItems,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ParsedReceiptItem item, int index) {
    final currencySymbol = item.currency == 'USD' ? '\$' : '\$';

    return ListTile(
      leading: Checkbox(
        value: item.isSelected,
        onChanged: (value) {
          setState(() {
            _items[index] = item.copyWith(isSelected: value ?? true);
          });
        },
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.productName,
              style: TextStyle(
                decoration:
                    item.isSelected ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          Text(
            '$currencySymbol${item.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: item.isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.quantity} ${item.unit} @ $currencySymbol${(item.price / item.quantity).toStringAsFixed(2)}/${item.unit}',
          ),
          if (item.variant != null || item.brand != null)
            Wrap(
              spacing: 8,
              children: [
                if (item.variant != null)
                  Chip(
                    label: Text(item.variant!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
                if (item.brand != null)
                  Chip(
                    label: Text(item.brand!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          if (item.matchedProductId == null)
            Text(
              'New product',
              style: TextStyle(
                color: Theme.of(context).colorScheme.tertiary,
                fontSize: 12,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _editItem(index),
      ),
    );
  }
}

class _EditItemSheet extends ConsumerStatefulWidget {
  final ParsedReceiptItem item;
  final void Function(ParsedReceiptItem) onSave;

  const _EditItemSheet({
    required this.item,
    required this.onSave,
  });

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _brandController;
  String _selectedUnit = 'kg';
  String? _selectedVariant;
  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.productName);
    _priceController =
        TextEditingController(text: widget.item.price.toString());
    _quantityController =
        TextEditingController(text: widget.item.quantity.toString());
    _brandController = TextEditingController(text: widget.item.brand ?? '');
    _selectedUnit = widget.item.unit;
    _selectedVariant = widget.item.variant;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Edit Item',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final price = double.tryParse(_priceController.text) ??
                          widget.item.price;
                      final quantity =
                          double.tryParse(_quantityController.text) ??
                              widget.item.quantity;

                      widget.onSave(widget.item.copyWith(
                        productName: _nameController.text,
                        matchedProductId: _selectedProduct?.id,
                        price: price,
                        quantity: quantity,
                        unit: _selectedUnit,
                        variant: _selectedVariant,
                        brand: _brandController.text.isNotEmpty
                            ? _brandController.text
                            : null,
                      ));
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Raw text reference
                  if (widget.item.rawText.isNotEmpty) ...[
                    Text(
                      'Original text:',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.item.rawText,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],

                  // Product name with autocomplete
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e'),
                    data: (products) => Autocomplete<Product>(
                      initialValue: TextEditingValue(text: _nameController.text),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Product>.empty();
                        }
                        return products.where((p) => p.name
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (product) => product.name,
                      onSelected: (product) {
                        setState(() {
                          _selectedProduct = product;
                          _nameController.text = product.name;
                          _selectedUnit = product.defaultUnit;
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Product name',
                            border: const OutlineInputBorder(),
                            suffixIcon: _selectedProduct != null
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                          ),
                          onChanged: (value) {
                            _nameController.text = value;
                            // Check for exact match
                            final match = products.where(
                              (p) => p.name.toLowerCase() == value.toLowerCase(),
                            );
                            if (match.isNotEmpty) {
                              setState(() {
                                _selectedProduct = match.first;
                              });
                            } else {
                              setState(() {
                                _selectedProduct = null;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price and quantity row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Unit dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: UnitConverter.allUnits
                        .map((u) => DropdownMenuItem(
                              value: u.symbol,
                              child: Text(u.symbol),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value ?? 'kg';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Variant chips
                  Text(
                    'Variant',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Regular',
                      'Organic',
                      'Free-range',
                      'Grass-fed',
                    ].map((variant) {
                      return ChoiceChip(
                        label: Text(variant),
                        selected: _selectedVariant == variant,
                        onSelected: (selected) {
                          setState(() {
                            _selectedVariant = selected ? variant : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Brand
                  TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(
                      labelText: 'Brand (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissibleImageViewer extends StatefulWidget {
  final String imagePath;

  const _DismissibleImageViewer({required this.imagePath});

  @override
  State<_DismissibleImageViewer> createState() => _DismissibleImageViewerState();
}

class _DismissibleImageViewerState extends State<_DismissibleImageViewer> {
  double _dragOffset = 0;
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dy;
          // Fade out as user drags down
          _opacity = (1 - (_dragOffset.abs() / 300)).clamp(0.5, 1.0);
        });
      },
      onVerticalDragEnd: (details) {
        // If dragged more than 100 pixels or with enough velocity, dismiss
        if (_dragOffset.abs() > 100 ||
            details.velocity.pixelsPerSecond.dy.abs() > 500) {
          Navigator.of(context).pop();
        } else {
          // Reset position
          setState(() {
            _dragOffset = 0;
            _opacity = 1.0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(_opacity),
        body: Stack(
          children: [
            // Tap anywhere to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            // The image
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Hint text at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: _opacity,
                child: const Text(
                  'Swipe down or tap to close',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
