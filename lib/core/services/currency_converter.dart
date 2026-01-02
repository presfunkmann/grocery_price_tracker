/// Supported currencies
enum Currency {
  MXN('MXN', '\$', 'Mexican Peso'),
  USD('USD', 'US\$', 'US Dollar');

  final String code;
  final String symbol;
  final String name;

  const Currency(this.code, this.symbol, this.name);

  static Currency? fromCode(String code) {
    for (final c in Currency.values) {
      if (c.code == code.toUpperCase()) {
        return c;
      }
    }
    return null;
  }
}

/// Currency converter using a stored exchange rate
class CurrencyConverter {
  final double mxnToUsdRate;

  const CurrencyConverter({required this.mxnToUsdRate});

  /// Convert amount from one currency to another
  double convert(double amount, Currency from, Currency to) {
    if (from == to) return amount;

    if (from == Currency.MXN && to == Currency.USD) {
      return amount * mxnToUsdRate;
    } else if (from == Currency.USD && to == Currency.MXN) {
      return amount / mxnToUsdRate;
    }

    return amount;
  }

  /// Format price with currency symbol
  String format(double amount, Currency currency, {int decimals = 2}) {
    return '${currency.symbol}${amount.toStringAsFixed(decimals)}';
  }

  /// Format price per unit (e.g., "$45.00/kg")
  String formatPricePerUnit(
    double pricePerUnit,
    Currency currency,
    String unit, {
    int decimals = 2,
  }) {
    return '${format(pricePerUnit, currency, decimals: decimals)}/$unit';
  }
}
