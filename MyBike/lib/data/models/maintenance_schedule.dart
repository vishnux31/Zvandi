import 'package:flutter/material.dart';

/// Priority level for a scheduled maintenance task.
enum MaintenancePriority {
  high,
  medium,
  low;

  static MaintenancePriority? fromString(String? value) => switch (value) {
        'high' => MaintenancePriority.high,
        'medium' => MaintenancePriority.medium,
        'low' => MaintenancePriority.low,
        _ => null,
      };
}

/// Maintenance category (oil, filter, chain, …) from the reference database.
enum MaintenanceCategory {
  oil,
  filter,
  chain,
  brake,
  engine,
  cooling,
  suspension,
  ignition,
  fuel,
  electrical,
  tyres,
  battery,
  motor,
  software,
  timing,
  other;

  static MaintenanceCategory fromString(String value) => switch (value) {
        'oil' => MaintenanceCategory.oil,
        'filter' => MaintenanceCategory.filter,
        'chain' => MaintenanceCategory.chain,
        'brake' => MaintenanceCategory.brake,
        'engine' => MaintenanceCategory.engine,
        'cooling' => MaintenanceCategory.cooling,
        'suspension' => MaintenanceCategory.suspension,
        'ignition' => MaintenanceCategory.ignition,
        'fuel' => MaintenanceCategory.fuel,
        'electrical' => MaintenanceCategory.electrical,
        'tyres' => MaintenanceCategory.tyres,
        'battery' => MaintenanceCategory.battery,
        'motor' => MaintenanceCategory.motor,
        'software' => MaintenanceCategory.software,
        'timing' => MaintenanceCategory.timing,
        _ => MaintenanceCategory.other,
      };

  String get label => switch (this) {
        MaintenanceCategory.oil => 'Oil',
        MaintenanceCategory.filter => 'Filter',
        MaintenanceCategory.chain => 'Chain',
        MaintenanceCategory.brake => 'Brake',
        MaintenanceCategory.engine => 'Engine',
        MaintenanceCategory.cooling => 'Cooling',
        MaintenanceCategory.suspension => 'Suspension',
        MaintenanceCategory.ignition => 'Ignition',
        MaintenanceCategory.fuel => 'Fuel',
        MaintenanceCategory.electrical => 'Electrical',
        MaintenanceCategory.tyres => 'Tyres',
        MaintenanceCategory.battery => 'Battery',
        MaintenanceCategory.motor => 'Motor',
        MaintenanceCategory.software => 'Software',
        MaintenanceCategory.timing => 'Timing',
        MaintenanceCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        MaintenanceCategory.oil => Icons.water_drop_outlined,
        MaintenanceCategory.filter => Icons.filter_alt_outlined,
        MaintenanceCategory.chain => Icons.link,
        MaintenanceCategory.brake => Icons.disc_full_outlined,
        MaintenanceCategory.engine => Icons.settings_outlined,
        MaintenanceCategory.cooling => Icons.ac_unit_outlined,
        MaintenanceCategory.suspension => Icons.unfold_more,
        MaintenanceCategory.ignition => Icons.electric_bolt_outlined,
        MaintenanceCategory.fuel => Icons.local_gas_station_outlined,
        MaintenanceCategory.electrical => Icons.electrical_services_outlined,
        MaintenanceCategory.tyres => Icons.trip_origin,
        MaintenanceCategory.battery => Icons.battery_charging_full_outlined,
        MaintenanceCategory.motor => Icons.electric_moped_outlined,
        MaintenanceCategory.software => Icons.system_update_outlined,
        MaintenanceCategory.timing => Icons.schedule_outlined,
        MaintenanceCategory.other => Icons.handyman_outlined,
      };
}

/// Accent colour for electric brands and EV models in the maintenance UI.
const kElectricAccentColor = Color(0xFF81C784);

class PriorityStyle {
  final Color background;
  final Color foreground;
  final String label;

  const PriorityStyle({
    required this.background,
    required this.foreground,
    required this.label,
  });

  factory PriorityStyle.fromMap(Map<String, dynamic> map) => PriorityStyle(
        background: _parseColor(map['bg'] as String),
        foreground: _parseColor(map['color'] as String),
        label: map['label'] as String,
      );
}

