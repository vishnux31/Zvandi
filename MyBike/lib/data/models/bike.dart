import 'enums.dart';

class Bike {
  final String id;
  final String name;
  final String? make;
  final String? model;

  /// Catalog ids backing [make]/[model] when chosen from the brand/model lists.
  final String? brandId;
  final String? modelId;
  final int? year;

  /// Year the bike was purchased by the rider.
  final int? yearOfPurchase;
  final String? registration;
  final BikeType type;

  /// Current odometer reading, always stored in kilometres.
  final double odometerKm;
  final String? photoPath;
  final String? notes;
  final DateTime createdAt;

  const Bike({
    required this.id,
    required this.name,
    this.make,
    this.model,
    this.brandId,
    this.modelId,
    this.year,
    this.yearOfPurchase,
    this.registration,
    this.type = BikeType.commuter,
    this.odometerKm = 0,
    this.photoPath,
    this.notes,
    required this.createdAt,
  });

  String get displayTitle {
    final parts = [make, model].where((e) => e != null && e.isNotEmpty).toList();
    if (parts.isEmpty) return name;
    return '${parts.join(' ')}${year != null ? ' ($year)' : ''}';
  }

  Bike copyWith({
    String? name,
    String? make,
    String? model,
    String? brandId,
    String? modelId,
    int? year,
    int? yearOfPurchase,
    String? registration,
    BikeType? type,
    double? odometerKm,
    String? photoPath,
    String? notes,
  }) {
    return Bike(
      id: id,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      brandId: brandId ?? this.brandId,
      modelId: modelId ?? this.modelId,
      year: year ?? this.year,
      yearOfPurchase: yearOfPurchase ?? this.yearOfPurchase,
      registration: registration ?? this.registration,
      type: type ?? this.type,
      odometerKm: odometerKm ?? this.odometerKm,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'make': make,
        'model': model,
        'brandId': brandId,
        'modelId': modelId,
        'year': year,
        'yearOfPurchase': yearOfPurchase,
        'registration': registration,
        'type': type.name,
        'odometerKm': odometerKm,
        'photoPath': photoPath,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bike.fromMap(Map<String, dynamic> map) => Bike(
        id: map['id'] as String,
        name: map['name'] as String,
        make: map['make'] as String?,
        model: map['model'] as String?,
        brandId: map['brandId'] as String?,
        modelId: map['modelId'] as String?,
        year: map['year'] as int?,
        yearOfPurchase: map['yearOfPurchase'] as int?,
        registration: map['registration'] as String?,
        type: BikeType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => BikeType.other,
        ),
        odometerKm: (map['odometerKm'] as num?)?.toDouble() ?? 0,
        photoPath: map['photoPath'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
