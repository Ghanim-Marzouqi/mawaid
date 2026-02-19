import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/appointment.dart';
import '../models/enums.dart';
import '../theme/colors.dart';
import '../utils/format_date.dart';

class CalendarView extends StatefulWidget {
  final List<Appointment> appointments;
  final void Function(DateTime selectedDay) onDaySelected;
  final DateTime? selectedDay;

  const CalendarView({
    super.key,
    required this.appointments,
    required this.onDaySelected,
    this.selectedDay,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = toMuscat(DateTime.now().toUtc());
    _focusedDay = now;
    _selectedDay = widget.selectedDay ?? now;
  }

  List<Appointment> _getEventsForDay(DateTime day) {
    return widget.appointments.where((a) {
      final start = toMuscat(a.startTime);
      return start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar<Appointment>(
      locale: 'ar_OM',
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      startingDayOfWeek: StartingDayOfWeek.saturday,
      availableCalendarFormats: const {
        CalendarFormat.month: 'شهر',
        CalendarFormat.twoWeeks: 'أسبوعين',
        CalendarFormat.week: 'أسبوع',
      },
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        widget.onDaySelected(selectedDay);
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppColors.primary),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: events.take(3).map((event) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _typeColor(event.type),
                ),
              );
            }).toList(),
          );
        },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
        formatButtonDecoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.primary),
          ),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        formatButtonTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _typeColor(AppointmentType type) => switch (type) {
        AppointmentType.ministry => AppColors.ministry,
        AppointmentType.patient => AppColors.patient,
        AppointmentType.external_ => AppColors.external_,
      };
}