class ScheduledMaintenanceTask {
  final String task;
  final String interval;
  final MaintenanceCategory category;
  final MaintenancePriority priority;

  const ScheduledMaintenanceTask({
    required this.task,
    required this.interval,
    required this.category,
    required this.priority,
  });

  factory ScheduledMaintenanceTask.fromMap(Map<String, dynamic> map) {
    return ScheduledMaintenanceTask(
      task: map['task'] as String,
      interval: map['interval'] as String,
      category: MaintenanceCategory.fromString(map['type'] as String),
      priority: MaintenancePriority.fromString(map['priority'] as String) ??
          MaintenancePriority.medium,
    );
  }
}

class ScheduleModelSpec {
  final String name;
  final double cc;
  final String type;
  final String cooling;
  final bool chain;
  final List<ScheduledMaintenanceTask> maintenance;
  final String notes;

  const ScheduleModelSpec({
    required this.name,
    required this.cc,
    required this.type,
    required this.cooling,
    required this.chain,
    required this.maintenance,
    required this.notes,
  });

  factory ScheduleModelSpec.fromMap(Map<String, dynamic> map) =>
      ScheduleModelSpec(
        name: map['name'] as String,
        cc: (map['cc'] as num).toDouble(),
        type: map['type'] as String,
        cooling: map['cooling'] as String,
        chain: map['chain'] as bool? ?? true,
        maintenance: (map['maintenance'] as List<dynamic>)
            .map((e) =>
                ScheduledMaintenanceTask.fromMap(e as Map<String, dynamic>))
            .toList(),
        notes: map['notes'] as String,
      );
}

class ScheduleBrand {
  final String id;
  final String name;
  final String origin;
  final Color color;
  final bool isElectric;
  final List<ScheduleModelSpec> models;

  const ScheduleBrand({
    required this.id,
    required this.name,
    required this.origin,
    required this.color,
    this.isElectric = false,
    required this.models,
  });

