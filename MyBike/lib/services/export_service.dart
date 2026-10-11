import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/bike.dart';
import '../data/models/fuel_entry.dart';
import '../data/models/service_record.dart';
import '../providers/app_providers.dart';

/// Exports service history + fuel log as CSV. Written as a small service
/// (rather than inline in Settings) so the Settings widget stays testable
/// against an injected implementation.
class ExportService {
  ExportService(this._ref);
  final Ref _ref;

  /// Returns the two generated file paths (service + fuel) and triggers the
  /// native share sheet. On a device without a share target, the files are
  /// still written to the app's documents directory and can be fetched by
  /// the caller.
  Future<ExportResult> exportAll() async {
    final bikes = _ref.read(bikesProvider);
    final records = _ref.read(recordsProvider);
    final fuel = _ref.read(fuelProvider);

    final servicePath = await _writeCsv(
      filename: 'mybike-services.csv',
      content: _serviceCsv(records, bikes),
    );
    final fuelPath = await _writeCsv(
      filename: 'mybike-fuel.csv',
      content: _fuelCsv(fuel, bikes),
    );

    // Share both files. Failures (no share target, declined) must not
    // break the export — the files still exist on disk.
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(servicePath), XFile(fuelPath)],
          text: 'MyBike data export',
        ),
      );
    } catch (_) {
      // Swallow: caller already has the paths and can surface them.
    }

    return ExportResult(servicePath: servicePath, fuelPath: fuelPath);
  }

  Future<String> _writeCsv({
    required String filename,
    required String content,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  String _serviceCsv(List<ServiceRecord> records, List<Bike> bikes) {
    final byId = {for (final b in bikes) b.id: b};
    final buf = StringBuffer()
      ..writeln(
        'Bike,Date,Type,OdometerKm,Cost,Provider,Notes',
      );
    final sorted = List<ServiceRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final r in sorted) {
      buf.writeln([
        _csv(byId[r.bikeId]?.name ?? r.bikeId),
        r.date.toIso8601String(),
        r.type.name,
        r.odometerKm.toStringAsFixed(1),
        r.cost?.toStringAsFixed(2) ?? '',
        _csv(r.provider ?? ''),
        _csv(r.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  String _fuelCsv(List<FuelEntry> entries, List<Bike> bikes) {
    final byId = {for (final b in bikes) b.id: b};
    final buf = StringBuffer()
      ..writeln(
        'Bike,Date,OdometerKm,Liters,Cost,FullTank,Notes',
      );
    final sorted = List<FuelEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      buf.writeln([
        _csv(byId[e.bikeId]?.name ?? e.bikeId),
        e.date.toIso8601String(),
        e.odometerKm.toStringAsFixed(1),
        e.liters.toStringAsFixed(2),
        e.cost?.toStringAsFixed(2) ?? '',
        e.fullTank ? 'true' : 'false',
        _csv(e.notes ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  /// Escape a value per RFC 4180: double any inner quote, wrap in quotes
  /// whenever the value contains a comma, quote, newline, or carriage
  /// return.
  String _csv(String value) {
    final needsQuoting = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuoting ? '"$escaped"' : escaped;
  }
}

class ExportResult {
  final String servicePath;
  final String fuelPath;
  const ExportResult({required this.servicePath, required this.fuelPath});
}

final exportServiceProvider =
    Provider<ExportService>((ref) => ExportService(ref));
