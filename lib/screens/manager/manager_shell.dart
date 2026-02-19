import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ui/responsive_scaffold.dart';

class ManagerShell extends ConsumerStatefulWidget {
  final Widget child;

  const ManagerShell({super.key, required this.child});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell>
    with WidgetsBindingObserver {
  late final RealtimeService _realtime;

  static const _routes = [
    '/manager',
    '/manager/calendar',
    '/manager/notifications',
    '/manager/settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime = RealtimeService(supabase);

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _realtime.subscribe(
        userId: userId,
        onAppointmentChange: (_) {
          ref.read(appointmentProvider.notifier).fetchAppointments();
        },
        onNotificationInsert: (payload) {
          ref.read(notificationProvider.notifier).fetchNotifications();
          if (mounted) {
            final newData = payload.newRecord;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(newData['title'] ?? ''),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        onSuggestionChange: (_) {
          ref.read(appointmentProvider.notifier).fetchAppointments();
        },
      );
    }

    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appointmentProvider.notifier).fetchAppointments();
      ref.read(notificationProvider.notifier).fetchNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtime.dispose();
    super.dispose();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = _routes.length - 1; i >= 0; i--) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(notificationProvider).unreadCount;

    final tabs = [
      const NavigationItem(icon: LucideIcons.clock, label: 'بانتظار'),
      const NavigationItem(icon: LucideIcons.calendar, label: 'التقويم'),
      NavigationItem(
        icon: LucideIcons.bell,
        label: 'الإشعارات',
        badgeCount: unreadCount,
      ),
      const NavigationItem(icon: LucideIcons.settings, label: 'الإعدادات'),
    ];

    return ResponsiveScaffold(
      tabs: tabs,
      currentIndex: _currentIndex(context),
      onTabSelected: (index) => context.go(_routes[index]),
      body: widget.child,
    );
  }
}
