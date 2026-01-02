import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';

/// Global database instance provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Stream of all products
final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllProducts();
});

/// Stream of all stores
final storesStreamProvider = StreamProvider<List<Store>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllStores();
});

/// Stream of all purchases
final purchasesStreamProvider = StreamProvider<List<Purchase>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllPurchases();
});

/// Stream of purchases for a specific product
final productPurchasesProvider =
    StreamProvider.family<List<Purchase>, int>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return db.watchPurchasesForProduct(productId);
});

/// Get exchange rate
final exchangeRateProvider = FutureProvider<double>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getExchangeRate();
});
