import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: const Icon(
                          LucideIcons.userRound,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile?.fullName ?? '',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Strings.coordinatorRole,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.mail),
                      title: const Text(Strings.email),
                      subtitle: Text(
                        authState.session?.user.email ?? '',
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(LucideIcons.shield),
                      title: const Text(Strings.role),
                      subtitle: const Text(Strings.coordinatorRole),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text(Strings.confirmSignOut),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(Strings.cancel),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(Strings.signOut),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(authProvider.notifier).signOut();
                  }
                },
                icon: const Icon(LucideIcons.logOut, size: 16),
                label: const Text(Strings.signOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
