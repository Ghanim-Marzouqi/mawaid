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
  final bool showRejected;

  const CalendarView({
    super.key,
    required this.appointments,
    required this.onDaySelected,
    this.selectedDay,
    this.showRejected = false,
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
      if (start.year != day.year ||
          start.month != day.month ||
          start.day != day.day) {
        return false;
      }
      if (a.status == AppointmentStatus.cancelled) {
        return false;
      }
      if (a.status == AppointmentStatus.rejected && !widget.showRejected) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar<Appointment>(
          locale: 'ar_OM',
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.saturday,
          rowHeight: 52,
          daysOfWeekHeight: 32,
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
            outsideDaysVisible: false,
            cellMargin: const EdgeInsets.all(3),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            todayTextStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            defaultTextStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            weekendTextStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
            markersMaxCount: 3,
            markersAlignment: Alignment.bottomCenter,
            markerMargin: const EdgeInsets.only(bottom: 4),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            weekendStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              final isSelected = isSameDay(_selectedDay, date);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(3).map((event) {
                    return Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : _typeColor(event.type),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: _typeColor(event.type)
                                    .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
            headerPadding: const EdgeInsets.symmetric(vertical: 12),
            titleTextStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'ReadexPro',
            ),
            formatButtonDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            formatButtonTextStyle: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: AppColors.primary,
              size: 24,
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
              size: 24,
            ),
          ),
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
