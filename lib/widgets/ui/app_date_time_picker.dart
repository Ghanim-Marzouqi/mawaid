import 'package:flutter/material.dart';

/// Shows a date then time picker and returns the combined DateTime.
/// Returns null if the user cancels either dialog.
Future<DateTime?> showAppDateTimePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: firstDate ?? now.subtract(const Duration(days: 1)),
    lastDate: lastDate ?? DateTime(2030, 12, 31),
    locale: const Locale('ar', 'OM'),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate ?? now),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
