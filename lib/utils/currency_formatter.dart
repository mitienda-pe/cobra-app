import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Returns the appropriate currency symbol based on the currency code
  static String getCurrencySymbol(String? currencyCode) {
    switch (currencyCode) {
      case 'PEN':
        return 'S/';
      case 'USD':
      default:
        return '\$';
    }
  }

  /// Creates a NumberFormat instance with the correct currency symbol
  static NumberFormat getCurrencyFormat(String? currencyCode, {int decimalDigits = 2}) {
    return NumberFormat.currency(
      symbol: getCurrencySymbol(currencyCode),
      decimalDigits: decimalDigits,
    );
  }

  /// Formats an amount with the correct currency symbol
  static String formatAmount(double amount, String? currencyCode, {int decimalDigits = 2}) {
    return getCurrencyFormat(currencyCode, decimalDigits: decimalDigits).format(amount);
  }
}
