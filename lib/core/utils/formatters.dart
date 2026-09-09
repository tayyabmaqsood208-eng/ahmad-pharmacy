import 'package:intl/intl.dart';

class Formatters {
  static String currency(double amount, {String symbol = 'Rs'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol.endsWith(' ') || symbol.length > 1 ? symbol : '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String date(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String shortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String number(num value) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(value);
  }

  static String daysUntilExpiry(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    if (difference < 0) {
      return 'Expired (${difference.abs()} days ago)';
    } else if (difference == 0) {
      return 'Expires today';
    } else if (difference <= 30) {
      return 'Expires in $difference days';
    } else if (difference <= 365) {
      final months = (difference / 30).floor();
      return 'Expires in $months mo (${difference}d)';
    } else {
      return 'Expires in ${DateFormat('MMM yyyy').format(expiryDate)}';
    }
  }
}
