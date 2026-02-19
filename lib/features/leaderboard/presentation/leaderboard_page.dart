import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../providers/leaderboard_providers.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [AppColors.surface, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textSecondary),
                      onPressed: () => context.go('/menu'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LEADERBOARD',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.playerX,
                                fontSize: 24,
                              ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: leaderboard.when(
                  loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.playerX),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.loss, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load leaderboard',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(leaderboardProvider),
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                  data: (players) {
                    if (players.isEmpty) {
                      return const Center(
                        child: Text(
                          'No players yet',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: AppColors.playerX,
                      onRefresh: () async {
                        ref.invalidate(leaderboardProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          final rank = index + 1;
                          return _LeaderboardTile(
                            rank: rank,
                            displayName:
                                (player['display_name'] as String?) ??
                                    'Anonymous',
                            wins: (player['wins'] as int?) ?? 0,
                            losses: (player['losses'] as int?) ?? 0,
                            draws: (player['draws'] as int?) ?? 0,
                            score: (player['score'] as int?) ?? 0,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;
  final int score;

  const _LeaderboardTile({
    required this.rank,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.score,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 40,
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: _rankColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Player info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'W:$wins  L:$losses  D:$draws',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.playerX.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score',
                style: const TextStyle(
                  color: AppColors.playerX,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
