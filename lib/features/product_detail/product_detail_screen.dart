import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/services/currency_converter.dart';
import '../../core/services/unit_converter.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../add_purchase/add_purchase_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _selectedVariantFilter;
  String? _selectedBrandFilter;
  bool _showComparison = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final settings = ref.watch(displaySettingsProvider);
    final purchasesAsync = ref.watch(productPurchasesProvider(widget.productId));

    return FutureBuilder<Product>(
      future: db.getProductById(widget.productId),
      builder: (context, productSnapshot) {
        if (!productSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final product = productSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              TextButton.icon(
                onPressed: () {
                  ref.read(displaySettingsProvider.notifier).toggleCurrency();
                },
                icon: const Icon(Icons.currency_exchange),
                label: Text(settings.displayCurrency.code),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(displaySettingsProvider.notifier).toggleWeightUnit();
                },
                icon: const Icon(Icons.scale),
                label: Text(settings.displayWeightUnit),
              ),
            ],
          ),
          body: purchasesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (purchases) {
              if (purchases.isEmpty) {
                return const Center(
                  child: Text('No purchases recorded yet'),
                );
              }
              return _buildContent(context, product, purchases, settings);
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AddPurchaseScreen(preselectedProductId: widget.productId),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Purchase'),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Product product,
    List<Purchase> purchases,
    DisplaySettings settings,
  ) {
    final converter = settings.currencyConverter;
    final targetUnit = _getTargetUnit(product.defaultUnit, settings);
    final targetCurrency = settings.displayCurrency;

    // Get unique variants and brands
    final variants = purchases
        .map((p) => p.variant)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    final brands = purchases
        .map((p) => p.brand)
        .where((b) => b != null && b.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    // Filter purchases based on selected filters
    var filteredPurchases = purchases;
    if (_selectedVariantFilter != null) {
      filteredPurchases = filteredPurchases
          .where((p) => p.variant == _selectedVariantFilter)
          .toList();
    }
    if (_selectedBrandFilter != null) {
      filteredPurchases = filteredPurchases
          .where((p) => p.brand == _selectedBrandFilter)
          .toList();
    }

    // Calculate stats for filtered purchases
    if (filteredPurchases.isEmpty) {
      return _buildFiltersAndEmpty(variants, brands);
    }

    final convertedPrices = filteredPurchases.map((p) {
      return _convertPrice(p, targetCurrency, targetUnit, converter);
    }).toList();

    final minPrice = convertedPrices.reduce((a, b) => a < b ? a : b);
    final maxPrice = convertedPrices.reduce((a, b) => a > b ? a : b);
    final avgPrice =
        convertedPrices.reduce((a, b) => a + b) / convertedPrices.length;
    final latestPrice = convertedPrices.first;

    final isDeal = latestPrice < avgPrice * 0.95;
    final isExpensive = latestPrice > avgPrice * 1.05;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Filters
        if (variants.isNotEmpty || brands.isNotEmpty) ...[
          _buildFilterSection(variants, brands),
          const Divider(),
        ],

        // Stats Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Latest',
                  value: converter.formatPricePerUnit(
                    latestPrice,
                    targetCurrency,
                    targetUnit,
                  ),
                  color: isDeal
                      ? Colors.green
                      : isExpensive
                          ? Colors.red
                          : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Average',
                  value: converter.formatPricePerUnit(
                    avgPrice,
                    targetCurrency,
                    targetUnit,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Min',
                  value: converter.formatPricePerUnit(
                    minPrice,
                    targetCurrency,
                    targetUnit,
                  ),
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Max',
                  value: converter.formatPricePerUnit(
                    maxPrice,
                    targetCurrency,
                    targetUnit,
                  ),
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),

        // Comparison toggle (when variants exist)
        if (variants.length > 1) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Price History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showComparison = !_showComparison;
                      if (_showComparison) {
                        _selectedVariantFilter = null;
                      }
                    });
                  },
                  icon: Icon(_showComparison
                      ? Icons.show_chart
                      : Icons.compare_arrows),
                  label:
                      Text(_showComparison ? 'Single View' : 'Compare Variants'),
                ),
              ],
            ),
          ),
        ] else if (filteredPurchases.length > 1) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Price History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],

        // Price Chart
        if (filteredPurchases.length > 1 || _showComparison) ...[
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _showComparison && variants.length > 1
                  ? _ComparisonChart(
                      purchases: purchases,
                      variants: variants,
                      targetCurrency: targetCurrency,
                      targetUnit: targetUnit,
                      converter: converter,
                    )
                  : _PriceChart(
                      purchases: filteredPurchases,
                      targetCurrency: targetCurrency,
                      targetUnit: targetUnit,
                      converter: converter,
                    ),
            ),
          ),
        ],

        // Purchase History
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Purchase History (${filteredPurchases.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...filteredPurchases.map((purchase) {
          final displayPrice = _convertPrice(
            purchase,
            targetCurrency,
            targetUnit,
            converter,
          );

          // Build subtitle with variant and brand
          final subtitleParts = <String>[
            DateFormat.yMMMd().format(purchase.purchaseDate),
          ];
          if (purchase.variant != null && purchase.variant!.isNotEmpty) {
            subtitleParts.add(purchase.variant!);
          }
          if (purchase.brand != null && purchase.brand!.isNotEmpty) {
            subtitleParts.add(purchase.brand!);
          }
          subtitleParts.add(
            '${purchase.quantity} ${purchase.unit} for '
            '${Currency.fromCode(purchase.currency)?.symbol ?? '\$'}${purchase.price.toStringAsFixed(2)}',
          );

          return Dismissible(
            key: Key('purchase_${purchase.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Purchase?'),
                  content: const Text(
                    'This will permanently remove this purchase from your history.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (direction) async {
              final db = ref.read(databaseProvider);
              await db.deletePurchase(purchase.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase deleted')),
                );
              }
            },
            child: ListTile(
              title: Text(
                converter.formatPricePerUnit(
                  displayPrice,
                  targetCurrency,
                  targetUnit,
                ),
              ),
              subtitle: Text(subtitleParts.join(' • ')),
              trailing: displayPrice < avgPrice
                  ? const Icon(Icons.thumb_up, color: Colors.green, size: 20)
                  : displayPrice > avgPrice * 1.1
                      ? const Icon(Icons.thumb_down, color: Colors.red, size: 20)
                      : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFiltersAndEmpty(List<String> variants, List<String> brands) {
    return Column(
      children: [
        _buildFilterSection(variants, brands),
        const Expanded(
          child: Center(
            child: Text('No purchases match the current filters'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection(List<String> variants, List<String> brands) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (variants.isNotEmpty) ...[
            Text(
              'Filter by Variant',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedVariantFilter == null && !_showComparison,
                  onSelected: (selected) {
                    setState(() {
                      _selectedVariantFilter = null;
                      _showComparison = false;
                    });
                  },
                ),
                ...variants.map((variant) => FilterChip(
                      label: Text(variant),
                      selected: _selectedVariantFilter == variant,
                      onSelected: (selected) {
                        setState(() {
                          _selectedVariantFilter = selected ? variant : null;
                          _showComparison = false;
                        });
                      },
                    )),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (brands.isNotEmpty) ...[
            Text(
              'Filter by Brand',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedBrandFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedBrandFilter = null;
                    });
                  },
                ),
                ...brands.map((brand) => FilterChip(
                      label: Text(brand),
                      selected: _selectedBrandFilter == brand,
                      onSelected: (selected) {
                        setState(() {
                          _selectedBrandFilter = selected ? brand : null;
                        });
                      },
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getTargetUnit(String defaultUnit, DisplaySettings settings) {
    final unitInfo = UnitConverter.getUnit(defaultUnit);
    if (unitInfo == null) return defaultUnit;

    switch (unitInfo.type) {
      case UnitType.weight:
        return settings.displayWeightUnit;
      case UnitType.volume:
        return settings.displayVolumeUnit;
      case UnitType.count:
        return defaultUnit;
    }
  }

  double _convertPrice(
    Purchase purchase,
    Currency targetCurrency,
    String targetUnit,
    CurrencyConverter currencyConverter,
  ) {
    var price = purchase.pricePerUnit;

    final sourceCurrency = Currency.fromCode(purchase.currency);
    if (sourceCurrency != null && sourceCurrency != targetCurrency) {
      price = currencyConverter.convert(price, sourceCurrency, targetCurrency);
    }

    if (purchase.unit != targetUnit) {
      final converted = UnitConverter.convertPricePerUnit(
        price,
        purchase.unit,
        targetUnit,
      );
      if (converted != null) {
        price = converted;
      }
    }

    return price;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChart extends StatelessWidget {
  final List<Purchase> purchases;
  final Currency targetCurrency;
  final String targetUnit;
  final CurrencyConverter converter;

  const _PriceChart({
    required this.purchases,
    required this.targetCurrency,
    required this.targetUnit,
    required this.converter,
  });

  @override
  Widget build(BuildContext context) {
    final sortedPurchases = [...purchases]
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    final spots = <FlSpot>[];
    for (var i = 0; i < sortedPurchases.length; i++) {
      final purchase = sortedPurchases[i];
      var price = purchase.pricePerUnit;

      final sourceCurrency = Currency.fromCode(purchase.currency);
      if (sourceCurrency != null && sourceCurrency != targetCurrency) {
        price = converter.convert(price, sourceCurrency, targetCurrency);
      }

      if (purchase.unit != targetUnit) {
        final converted = UnitConverter.convertPricePerUnit(
          price,
          purchase.unit,
          targetUnit,
        );
        if (converted != null) {
          price = converted;
        }
      }

      spots.add(FlSpot(i.toDouble(), price));
    }

    if (spots.isEmpty) {
      return const Center(child: Text('Not enough data for chart'));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${targetCurrency.symbol}${value.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedPurchases.length) {
                  return Text(
                    DateFormat.MMMd()
                        .format(sortedPurchases[index].purchaseDate),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withAlpha(25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comparison chart showing multiple variants as separate lines
class _ComparisonChart extends StatelessWidget {
  final List<Purchase> purchases;
  final List<String> variants;
  final Currency targetCurrency;
  final String targetUnit;
  final CurrencyConverter converter;

  const _ComparisonChart({
    required this.purchases,
    required this.variants,
    required this.targetCurrency,
    required this.targetUnit,
    required this.converter,
  });

  static const List<Color> _lineColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    final lineBarsData = <LineChartBarData>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var vIndex = 0; vIndex < variants.length; vIndex++) {
      final variant = variants[vIndex];
      final variantPurchases = purchases
          .where((p) => p.variant == variant)
          .toList()
        ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

      if (variantPurchases.isEmpty) continue;

      final spots = <FlSpot>[];
      for (var i = 0; i < variantPurchases.length; i++) {
        final purchase = variantPurchases[i];
        var price = purchase.pricePerUnit;

        final sourceCurrency = Currency.fromCode(purchase.currency);
        if (sourceCurrency != null && sourceCurrency != targetCurrency) {
          price = converter.convert(price, sourceCurrency, targetCurrency);
        }

        if (purchase.unit != targetUnit) {
          final converted = UnitConverter.convertPricePerUnit(
            price,
            purchase.unit,
            targetUnit,
          );
          if (converted != null) {
            price = converted;
          }
        }

        spots.add(FlSpot(i.toDouble(), price));
        if (price < minY) minY = price;
        if (price > maxY) maxY = price;
      }

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: _lineColors[vIndex % _lineColors.length],
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );
    }

    if (lineBarsData.isEmpty) {
      return const Center(child: Text('Not enough data for comparison'));
    }

    minY *= 0.9;
    maxY *= 1.1;

    return Column(
      children: [
        // Legend
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 16,
            children: [
              for (var i = 0; i < variants.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _lineColors[i % _lineColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      variants[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${targetCurrency.symbol}${value.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBarsData,
            ),
          ),
        ),
      ],
    );
  }
}
