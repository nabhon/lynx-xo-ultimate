import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class MatchmakingService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  MatchmakingService(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Insert current user into the matchmaking queue.
  Future<void> joinQueue({int timeControlSeconds = 60}) async {
    await _client.from('queue').insert({
      'user_id': _userId,
      'time_control_seconds': timeControlSeconds,
    });
  }

  /// Remove current user from the queue.
  Future<void> leaveQueue() async {
    await _client.from('queue').delete().eq('user_id', _userId);
  }

  /// Call the match_players() RPC to try to pair two queued users.
  Future<String?> callMatchPlayers() async {
    final result = await _client.rpc('match_players');
    if (result is String && result.isNotEmpty) {
      return result; // game ID
    }
    return null;
  }

  /// Subscribe to INSERT events on the `games` table where I am a participant.
  /// Returns a stream that emits the game ID when a match is found.
  Stream<String> subscribeToMatchFound() {
    final controller = StreamController<String>.broadcast();

    _channel = _client
        .channel('matchmaking_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_x',
            value: _userId,
          ),
          callback: (payload) {
            final gameId = payload.newRecord['id'] as String;
            controller.add(gameId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_o',
            value: _userId,
          ),
          callback: (payload) {
            final gameId = payload.newRecord['id'] as String;
            controller.add(gameId);
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Unsubscribe from matchmaking realtime channel.
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
