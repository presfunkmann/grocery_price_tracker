import 'package:drift/drift.dart';

/// Products table - items you track (e.g., "Chicken Breast", "Fusilli")
/// Note: Organic/Regular variant is tracked per-purchase, not per-product
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().nullable()();
  TextColumn get defaultUnit =>
      text().withLength(min: 1, max: 20)(); // kg, lb, L, unit, etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stores table - where you shop
class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Purchases table - individual purchase records
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get storeId => integer().nullable().references(Stores, #id)();

  // Product variant and brand
  TextColumn get variant =>
      text().nullable()(); // "Organic", "Regular", "Free-range", etc.
  TextColumn get brand =>
      text().nullable()(); // "Barilla", "De Cecco", "Kirkland", etc.

  // Price and quantity
  RealColumn get price => real()(); // Total price paid
  TextColumn get currency =>
      text().withLength(min: 3, max: 3)(); // MXN, USD, etc.
  RealColumn get quantity => real()(); // Amount purchased
  TextColumn get unit => text().withLength(min: 1, max: 20)(); // kg, lb, etc.
  RealColumn get pricePerUnit => real()(); // Calculated: price / quantity

  // Metadata
  DateTimeColumn get purchaseDate => dateTime()();
  TextColumn get receiptImagePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// App settings - stores exchange rate and preferences
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}
