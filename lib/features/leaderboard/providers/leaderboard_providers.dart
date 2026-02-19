import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/leaderboard_service.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService(Supabase.instance.client);
});

final leaderboardProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(leaderboardServiceProvider);
  return service.getTopPlayers();
});
