import '../data/models/enums.dart';

const double _kmPerMile = 1.609344;

/// Helpers to convert between stored km values and the user's chosen unit.
extension DistanceConversion on DistanceUnit {
  /// Convert a stored km value into this unit for display.
  double fromKm(double km) => this == DistanceUnit.km ? km : km / _kmPerMile;

  /// Convert a value entered in this unit back into km for storage.
  double toKm(double value) =>
      this == DistanceUnit.km ? value : value * _kmPerMile;
}

/// Fuel economy helpers (litres consumed over a km distance).
class FuelEconomy {
  /// Kilometres per litre.
  static double kmPerLiter(double distanceKm, double liters) =>
      liters <= 0 ? 0 : distanceKm / liters;

  /// Litres per 100 km.
  static double litersPer100Km(double distanceKm, double liters) =>
      distanceKm <= 0 ? 0 : (liters / distanceKm) * 100;

  /// Miles per (US) gallon.
  static double milesPerGallon(double distanceKm, double liters) {
    if (liters <= 0) return 0;
    final miles = distanceKm / _kmPerMile;
    final gallons = liters / 3.785411784;
    return miles / gallons;
  }
}
