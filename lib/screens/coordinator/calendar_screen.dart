import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../utils/format_date.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/calendar_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = toMuscat(DateTime.now().toUtc());
    Future.microtask(
      () => ref.read(appointmentProvider.notifier).fetchAppointments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentProvider);
    final selectedDayAppointments = _selectedDay == null
        ? <dynamic>[]
        : state.appointments.where((a) {
            final start = toMuscat(a.startTime);
            return start.year == _selectedDay!.year &&
                start.month == _selectedDay!.month &&
                start.day == _selectedDay!.day &&
                a.status != AppointmentStatus.cancelled &&
                a.status != AppointmentStatus.rejected;
          }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.calendar)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text(Strings.networkError),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(appointmentProvider.notifier).fetchAppointments(),
                        child: const Text(Strings.retry),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    CalendarView(
                      appointments: state.appointments,
                      selectedDay: _selectedDay,
                      onDaySelected: (day) {
                        setState(() => _selectedDay = day);
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: selectedDayAppointments.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.calendarOff, size: 48, color: AppColors.onSurfaceVariant),
                                  SizedBox(height: 12),
                                  Text(
                                    Strings.noAppointments,
                                    style: TextStyle(color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: selectedDayAppointments.length,
                              itemBuilder: (context, index) {
                                final a = selectedDayAppointments[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AppointmentCard(
                                    appointment: a,
                                    onTap: () => context.push('/coordinator/appointment/${a.id}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