  factory ScheduleBrand.fromMap(Map<String, dynamic> map) => ScheduleBrand(
        id: map['id'] as String,
        name: map['name'] as String,
        origin: map['origin'] as String,
        color: _parseColor(map['color'] as String),
        isElectric: map['isElectric'] as bool? ?? false,
        models: (map['models'] as List<dynamic>)
            .map((e) => ScheduleModelSpec.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class MaintenanceScheduleDatabase {
  final List<ScheduleBrand> brands;
  final Map<MaintenanceCategory, Color> typeColors;
  final Map<MaintenancePriority, PriorityStyle> priorityStyles;

  const MaintenanceScheduleDatabase({
    required this.brands,
    required this.typeColors,
    required this.priorityStyles,
  });

  factory MaintenanceScheduleDatabase.fromMap(Map<String, dynamic> map) {
    final rawTypeColors = map['typeColors'] as Map<String, dynamic>;
    final typeColors = <MaintenanceCategory, Color>{};
    for (final entry in rawTypeColors.entries) {
      typeColors[MaintenanceCategory.fromString(entry.key)] =
          _parseColor(entry.value as String);
    }

    final rawPriority = map['priorityBadge'] as Map<String, dynamic>;
    final priorityStyles = <MaintenancePriority, PriorityStyle>{};
    for (final p in MaintenancePriority.values) {
      final style = rawPriority[p.name];
      if (style != null) {
        priorityStyles[p] = PriorityStyle.fromMap(style as Map<String, dynamic>);
      }
    }

    return MaintenanceScheduleDatabase(
      brands: (map['brands'] as List<dynamic>)
          .map((e) => ScheduleBrand.fromMap(e as Map<String, dynamic>))
          .toList(),
      typeColors: typeColors,
      priorityStyles: priorityStyles,
    );
  }

  Color colorFor(MaintenanceCategory category) =>
      typeColors[category] ?? const Color(0xFF888888);

  PriorityStyle styleFor(MaintenancePriority priority) =>
      priorityStyles[priority] ??
      const PriorityStyle(
        background: Color(0xFFEAF6EA),
        foreground: Color(0xFF1E8449),
        label: 'Medium',
      );
}

/// Resolved maintenance profile for a rider's bike.
class BikeMaintenanceProfile {
  final ScheduleBrand brand;
  final ScheduleModelSpec model;
  final bool exactModelMatch;

  const BikeMaintenanceProfile({
    required this.brand,
    required this.model,
    required this.exactModelMatch,
  });

  /// Light green for EV brands/models; otherwise the brand colour from the DB.
  Color get accentColor =>
      (brand.isElectric || model.cc == 0) ? kElectricAccentColor : brand.color;

  bool get isElectricModel => brand.isElectric || model.cc == 0;

  int get highPriorityCount =>
      model.maintenance.where((t) => t.priority == MaintenancePriority.high).length;

  int get categoryCount =>
      model.maintenance.map((t) => t.category).toSet().length;
}

Color _parseColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

String _normalizeName(String input) =>
    input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Maps catalog / Firestore brand ids to the maintenance database ids.
const maintenanceBrandAliases = <String, String>{
  'hero': 'hero',
  'royal-enfield': 'royalenfield',
  'bajaj': 'bajaj',
  'honda': 'honda',
  'yamaha': 'yamaha',
  'tvs': 'tvs',
  'ktm': 'ktm',
  'suzuki': 'suzuki',
  'bmw': 'bmw',
  'benelli': 'benelli',
  'aprilia': 'aprilia',
  'ducati': 'ducati',
  'harley-davidson': 'harley',
  'kawasaki': 'kawasaki',
  'triumph': 'triumph',
  'jawa': 'jawa',
  'yezdi': 'yezdi',
  'mahindra': 'mahindra',
  'husqvarna': 'husqvarna',
  'keeway': 'keeway',
  'cfmoto': 'cfmoto',
  'ola-electric': 'ola',
  'ather': 'ather',
  'vida': 'vida',
  'revolt': 'revolt',
  'okinawa': 'okinawa',
};

ScheduleBrand? _findBrand(
  MaintenanceScheduleDatabase db, {
  String? brandId,
  String? make,
}) {
  if (brandId != null) {
    final alias = maintenanceBrandAliases[brandId] ?? brandId;
    final byId = db.brands.where((b) => b.id == alias);
    if (byId.isNotEmpty) return byId.first;
  }
  if (make == null || make.trim().isEmpty) return null;
  final normMake = _normalizeName(make);
  for (final brand in db.brands) {
    if (_normalizeName(brand.name).contains(normMake) ||
        normMake.contains(_normalizeName(brand.name))) {
      return brand;
    }
    if (normMake.contains(_normalizeName(brand.id.replaceAll('-', ' ')))) {
      return brand;
    }
  }
  return null;
}

ScheduleModelSpec? _findModel(List<ScheduleModelSpec> models, String? modelName) {
  if (modelName == null || modelName.trim().isEmpty) return null;
  final norm = _normalizeName(modelName);

  ScheduleModelSpec? best;
  var bestScore = 0;

  for (final spec in models) {
    final specNorm = _normalizeName(spec.name);
    if (specNorm == norm) return spec;

    for (final part in spec.name.split('/')) {
      final partNorm = _normalizeName(part);
      if (partNorm == norm) return spec;
      if (partNorm.contains(norm) || norm.contains(partNorm)) {
        final score = partNorm.length;
        if (score > bestScore) {
          bestScore = score;
          best = spec;
        }
      }
    }

    final specTokens = specNorm.split(' ').where((t) => t.length > 2);
    final bikeTokens = norm.split(' ').where((t) => t.length > 2);
    var overlap = 0;
    for (final token in bikeTokens) {
      if (specTokens.any((s) => s == token || s.contains(token) || token.contains(s))) {
        overlap++;
      }
    }
    if (overlap >= 2 && overlap > bestScore) {
      bestScore = overlap;
      best = spec;
    }
  }

  return best;
}

BikeMaintenanceProfile? resolveMaintenanceProfile(
  MaintenanceScheduleDatabase db,
  String? brandId,
  String? make,
  String? model,
) {
  final brand = _findBrand(db, brandId: brandId, make: make);
  if (brand == null) return null;

  final spec = _findModel(brand.models, model);
  if (spec == null) return null;

  final exact = _normalizeName(spec.name) == _normalizeName(model ?? '');
  return BikeMaintenanceProfile(
    brand: brand,
    model: spec,
    exactModelMatch: exact,
  );
}
