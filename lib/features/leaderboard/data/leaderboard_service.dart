import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardService {
  final SupabaseClient _client;

  LeaderboardService(this._client);

  Future<List<Map<String, dynamic>>> getTopPlayers({int limit = 20}) async {
    final response = await _client
        .from('profiles')
        .select('id, display_name, wins, losses, draws, score')
        .order('score', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }
}
