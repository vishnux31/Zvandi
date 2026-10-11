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
  final String? provider;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRecord({
    required this.id,
    required this.bikeId,
    this.itemId,
    required this.type,
    required this.date,
    required this.odometerKm,
    this.cost,
    this.notes,
    this.provider,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  ServiceRecord copyWith({
    String? itemId,
    bool clearItemId = false,
    ServiceType? type,
    DateTime? date,
    double? odometerKm,
    double? cost,
    bool clearCost = false,
    String? notes,
    String? provider,
    bool clearProvider = false,
    DateTime? updatedAt,
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
      provider: clearProvider ? null : (provider ?? this.provider),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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
        'provider': provider,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.parse(map['createdAt'] as String);
    final rawNotes = map['notes'] as String?;
    final rawProvider = map['provider'] as String?;

    // Legacy migration: older rows stored provider inline in the notes as
    // "Provider: X\n{notes}". Split on read so new readers see them as
    // separate fields.
    String? migratedProvider = rawProvider;
    String? migratedNotes = rawNotes;
    if (rawProvider == null && rawNotes != null && rawNotes.startsWith('Provider: ')) {
      final newlineIdx = rawNotes.indexOf('\n');
      if (newlineIdx > 0) {
        migratedProvider = rawNotes.substring('Provider: '.length, newlineIdx).trim();
        migratedNotes = rawNotes.substring(newlineIdx + 1).trim();
      } else {
        migratedProvider = rawNotes.substring('Provider: '.length).trim();
        migratedNotes = '';
      }
      if (migratedNotes.isEmpty) migratedNotes = null;
    }

    return ServiceRecord(
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
      notes: migratedNotes,
      provider: migratedProvider,
      createdAt: createdAt,
      updatedAt: map['updatedAt'] == null
          ? createdAt
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}
