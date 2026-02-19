import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

final _muscat = tz.getLocation('Asia/Muscat');

void initTimezone() {
  tz_data.initializeTimeZones();
}

/// Convert a UTC DateTime to Muscat local time.
tz.TZDateTime toMuscat(DateTime utc) {
  return tz.TZDateTime.from(utc.toUtc(), _muscat);
}

/// Create a TZDateTime in Muscat timezone.
tz.TZDateTime muscatNow() {
  return tz.TZDateTime.now(_muscat);
}

/// Format as "الأحد، 1 يناير 2026"
String formatDate(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('EEEE، d MMMM yyyy', 'ar_OM').format(local);
}

/// Format as "09:00 ص"
String formatTime(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('hh:mm a', 'ar_OM').format(local);
}

/// Format as "09:00 ص - 10:00 ص"
String formatTimeRange(DateTime start, DateTime end) {
  return '${formatTime(start)} - ${formatTime(end)}';
}

/// Format as "1 يناير 2026، 09:00 ص"
String formatDateTime(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('d MMMM yyyy، hh:mm a', 'ar_OM').format(local);
}

/// Format as short date "1 يناير"
String formatShortDate(DateTime date) {
  final local = toMuscat(date);
  return DateFormat('d MMMM', 'ar_OM').format(local);
}
