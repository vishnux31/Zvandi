import 'enums.dart';

/// A single logged maintenance/service action (the service history).
class ServiceRecord {
  final String id;
  final String bikeId;

  /// Optional link to the recurring [MaintenanceItem] this record fulfils.
  final String? itemId;
  final ServiceType type;
  final DateTime date;
  final double odometerKm;
  final double? cost;
  final String? notes;
  final DateTime createdAt;

  const ServiceRecord({
    required this.id,
    required this.bikeId,
    this.itemId,
    required this.type,
    required this.date,
    required this.odometerKm,
    this.cost,
    this.notes,
    required this.createdAt,
  });

  ServiceRecord copyWith({
    String? itemId,
    bool clearItemId = false,
    ServiceType? type,
    DateTime? date,
    double? odometerKm,
    double? cost,
    bool clearCost = false,
    String? notes,
  }) {
    return ServiceRecord(
      id: id,
      bikeId: bikeId,
      itemId: clearItemId ? null : (itemId ?? this.itemId),
      type: type ?? this.type,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      cost: clearCost ? null : (cost ?? this.cost),
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'bikeId': bikeId,
        'itemId': itemId,
        'type': type.name,
        'date': date.toIso8601String(),
        'odometerKm': odometerKm,
        'cost': cost,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) => ServiceRecord(
        id: map['id'] as String,
        bikeId: map['bikeId'] as String,
        itemId: map['itemId'] as String?,
        type: ServiceType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => ServiceType.other,
        ),
        date: DateTime.parse(map['date'] as String),
        odometerKm: (map['odometerKm'] as num?)?.toDouble() ?? 0,
        cost: (map['cost'] as num?)?.toDouble(),
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
