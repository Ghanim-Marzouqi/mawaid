import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/coordinator/coordinator_shell.dart';
import '../screens/coordinator/dashboard_screen.dart';
import '../screens/coordinator/calendar_screen.dart' as coord;
import '../screens/coordinator/create_appointment_screen.dart';
import '../screens/coordinator/appointment_detail_screen.dart' as coord_detail;
import '../screens/coordinator/notifications_screen.dart' as coord_notif;
import '../screens/coordinator/edit_appointment_screen.dart' as coord_edit;
import '../screens/coordinator/settings_screen.dart' as coord_settings;
import '../screens/manager/manager_shell.dart';
import '../screens/manager/pending_queue_screen.dart';
import '../screens/manager/calendar_screen.dart' as mgr;
import '../screens/manager/appointment_detail_screen.dart' as mgr_detail;
import '../screens/manager/suggest_screen.dart';
import '../screens/manager/notifications_screen.dart' as mgr_notif;
import '../screens/manager/settings_screen.dart' as mgr_settings;

/// Bridges Riverpod auth state changes to a [Listenable] so GoRouter
/// re-evaluates its redirect WITHOUT being recreated.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(() => refreshNotifier.dispose());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.session != null;
      final isOnLogin = state.matchedLocation == '/login';
      final isOnReset = state.matchedLocation == '/reset-password';

      if (!isLoggedIn && !isOnLogin && !isOnReset) return '/login';

      if (isLoggedIn) {
        // Allow staying on reset-password even when logged in (recovery session)
        if (isOnReset) return null;

        if (authState.profile == null) {
          return null;
        }

        final role = authState.profile!.role;
        final targetPrefix = '/$role';

        if (isOnLogin) return targetPrefix;

        if (!state.matchedLocation.startsWith(targetPrefix)) {
          return targetPrefix;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => CoordinatorShell(child: child),
        routes: [
          GoRoute(
            path: '/coordinator',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/coordinator/calendar',
            builder: (_, __) => const coord.CalendarScreen(),
          ),
          GoRoute(
            path: '/coordinator/create',
            builder: (_, __) => const CreateAppointmentScreen(),
          ),
          GoRoute(
            path: '/coordinator/appointment/:id',
            builder: (_, state) => coord_detail.AppointmentDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/coordinator/edit/:id',
            builder: (_, state) => coord_edit.EditAppointmentScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/coordinator/notifications',
            builder: (_, __) => const coord_notif.NotificationsScreen(),
          ),
          GoRoute(
            path: '/coordinator/settings',
            builder: (_, __) => const coord_settings.SettingsScreen(),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => ManagerShell(child: child),
        routes: [
          GoRoute(
            path: '/manager',
            builder: (_, __) => const PendingQueueScreen(),
          ),
          GoRoute(
            path: '/manager/calendar',
            builder: (_, __) => const mgr.CalendarScreen(),
          ),
          GoRoute(
            path: '/manager/appointment/:id',
            builder: (_, state) => mgr_detail.AppointmentDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/manager/suggest/:id',
            builder: (_, state) => SuggestScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/manager/notifications',
            builder: (_, __) => const mgr_notif.NotificationsScreen(),
          ),
          GoRoute(
            path: '/manager/settings',
            builder: (_, __) => const mgr_settings.SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, __) => const NotFoundScreen(),
  );
});
