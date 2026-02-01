import 'package:intl/intl.dart';

int? tryToCents(String input) {
  final sanitized = input
      .trim()
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll(',', '.');
  if (sanitized.isEmpty) return null;
  final value = double.tryParse(sanitized);
  if (value == null) return null;
  return (value * 100).round();
}

String centsToTry(int cents) {
  final format = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 2,
  );
  return format.format(cents / 100);
}
