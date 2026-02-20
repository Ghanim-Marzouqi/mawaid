import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/appointment.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../utils/format_date.dart';
import '../../widgets/calendar_view.dart';
import '../../widgets/status_badge.dart';

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
        ? <Appointment>[]
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
                      const Icon(LucideIcons.wifiOff,
                          size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text(Strings.networkError),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(appointmentProvider.notifier)
                            .fetchAppointments(),
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
                    // Legend
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(
                              color: AppColors.ministry,
                              label: Strings.ministry),
                          const SizedBox(width: 16),
                          _LegendDot(
                              color: AppColors.patient,
                              label: Strings.patient),
                          const SizedBox(width: 16),
                          _LegendDot(
                              color: AppColors.external_,
                              label: Strings.external_),
                        ],
                      ),
                    ),
                    // Selected day header
                    if (_selectedDay != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16, 8, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              formatShortDate(_selectedDay!),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'ReadexPro',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${selectedDayAppointments.length} \u0645\u0648\u0627\u0639\u064a\u062f',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Appointment list
                    Expanded(
                      child: selectedDayAppointments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.06),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      LucideIcons.calendarOff,
                                      size: 28,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    Strings.noAppointments,
                                    style: TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 16),
                              itemCount: selectedDayAppointments.length,
                              itemBuilder: (context, index) {
                                final a = selectedDayAppointments[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: _CalendarAppointmentCard(
                                    appointment: a,
                                    onTap: () => context.push(
                                        '/manager/appointment/${a.id}'),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _CalendarAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;

  const _CalendarAppointmentCard({
    required this.appointment,
    this.onTap,
  });

  Color get _typeColor => switch (appointment.type) {
        AppointmentType.ministry => AppColors.ministry,
        AppointmentType.patient => AppColors.patient,
        AppointmentType.external_ => AppColors.external_,
      };

  IconData get _typeIcon => switch (appointment.type) {
        AppointmentType.ministry => LucideIcons.landmark,
        AppointmentType.patient => LucideIcons.userRound,
        AppointmentType.external_ => LucideIcons.building2,
      };

  String get _typeLabel => switch (appointment.type) {
        AppointmentType.ministry => Strings.ministry,
        AppointmentType.patient => Strings.patient,
        AppointmentType.external_ => Strings.external_,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: const BorderRadiusDirectional.only(
                    topEnd: Radius.circular(0),
                    bottomEnd: Radius.circular(0),
                    topStart: Radius.circular(12),
                    bottomStart: Radius.circular(12),
                  ),
                ),
              ),
              // Time column
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatTime(appointment.startTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _typeColor,
                        fontFamily: 'ReadexPro',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Icon(
                        LucideIcons.arrowDown,
                        size: 10,
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      formatTime(appointment.endTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant
                            .withValues(alpha: 0.6),
                        fontFamily: 'ReadexPro',
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical separator
              Container(
                width: 1,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_typeIcon,
                                size: 13, color: _typeColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _typeLabel,
                            style: TextStyle(
                              color: _typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(status: appointment.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appointment.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (appointment.location != null &&
                          appointment.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              size: 12,
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                appointment.location!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Chevron
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 16,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
