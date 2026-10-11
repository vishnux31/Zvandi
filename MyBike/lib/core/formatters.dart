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

/// A time-of-day greeting, e.g. for the Home screen header.
String greetingForHour(int hour) {
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

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

/// Odometer value formatted for an editable `TextField`:
/// whole numbers display without a decimal, fractional values keep one
/// decimal place. Avoids `.round()` which silently discards precision on
/// every form open/save round-trip.
String formatOdometerForInput(double value) {
  if (value <= 0) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// A human friendly "due in" / "overdue" string from a signed remaining value.
String relativeDays(DateTime due, DateTime now) {
  final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return '${-days}d overdue';
  if (days == 0) return 'due today';
  if (days < 30) return 'in ${days}d';
  final months = (days / 30).round();
  return 'in ${months}mo';
}
