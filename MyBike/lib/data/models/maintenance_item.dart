import 'enums.dart';

/// A recurring serviceable item on a bike (e.g. "Engine oil every 3000 km").
///
/// Combines the idea of a wearing component and its service schedule so the
/// app can compute wear/health, next-due, and reminders from one source.
class MaintenanceItem {
  final String id;
  final String bikeId;
  final String name;
  final ServiceType type;

  /// Service interval in km. Null when the item is purely time-based.
  final double? intervalKm;

  /// Service interval in months. Null when the item is purely distance-based.
  final int? intervalMonths;

  /// Odometer (km) at the last time this item was serviced / installed.
  final double lastServiceOdometerKm;

  /// Date of the last service / installation.
  final DateTime lastServiceDate;

  final String? notes;
  final DateTime createdAt;

  const MaintenanceItem({
    required this.id,
    required this.bikeId,
    required this.name,
    required this.type,
    this.intervalKm,
    this.intervalMonths,
    required this.lastServiceOdometerKm,
    required this.lastServiceDate,
    this.notes,
    required this.createdAt,
  });

  double? get nextDueOdometerKm =>
      intervalKm == null ? null : lastServiceOdometerKm + intervalKm!;

  DateTime? get nextDueDate {
    if (intervalMonths == null) return null;
    final d = lastServiceDate;
    final totalMonth = d.month + intervalMonths!;
    final year = d.year + (totalMonth - 1) ~/ 12;
    final month = (totalMonth - 1) % 12 + 1;
    final day = d.day;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDayOfMonth ? lastDayOfMonth : day);
  }

  /// Fraction of the service interval consumed, 0..(>1 when overdue).
  /// Returns the more urgent of distance-based and time-based usage.
  double usageFraction(double currentOdometerKm, DateTime now) {
    double? byDistance;
    if (intervalKm != null && intervalKm! > 0) {
      byDistance = (currentOdometerKm - lastServiceOdometerKm) / intervalKm!;
    }
    double? byTime;
    if (intervalMonths != null && intervalMonths! > 0) {
      final due = nextDueDate!;
      final totalDays = due.difference(lastServiceDate).inDays;
      final usedDays = now.difference(lastServiceDate).inDays;
      if (totalDays > 0) byTime = usedDays / totalDays;
    }
    final values = [byDistance, byTime].whereType<double>().toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b).clamp(0.0, double.infinity);
  }

  MaintenanceItem copyWith({
    String? name,
    ServiceType? type,
    double? intervalKm,
    bool clearIntervalKm = false,
    int? intervalMonths,
    bool clearIntervalMonths = false,
    double? lastServiceOdometerKm,
    DateTime? lastServiceDate,
    String? notes,
  }) {
    return MaintenanceItem(
      id: id,
      bikeId: bikeId,
      name: name ?? this.name,
      type: type ?? this.type,
      intervalKm: clearIntervalKm ? null : (intervalKm ?? this.intervalKm),
      intervalMonths:
          clearIntervalMonths ? null : (intervalMonths ?? this.intervalMonths),
      lastServiceOdometerKm:
          lastServiceOdometerKm ?? this.lastServiceOdometerKm,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'bikeId': bikeId,
        'name': name,
        'type': type.name,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
        'lastServiceOdometerKm': lastServiceOdometerKm,
        'lastServiceDate': lastServiceDate.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MaintenanceItem.fromMap(Map<String, dynamic> map) => MaintenanceItem(
        id: map['id'] as String,
        bikeId: map['bikeId'] as String,
        name: map['name'] as String,
        type: ServiceType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => ServiceType.other,
        ),
        intervalKm: (map['intervalKm'] as num?)?.toDouble(),
        intervalMonths: map['intervalMonths'] as int?,
        lastServiceOdometerKm:
            (map['lastServiceOdometerKm'] as num?)?.toDouble() ?? 0,
        lastServiceDate: DateTime.parse(map['lastServiceDate'] as String),
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}
