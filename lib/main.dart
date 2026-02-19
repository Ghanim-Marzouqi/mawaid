import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'utils/format_date.dart';
import 'services/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initTimezone();
  await initializeDateFormatting('ar_OM', null);
  await initSupabase();

  final container = ProviderContainer();
  await container.read(authProvider.notifier).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MawaidApp(),
    ),
  );
}

class MawaidApp extends ConsumerWidget {
  const MawaidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'مواعيد',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      theme: appTheme,
    );
  }
}
