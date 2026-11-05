/// Friendly date and greeting text used across the dashboard.
class DateText {
  DateText._();

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Good morning" / "Good afternoon" / "Good evening" for [time].
  static String greeting(DateTime time) {
    if (time.hour < 12) return 'Good morning';
    if (time.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// "Monday, 26 Oct 2026".
  static String longDate(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]} ${date.year}';

  /// "26 Oct 2026".
  static String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
}
