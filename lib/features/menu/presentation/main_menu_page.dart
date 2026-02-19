import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../matchmaking/presentation/matchmaking_dialog.dart';

class MainMenuPage extends ConsumerWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [AppColors.surface, AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LOGIC',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.playerX,
                      fontSize: 36,
                      letterSpacing: 8,
                    ),
              ),
              Text(
                'XO',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.playerO,
                      fontSize: 48,
                      letterSpacing: 12,
                    ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const MatchmakingDialog(),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('FIND MATCH'),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 240,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/leaderboard'),
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('LEADERBOARD'),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.surface,
        onPressed: () async {
          await ref.read(authServiceProvider).signOut();
          if (context.mounted) {
            context.go('/login');
          }
        },
        child: const Icon(Icons.logout, color: AppColors.loss),
      ),
    );
  }
}
