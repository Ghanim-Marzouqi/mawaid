import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/appointment_card.dart';

class PendingQueueScreen extends ConsumerStatefulWidget {
  const PendingQueueScreen({super.key});

  @override
  ConsumerState<PendingQueueScreen> createState() => _PendingQueueScreenState();
}

class _PendingQueueScreenState extends ConsumerState<PendingQueueScreen> {
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
    final pendingAppointments = state.appointments
        .where((a) => a.status == AppointmentStatus.pending)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.pendingQueue)),
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
              : pendingAppointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.circleCheck, size: 48, color: AppColors.confirmed),
                          const SizedBox(height: 12),
                          const Text(
                            Strings.noAppointments,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(appointmentProvider.notifier).fetchAppointments(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendingAppointments.length,
                        itemBuilder: (context, index) {
                          final a = pendingAppointments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppointmentCard(
                              appointment: a,
                              onTap: () => context.push('/manager/appointment/${a.id}'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
