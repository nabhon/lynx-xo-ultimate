import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class GameService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  GameService(this._client);

  /// Call the make_move RPC.
  Future<void> makeMove(String gameId, int cellIndex) async {
    await _client.rpc('make_move', params: {
      'game_id': gameId,
      'cell_index': cellIndex,
    });
  }

  /// Call the expire_game RPC.
  Future<void> expireGame(String gameId) async {
    await _client.rpc('expire_game', params: {
      'p_game_id': gameId,
    });
  }

  /// Fetch the current game state.
  Future<Map<String, dynamic>> getGame(String gameId) async {
    final response =
        await _client.from('games').select().eq('id', gameId).single();
    return response;
  }

  /// Subscribe to real-time updates on a specific game.
  /// Returns a stream of game state maps.
  Stream<Map<String, dynamic>> subscribeToGame(String gameId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    _channel = _client
        .channel('game_$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: gameId,
          ),
          callback: (payload) {
            controller.add(payload.newRecord);
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Unsubscribe from game channel.
  Future<void> unsubscribe() async {
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
