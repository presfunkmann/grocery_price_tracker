import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/currency_converter.dart';
import '../../core/services/unit_converter.dart';
import '../../providers/database_provider.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final int? preselectedProductId;

  const AddPurchaseScreen({super.key, this.preselectedProductId});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _storeController = TextEditingController();
  final _brandController = TextEditingController();
  final _notesController = TextEditingController();

  Product? _selectedProduct;
  String? _selectedCategory;
  String? _selectedVariant;
  String _selectedUnit = 'kg';
  Currency _selectedCurrency = Currency.MXN;
  DateTime _purchaseDate = DateTime.now();
  bool _isNewProduct = true;

  List<String> _existingVariants = [];
  List<String> _existingBrands = [];

  final List<String> _defaultVariants = [
    'Regular',
    'Organic',
    'Free-range',
    'Grass-fed',
    'Whole wheat',
    'Gluten-free',
    'Low-fat',
    'Sugar-free',
  ];

  final List<String> _categories = [
    'Meat',
    'Dairy',
    'Produce',
    'Bakery',
    'Frozen',
    'Beverages',
    'Snacks',
    'Pantry',
    'Household',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    if (widget.preselectedProductId != null) {
      _loadPreselectedProduct();
    }
  }

  Future<void> _loadExistingData() async {
    final db = ref.read(databaseProvider);
    final variants = await db.getDistinctVariants();
    final brands = await db.getDistinctBrands();
    setState(() {
      _existingVariants = variants;
      _existingBrands = brands;
    });
  }

  Future<void> _loadPreselectedProduct() async {
    final db = ref.read(databaseProvider);
    final product = await db.getProductById(widget.preselectedProductId!);
    setState(() {
      _selectedProduct = product;
      _productNameController.text = product.name;
      _selectedUnit = product.defaultUnit;
      _selectedCategory = product.category;
      _isNewProduct = false;
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _storeController.dispose();
    _brandController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final storesAsync = ref.watch(storesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Selection
            _buildSectionHeader('Product'),
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
              data: (products) => _buildProductField(products),
            ),
            const SizedBox(height: 16),

            // Category (for new products)
            if (_isNewProduct) ...[
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // Variant (Organic/Regular/etc.)
            _buildSectionHeader('Variant (Optional)'),
            _buildVariantField(),
            const SizedBox(height: 24),

            // Brand
            _buildSectionHeader('Brand (Optional)'),
            _buildBrandField(),
            const SizedBox(height: 24),

            // Price and Currency
            _buildSectionHeader('Price'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Price',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<Currency>(
                    segments: const [
                      ButtonSegment(value: Currency.MXN, label: Text('MXN')),
                      ButtonSegment(value: Currency.USD, label: Text('USD')),
                    ],
                    selected: {_selectedCurrency},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedCurrency = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quantity and Unit
            _buildSectionHeader('Quantity'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter quantity';
                      }
                      final qty = double.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'Invalid quantity';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Store
            _buildSectionHeader('Store (Optional)'),
            storesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error: $e'),
              data: (stores) => Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return stores.map((s) => s.name);
                  }
                  return stores
                      .where((s) => s.name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()))
                      .map((s) => s.name);
                },
                onSelected: (selection) {
                  _storeController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Store name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Costco, Walmart',
                    ),
                    onChanged: (value) {
                      _storeController.text = value;
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Date
            _buildSectionHeader('Date'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat.yMMMd().format(_purchaseDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
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
            const SizedBox(height: 24),

            // Notes
            _buildSectionHeader('Notes (Optional)'),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Any additional info...',
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton.icon(
              onPressed: _savePurchase,
              icon: const Icon(Icons.save),
              label: const Text('Save Purchase'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildProductField(List<Product> products) {
    return Autocomplete<Product>(
      initialValue: _productNameController.text.isNotEmpty
          ? TextEditingValue(text: _productNameController.text)
          : null,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Product>.empty();
        }
        return products.where((p) =>
            p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (product) => product.name,
      onSelected: (product) {
        setState(() {
          _selectedProduct = product;
          _productNameController.text = product.name;
          _selectedUnit = product.defaultUnit;
          _selectedCategory = product.category;
          _isNewProduct = false;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Product name',
            border: const OutlineInputBorder(),
            hintText: 'e.g., Chicken Breast, Fusilli',
            suffixIcon: _selectedProduct != null
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
          ),
          onChanged: (value) {
            _productNameController.text = value;
            // Check if it matches an existing product exactly
            final match = products.where(
              (p) => p.name.toLowerCase() == value.toLowerCase(),
            );
            if (match.isNotEmpty) {
              setState(() {
                _selectedProduct = match.first;
                _selectedUnit = match.first.defaultUnit;
                _selectedCategory = match.first.category;
                _isNewProduct = false;
              });
            } else {
              setState(() {
                _selectedProduct = null;
                _isNewProduct = true;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter product name';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildVariantField() {
    // Combine default variants with any existing ones from the database
    final allVariants = {..._defaultVariants, ..._existingVariants}.toList();
    allVariants.sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...allVariants.map((variant) => ChoiceChip(
              label: Text(variant),
              selected: _selectedVariant == variant,
              onSelected: (selected) {
                setState(() {
                  _selectedVariant = selected ? variant : null;
                });
              },
            )),
        // Option to clear selection
        if (_selectedVariant != null)
          ActionChip(
            label: const Text('Clear'),
            avatar: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _selectedVariant = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildBrandField() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _existingBrands;
        }
        return _existingBrands.where((b) =>
            b.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        _brandController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Brand name',
            border: OutlineInputBorder(),
            hintText: 'e.g., Barilla, Kirkland, Great Value',
          ),
          onChanged: (value) {
            _brandController.text = value;
          },
        );
      },
    );
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(databaseProvider);
    final price = double.parse(_priceController.text);
    final quantity = double.parse(_quantityController.text);
    final pricePerUnit = price / quantity;

    try {
      // Get or create product
      int productId;
      if (_selectedProduct != null) {
        productId = _selectedProduct!.id;
      } else {
        // Create new product
        productId = await db.insertProduct(
          ProductsCompanion.insert(
            name: _productNameController.text.trim(),
            category: Value(_selectedCategory),
            defaultUnit: _selectedUnit,
          ),
        );
      }

      // Get or create store
      int? storeId;
      if (_storeController.text.isNotEmpty) {
        final stores = await db.getAllStores();
        final existingStore = stores.where(
          (s) => s.name.toLowerCase() == _storeController.text.toLowerCase(),
        );
        if (existingStore.isNotEmpty) {
          storeId = existingStore.first.id;
        } else {
          storeId = await db.insertStore(
            StoresCompanion.insert(name: _storeController.text.trim()),
          );
        }
      }

      // Create purchase
      await db.insertPurchase(
        PurchasesCompanion.insert(
          productId: productId,
          storeId: Value(storeId),
          variant: Value(_selectedVariant),
          brand: Value(_brandController.text.isNotEmpty
              ? _brandController.text.trim()
              : null),
          price: price,
          currency: _selectedCurrency.code,
          quantity: quantity,
          unit: _selectedUnit,
          pricePerUnit: pricePerUnit,
          purchaseDate: _purchaseDate,
          notes: Value(_notesController.text.isNotEmpty
              ? _notesController.text
              : null),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
