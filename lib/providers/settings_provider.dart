import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/services/currency_converter.dart';
import 'database_provider.dart';

/// Display settings state
class DisplaySettings {
  final Currency displayCurrency;
  final String displayWeightUnit; // kg or lb
  final String displayVolumeUnit; // L or gal
  final double exchangeRate;

  const DisplaySettings({
    this.displayCurrency = Currency.MXN,
    this.displayWeightUnit = 'kg',
    this.displayVolumeUnit = 'L',
    this.exchangeRate = 0.05, // ~20 MXN = 1 USD
  });

  DisplaySettings copyWith({
    Currency? displayCurrency,
    String? displayWeightUnit,
    String? displayVolumeUnit,
    double? exchangeRate,
  }) {
    return DisplaySettings(
      displayCurrency: displayCurrency ?? this.displayCurrency,
      displayWeightUnit: displayWeightUnit ?? this.displayWeightUnit,
      displayVolumeUnit: displayVolumeUnit ?? this.displayVolumeUnit,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  CurrencyConverter get currencyConverter =>
      CurrencyConverter(mxnToUsdRate: exchangeRate);
}

/// Display settings notifier
class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  DisplaySettingsNotifier() : super(const DisplaySettings());

  void setCurrency(Currency currency) {
    state = state.copyWith(displayCurrency: currency);
  }

  void toggleCurrency() {
    final newCurrency = state.displayCurrency == Currency.MXN
        ? Currency.USD
        : Currency.MXN;
    state = state.copyWith(displayCurrency: newCurrency);
  }

  void setWeightUnit(String unit) {
    state = state.copyWith(displayWeightUnit: unit);
  }

  void toggleWeightUnit() {
    final newUnit = state.displayWeightUnit == 'kg' ? 'lb' : 'kg';
    state = state.copyWith(displayWeightUnit: newUnit);
  }

  void setVolumeUnit(String unit) {
    state = state.copyWith(displayVolumeUnit: unit);
  }

  void toggleVolumeUnit() {
    final newUnit = state.displayVolumeUnit == 'L' ? 'gal' : 'L';
    state = state.copyWith(displayVolumeUnit: newUnit);
  }

  void setExchangeRate(double rate) {
    state = state.copyWith(exchangeRate: rate);
  }

  Future<void> loadFromDatabase(AppDatabase db) async {
    final rate = await db.getExchangeRate();
    state = state.copyWith(exchangeRate: rate);
  }

  Future<void> saveExchangeRate(AppDatabase db, double rate) async {
    await db.setExchangeRate(rate);
    state = state.copyWith(exchangeRate: rate);
  }
}

/// Display settings provider
final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  final notifier = DisplaySettingsNotifier();
  // Load exchange rate from database on init
  final db = ref.read(databaseProvider);
  notifier.loadFromDatabase(db);
  return notifier;
});
