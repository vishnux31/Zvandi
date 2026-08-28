/// A single refuelling record, used to track fuel economy.
class FuelEntry {
  final String id;
  final String bikeId;
  final DateTime date;
  final double odometerKm;
  final double liters;
  final double? cost;

  /// Whether the tank was filled completely (needed for accurate mileage).
  final bool fullTank;
  final String? notes;
  final DateTime createdAt;

  const FuelEntry({
    required this.id,
    required this.bikeId,
    required this.date,
    required this.odometerKm,
    required this.liters,
    this.cost,
    this.fullTank = true,
    this.notes,
    required this.createdAt,
  });

  FuelEntry copyWith({
    DateTime? date,
    double? odometerKm,
    double? liters,
    double? cost,
    bool clearCost = false,
    bool? fullTank,
    String? notes,
  }) {
    return FuelEntry(
      id: id,
      bikeId: bikeId,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      liters: liters ?? this.liters,
      cost: clearCost ? null : (cost ?? this.cost),
      fullTank: fullTank ?? this.fullTank,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'bikeId': bikeId,
        'date': date.toIso8601String(),
        'odometerKm': odometerKm,
        'liters': liters,
        'cost': cost,
        'fullTank': fullTank,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FuelEntry.fromMap(Map<String, dynamic> map) => FuelEntry(
        id: map['id'] as String,
        bikeId: map['bikeId'] as String,
        date: DateTime.parse(map['date'] as String),
        odometerKm: (map['odometerKm'] as num?)?.toDouble() ?? 0,
        liters: (map['liters'] as num?)?.toDouble() ?? 0,
        cost: (map['cost'] as num?)?.toDouble(),
        fullTank: map['fullTank'] as bool? ?? true,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
