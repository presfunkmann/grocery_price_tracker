/// Unit types for categorizing units
enum UnitType { weight, volume, count }

/// Represents a unit of measurement
class UnitInfo {
  final String symbol;
  final String name;
  final UnitType type;
  final double toBaseMultiplier; // Multiplier to convert to base unit (kg for weight, L for volume)

  const UnitInfo({
    required this.symbol,
    required this.name,
    required this.type,
    required this.toBaseMultiplier,
  });
}

/// Unit converter for weight, volume, and count units
class UnitConverter {
  // Weight units (base: kg)
  static const kg = UnitInfo(symbol: 'kg', name: 'Kilogram', type: UnitType.weight, toBaseMultiplier: 1.0);
  static const g = UnitInfo(symbol: 'g', name: 'Gram', type: UnitType.weight, toBaseMultiplier: 0.001);
  static const lb = UnitInfo(symbol: 'lb', name: 'Pound', type: UnitType.weight, toBaseMultiplier: 0.453592);
  static const oz = UnitInfo(symbol: 'oz', name: 'Ounce', type: UnitType.weight, toBaseMultiplier: 0.0283495);

  // Volume units (base: L)
  static const L = UnitInfo(symbol: 'L', name: 'Liter', type: UnitType.volume, toBaseMultiplier: 1.0);
  static const mL = UnitInfo(symbol: 'mL', name: 'Milliliter', type: UnitType.volume, toBaseMultiplier: 0.001);
  static const gal = UnitInfo(symbol: 'gal', name: 'Gallon', type: UnitType.volume, toBaseMultiplier: 3.78541);
  static const flOz = UnitInfo(symbol: 'fl oz', name: 'Fluid Ounce', type: UnitType.volume, toBaseMultiplier: 0.0295735);

  // Count units (base: unit)
  static const unit = UnitInfo(symbol: 'unit', name: 'Unit', type: UnitType.count, toBaseMultiplier: 1.0);
  static const dozen = UnitInfo(symbol: 'dozen', name: 'Dozen', type: UnitType.count, toBaseMultiplier: 12.0);

  static const List<UnitInfo> allUnits = [kg, g, lb, oz, L, mL, gal, flOz, unit, dozen];

  static const List<UnitInfo> weightUnits = [kg, g, lb, oz];
  static const List<UnitInfo> volumeUnits = [L, mL, gal, flOz];
  static const List<UnitInfo> countUnits = [unit, dozen];

  /// Get UnitInfo by symbol
  static UnitInfo? getUnit(String symbol) {
    final lowerSymbol = symbol.toLowerCase();
    for (final u in allUnits) {
      if (u.symbol.toLowerCase() == lowerSymbol) {
        return u;
      }
    }
    return null;
  }

  /// Convert a value from one unit to another
  /// Returns null if units are incompatible (e.g., kg to L)
  static double? convert(double value, String fromUnit, String toUnit) {
    final from = getUnit(fromUnit);
    final to = getUnit(toUnit);

    if (from == null || to == null) return null;
    if (from.type != to.type) return null;

    // Convert to base unit, then to target unit
    final baseValue = value * from.toBaseMultiplier;
    return baseValue / to.toBaseMultiplier;
  }

  /// Convert price per unit to another unit
  /// e.g., $10/kg to $/lb
  static double? convertPricePerUnit(
    double pricePerUnit,
    String fromUnit,
    String toUnit,
  ) {
    final from = getUnit(fromUnit);
    final to = getUnit(toUnit);

    if (from == null || to == null) return null;
    if (from.type != to.type) return null;

    // Price per smaller unit is higher
    // e.g., $10/kg = $4.54/lb (because 1 lb < 1 kg)
    return pricePerUnit * (to.toBaseMultiplier / from.toBaseMultiplier);
  }

  /// Get compatible units for a given unit
  static List<UnitInfo> getCompatibleUnits(String unitSymbol) {
    final u = getUnit(unitSymbol);
    if (u == null) return [];

    switch (u.type) {
      case UnitType.weight:
        return weightUnits;
      case UnitType.volume:
        return volumeUnits;
      case UnitType.count:
        return countUnits;
    }
  }
}
