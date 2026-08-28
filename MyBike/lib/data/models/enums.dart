import 'package:flutter/material.dart';

/// Distance unit used for display. Internally everything is stored in km.
enum DistanceUnit {
  km,
  mi;

  String get label => this == DistanceUnit.km ? 'km' : 'mi';
}

/// Rider gender for profile settings.
enum RiderGender {
  male,
  female,
  other;

  String get label => switch (this) {
        RiderGender.male => 'Male',
        RiderGender.female => 'Female',
        RiderGender.other => 'Other',
      };
}

/// High level category of the motorbike.
enum BikeType {
  commuter,
  sport,
  cruiser,
  adventure,
  touring,
  offRoad,
  scooter,
  other;

  String get label => switch (this) {
        BikeType.commuter => 'Commuter',
        BikeType.sport => 'Sport',
        BikeType.cruiser => 'Cruiser',
        BikeType.adventure => 'Adventure',
        BikeType.touring => 'Touring',
        BikeType.offRoad => 'Off-road',
        BikeType.scooter => 'Scooter',
        BikeType.other => 'Other',
      };

  IconData get icon => switch (this) {
        BikeType.scooter => Icons.moped,
        BikeType.offRoad => Icons.terrain,
        _ => Icons.two_wheeler,
      };
}

/// Motorbike-specific service / serviceable component types.
enum ServiceType {
  engineOil,
  oilFilter,
  airFilter,
  chainLube,
  chainSprocket,
  frontTire,
  rearTire,
  brakePadsFront,
  brakePadsRear,
  brakeFluid,
  coolant,
  sparkPlug,
  battery,
  valveClearance,
  generalService,
  other;

  String get label => switch (this) {
        ServiceType.engineOil => 'Engine Oil',
        ServiceType.oilFilter => 'Oil Filter',
        ServiceType.airFilter => 'Air Filter',
        ServiceType.chainLube => 'Chain Lube',
        ServiceType.chainSprocket => 'Chain & Sprocket',
        ServiceType.frontTire => 'Front Tire',
        ServiceType.rearTire => 'Rear Tire',
        ServiceType.brakePadsFront => 'Front Brake Pads',
        ServiceType.brakePadsRear => 'Rear Brake Pads',
        ServiceType.brakeFluid => 'Brake Fluid',
        ServiceType.coolant => 'Coolant',
        ServiceType.sparkPlug => 'Spark Plug',
        ServiceType.battery => 'Battery',
        ServiceType.valveClearance => 'Valve Clearance',
        ServiceType.generalService => 'General Service',
        ServiceType.other => 'Other',
      };

  IconData get icon => switch (this) {
        ServiceType.engineOil => Icons.oil_barrel,
        ServiceType.oilFilter => Icons.filter_alt,
        ServiceType.airFilter => Icons.air,
        ServiceType.chainLube => Icons.link,
        ServiceType.chainSprocket => Icons.settings,
        ServiceType.frontTire => Icons.trip_origin,
        ServiceType.rearTire => Icons.trip_origin,
        ServiceType.brakePadsFront => Icons.disc_full,
        ServiceType.brakePadsRear => Icons.disc_full,
        ServiceType.brakeFluid => Icons.water_drop,
        ServiceType.coolant => Icons.ac_unit,
        ServiceType.sparkPlug => Icons.electric_bolt,
        ServiceType.battery => Icons.battery_charging_full,
        ServiceType.valveClearance => Icons.tune,
        ServiceType.generalService => Icons.build,
        ServiceType.other => Icons.handyman,
      };

  /// Sensible default service interval in km (null when not distance-based).
  double? get defaultIntervalKm => switch (this) {
        ServiceType.engineOil => 3000,
        ServiceType.oilFilter => 6000,
        ServiceType.airFilter => 10000,
        ServiceType.chainLube => 500,
        ServiceType.chainSprocket => 25000,
        ServiceType.frontTire => 18000,
        ServiceType.rearTire => 12000,
        ServiceType.brakePadsFront => 20000,
        ServiceType.brakePadsRear => 25000,
        ServiceType.brakeFluid => 24000,
        ServiceType.coolant => 24000,
        ServiceType.sparkPlug => 12000,
        ServiceType.battery => null,
        ServiceType.valveClearance => 24000,
        ServiceType.generalService => 6000,
        ServiceType.other => null,
      };

  /// Sensible default service interval in months (null when not time-based).
  int? get defaultIntervalMonths => switch (this) {
        ServiceType.engineOil => 6,
        ServiceType.oilFilter => 12,
        ServiceType.brakeFluid => 24,
        ServiceType.coolant => 24,
        ServiceType.battery => 36,
        ServiceType.generalService => 12,
        _ => null,
      };
}
