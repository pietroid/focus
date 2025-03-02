import 'package:intl/intl.dart';

extension StringFormatter on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

extension MoneyFormatter on double {
  String formatAsMoney() {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: 2,
    );
    final formattedNumber = formatter.format(this);
    return '\$ $formattedNumber';
  }
}

extension MoneyFormatterText on String {
  num formatAsNumber() {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: 2,
    );
    final parsedNumber = formatter.parse(this);
    return parsedNumber;
  }
}
