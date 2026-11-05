/// Rupee amounts in the Indian style used across bookings and payments.
class MoneyText {
  MoneyText._();

  /// "₹12,50,000" (lakh grouping, no paise).
  static String full(double amount) {
    final negative = amount < 0;
    final digits = amount.abs().round().toString();
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$last3';
    }
    return '${negative ? '-' : ''}₹$grouped';
  }

  /// "₹12.5 L", "₹1.2 Cr" or "₹45,000", for tight spaces.
  static String short(double amount) {
    final abs = amount.abs();
    if (abs >= 10000000) return '₹${_trim(amount / 10000000)} Cr';
    if (abs >= 100000) return '₹${_trim(amount / 100000)} L';
    return full(amount);
  }

  static String _trim(double v, {int decimals = 2}) {
    final text = v.toStringAsFixed(decimals);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// "₹1,371.35" for an amount with paise, otherwise the same as [full].
  static String exact(double amount) {
    if (amount == amount.roundToDouble()) return full(amount);
    final parts = amount.toStringAsFixed(2).split('.');
    return '${full(double.parse(parts[0]))}.${parts[1]}';
  }

  /// "1,20,000" or "1,371.35": [exact] without the rupee sign, for areas.
  static String grouped(double value) => exact(value).replaceFirst('₹', '');

  /// "1234.5" or "200", for prefilling a field that [parse] reads back.
  static String plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : _trim(value, decimals: 3);

  /// Reads "12,50,000" or "1250000" typed in a field; null when invalid.
  static double? parse(String? text) {
    final cleaned = (text ?? '').replaceAll(RegExp(r'[,\s₹]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
