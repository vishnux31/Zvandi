import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Indian-style digit grouping: 1,23,456 (groups of 2 after the first 3).
final _indianGroup = NumberFormat('#,##,##0');

String formatIndianInt(num value) => _indianGroup.format(value);

/// Formats a whole-number text field with live Indian digit grouping and
/// rejects any non-digit input.
class IndianDigitsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _indianGroup.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Strips grouping separators back to a plain integer (0 when empty).
int parseGroupedInt(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}
