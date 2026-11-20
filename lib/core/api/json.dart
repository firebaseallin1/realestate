/// Conversions between the app's values and the API's: money travels as whole
/// paise and calendar dates as "YYYY-MM-DD".
int toPaise(double rupees) => (rupees * 100).round();

double fromPaise(num paise) => paise / 100;

String dayToJson(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

/// Parsed by hand: DateTime.parse would be right here, but this states that
/// the date is a local calendar day, with no time zone involved.
DateTime dayFromJson(String day) {
  final parts = day.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
