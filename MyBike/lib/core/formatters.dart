import 'package:intl/intl.dart';

import '../data/models/enums.dart';
import 'units.dart';

final _dateFormat = DateFormat('d MMM yyyy');
// Indian-style digit grouping (e.g. 1,23,456) to match the rest of the app.
final _numberFormat = NumberFormat('#,##,##0');
final _decimalFormat = NumberFormat('#,##,##0.0');

/// Indian rupee — fixed across the app.
const kCurrencySymbol = '₹';

String formatDate(DateTime date) => _dateFormat.format(date);

String formatDistance(double km, DistanceUnit unit, {bool withUnit = true}) {
  final value = unit.fromKm(km);
  final text = _numberFormat.format(value.round());
  return withUnit ? '$text ${unit.label}' : text;
}

String formatDistanceShort(double km, DistanceUnit unit) {
  final value = unit.fromKm(km);
  if (value.abs() >= 1000) {
    return '${_decimalFormat.format(value / 1000)}k ${unit.label}';
  }
  return '${_numberFormat.format(value.round())} ${unit.label}';
}

String formatCost(double cost) =>
    '$kCurrencySymbol${_decimalFormat.format(cost)}';

/// A human friendly "due in" / "overdue" string from a signed remaining value.
String relativeDays(DateTime due, DateTime now) {
  final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return '${-days}d overdue';
  if (days == 0) return 'due today';
  if (days < 30) return 'in ${days}d';
  final months = (days / 30).round();
  return 'in ${months}mo';
}
