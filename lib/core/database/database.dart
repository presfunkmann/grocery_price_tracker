import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Products, Stores, Purchases, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Add variant and brand columns to purchases
            await m.addColumn(purchases, purchases.variant);
            await m.addColumn(purchases, purchases.brand);
          }
        },
      );

  // Product operations
  Future<List<Product>> getAllProducts() => select(products).get();

  Stream<List<Product>> watchAllProducts() => select(products).watch();

  Future<Product> getProductById(int id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingle();

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  Future<bool> updateProduct(Product product) => update(products).replace(product);

  Future<int> deleteProduct(int id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  // Store operations
  Future<List<Store>> getAllStores() => select(stores).get();

  Stream<List<Store>> watchAllStores() => select(stores).watch();

  Future<int> insertStore(StoresCompanion store) => into(stores).insert(store);

  // Purchase operations
  Future<List<Purchase>> getAllPurchases() => select(purchases).get();

  Stream<List<Purchase>> watchAllPurchases() => select(purchases).watch();

  Future<List<Purchase>> getPurchasesForProduct(int productId) =>
      (select(purchases)..where((p) => p.productId.equals(productId))).get();

  Stream<List<Purchase>> watchPurchasesForProduct(int productId) =>
      (select(purchases)
            ..where((p) => p.productId.equals(productId))
            ..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)]))
          .watch();

  Future<int> insertPurchase(PurchasesCompanion purchase) =>
      into(purchases).insert(purchase);

  Future<bool> updatePurchase(Purchase purchase) =>
      update(purchases).replace(purchase);

  Future<int> deletePurchase(int id) =>
      (delete(purchases)..where((p) => p.id.equals(id))).go();

  // Get distinct variants for autocomplete
  Future<List<String>> getDistinctVariants() async {
    final allPurchases = await getAllPurchases();
    final variants = allPurchases
        .map((p) => p.variant)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    variants.sort();
    return variants;
  }

  // Get distinct brands for autocomplete
  Future<List<String>> getDistinctBrands() async {
    final allPurchases = await getAllPurchases();
    final brands = allPurchases
        .map((p) => p.brand)
        .where((b) => b != null && b.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    brands.sort();
    return brands;
  }

  // Get distinct brands for a specific product
  Future<List<String>> getBrandsForProduct(int productId) async {
    final productPurchases = await getPurchasesForProduct(productId);
    final brands = productPurchases
        .map((p) => p.brand)
        .where((b) => b != null && b.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    brands.sort();
    return brands;
  }

  // Get distinct variants for a specific product
  Future<List<String>> getVariantsForProduct(int productId) async {
    final productPurchases = await getPurchasesForProduct(productId);
    final variants = productPurchases
        .map((p) => p.variant)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    variants.sort();
    return variants;
  }

  // Get latest purchase for each product (for dashboard)
  Future<List<Purchase>> getLatestPurchasePerProduct() async {
    final allPurchases = await getAllPurchases();
    final Map<int, Purchase> latestByProduct = {};

    for (final purchase in allPurchases) {
      final existing = latestByProduct[purchase.productId];
      if (existing == null ||
          purchase.purchaseDate.isAfter(existing.purchaseDate)) {
        latestByProduct[purchase.productId] = purchase;
      }
    }

    return latestByProduct.values.toList();
  }

  // Settings operations
  Future<String?> getSetting(String key) async {
    final result = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  // Get exchange rate (MXN to USD)
  Future<double> getExchangeRate() async {
    final rate = await getSetting('exchange_rate_mxn_usd');
    return rate != null ? double.tryParse(rate) ?? 0.05 : 0.05; // Default ~20 MXN = 1 USD
  }

  Future<void> setExchangeRate(double rate) async {
    await setSetting('exchange_rate_mxn_usd', rate.toString());
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'grocery_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
