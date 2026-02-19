import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../providers/matchmaking_providers.dart';

class MatchmakingDialog extends ConsumerStatefulWidget {
  const MatchmakingDialog({super.key});

  @override
  ConsumerState<MatchmakingDialog> createState() => _MatchmakingDialogState();
}

class _MatchmakingDialogState extends ConsumerState<MatchmakingDialog> {
  @override
  void initState() {
    super.initState();
    // Start searching when dialog opens
    Future.microtask(() {
      ref.read(matchmakingProvider.notifier).findMatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingProvider);

    // Navigate to game when matched
    ref.listen<MatchmakingState>(matchmakingProvider, (prev, next) {
      if (next.status == MatchmakingStatus.matched && next.gameId != null) {
        Navigator.of(context).pop(); // close dialog
        context.go('/game/${next.gameId}');
      }
    });

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status == MatchmakingStatus.searching) ...[
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppColors.playerX,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Finding opponent...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  ref.read(matchmakingProvider.notifier).cancelSearch();
                  Navigator.of(context).pop();
                },
                child: const Text('CANCEL'),
              ),
            ] else if (state.status == MatchmakingStatus.timeout) ...[
              const Icon(
                Icons.timer_off,
                color: AppColors.draw,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No opponents found',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try again later',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ] else if (state.status == MatchmakingStatus.error) ...[
              const Icon(
                Icons.error_outline,
                color: AppColors.loss,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'Something went wrong',
                style: const TextStyle(color: AppColors.loss),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
