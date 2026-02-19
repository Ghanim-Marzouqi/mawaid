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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appointmentProvider.notifier).fetchAppointments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentProvider);
    final now = toMuscat(DateTime.now().toUtc());
    final todayAppointments = state.appointments.where((a) {
      final start = toMuscat(a.startTime);
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.rejected;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final pendingCount = state.appointments
        .where((a) => a.status == AppointmentStatus.pending)
        .length;
    final confirmedCount = state.appointments
        .where((a) => a.status == AppointmentStatus.confirmed)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.dashboard)),
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
              : RefreshIndicator(
                  onRefresh: () => ref.read(appointmentProvider.notifier).fetchAppointments(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: Strings.pendingCount,
                              count: pendingCount,
                              color: AppColors.pending,
                              icon: LucideIcons.clock,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: Strings.confirmedCount,
                              count: confirmedCount,
                              color: AppColors.confirmed,
                              icon: LucideIcons.circleCheck,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        Strings.todaySchedule,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(DateTime.now()),
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (todayAppointments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              const Icon(LucideIcons.calendarOff, size: 48, color: AppColors.onSurfaceVariant),
                              const SizedBox(height: 12),
                              const Text(
                                Strings.noAppointments,
                                style: TextStyle(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      else
                        ...todayAppointments.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppointmentCard(
                              appointment: a,
                              onTap: () => context.push('/coordinator/appointment/${a.id}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
