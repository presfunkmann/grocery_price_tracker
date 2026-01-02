import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/services/currency_converter.dart';
import '../../core/services/unit_converter.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../add_purchase/add_purchase_screen.dart';
import '../product_detail/product_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final purchasesAsync = ref.watch(purchasesStreamProvider);
    final settings = ref.watch(displaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Tracker'),
        actions: [
          // Currency toggle
          TextButton.icon(
            onPressed: () {
              ref.read(displaySettingsProvider.notifier).toggleCurrency();
            },
            icon: const Icon(Icons.currency_exchange),
            label: Text(settings.displayCurrency.code),
          ),
          // Unit toggle
          TextButton.icon(
            onPressed: () {
              ref.read(displaySettingsProvider.notifier).toggleWeightUnit();
            },
            icon: const Icon(Icons.scale),
            label: Text(settings.displayWeightUnit),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No products tracked yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add your first purchase',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return purchasesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (purchases) {
              return _buildProductList(
                context,
                ref,
                products,
                purchases,
                settings,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddPurchaseScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Purchase'),
      ),
    );
  }

  Widget _buildProductList(
    BuildContext context,
    WidgetRef ref,
    List<Product> products,
    List<Purchase> purchases,
    DisplaySettings settings,
  ) {
    // Group purchases by product and get latest for each
    final latestPurchaseByProduct = <int, Purchase>{};
    final allPurchasesByProduct = <int, List<Purchase>>{};

    for (final purchase in purchases) {
      allPurchasesByProduct.putIfAbsent(purchase.productId, () => []);
      allPurchasesByProduct[purchase.productId]!.add(purchase);

      final existing = latestPurchaseByProduct[purchase.productId];
      if (existing == null ||
          purchase.purchaseDate.isAfter(existing.purchaseDate)) {
        latestPurchaseByProduct[purchase.productId] = purchase;
      }
    }

    // Sort products by most recent purchase
    final sortedProducts = [...products];
    sortedProducts.sort((a, b) {
      final aLatest = latestPurchaseByProduct[a.id];
      final bLatest = latestPurchaseByProduct[b.id];
      if (aLatest == null && bLatest == null) return 0;
      if (aLatest == null) return 1;
      if (bLatest == null) return -1;
      return bLatest.purchaseDate.compareTo(aLatest.purchaseDate);
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        final product = sortedProducts[index];
        final latestPurchase = latestPurchaseByProduct[product.id];
        final productPurchases = allPurchasesByProduct[product.id] ?? [];

        return _ProductCard(
          product: product,
          latestPurchase: latestPurchase,
          allPurchases: productPurchases,
          settings: settings,
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final Purchase? latestPurchase;
  final List<Purchase> allPurchases;
  final DisplaySettings settings;

  const _ProductCard({
    required this.product,
    required this.latestPurchase,
    required this.allPurchases,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final converter = settings.currencyConverter;
    final targetUnit = _getTargetUnit(product.defaultUnit);

    String priceDisplay = 'No purchases yet';
    Widget? trendIndicator;

    if (latestPurchase != null) {
      // Convert price to display currency and unit
      final displayPrice = _convertPrice(
        latestPurchase!,
        settings.displayCurrency,
        targetUnit,
        converter,
      );
      priceDisplay = converter.formatPricePerUnit(
        displayPrice,
        settings.displayCurrency,
        targetUnit,
      );

      // Calculate average and show trend
      if (allPurchases.length > 1) {
        final avgPrice = _calculateAveragePrice(
          allPurchases,
          settings.displayCurrency,
          targetUnit,
          converter,
        );
        final diff = displayPrice - avgPrice;
        final percentDiff = (diff / avgPrice * 100).abs();

        if (percentDiff > 5) {
          if (diff < 0) {
            trendIndicator = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                Text(
                  '${percentDiff.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            );
          } else {
            trendIndicator = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                Text(
                  '${percentDiff.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            );
          }
        }
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(product.name),
        subtitle: Text(priceDisplay),
        trailing: trendIndicator,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: product.id),
            ),
          );
        },
      ),
    );
  }

  String _getTargetUnit(String defaultUnit) {
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

    // Convert currency if needed
    final sourceCurrency = Currency.fromCode(purchase.currency);
    if (sourceCurrency != null && sourceCurrency != targetCurrency) {
      price = currencyConverter.convert(price, sourceCurrency, targetCurrency);
    }

    // Convert unit if needed
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

  double _calculateAveragePrice(
    List<Purchase> purchases,
    Currency targetCurrency,
    String targetUnit,
    CurrencyConverter currencyConverter,
  ) {
    if (purchases.isEmpty) return 0;

    var total = 0.0;
    for (final p in purchases) {
      total += _convertPrice(p, targetCurrency, targetUnit, currencyConverter);
    }
    return total / purchases.length;
  }
}
