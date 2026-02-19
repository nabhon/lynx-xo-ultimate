import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/game_service.dart';

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(Supabase.instance.client);
});

class GameState {
  final String gameId;
  final String? playerX;
  final String? playerO;
  final String? turn;
  final List<dynamic> board;
  final List<dynamic> xMoves;
  final List<dynamic> oMoves;
  final String status; // 'playing', 'won', 'draw'
  final String? winner;
  final bool isLoading;

  const GameState({
    required this.gameId,
    this.playerX,
    this.playerO,
    this.turn,
    this.board = const [null, null, null, null, null, null, null, null, null],
    this.xMoves = const [],
    this.oMoves = const [],
    this.status = 'playing',
    this.winner,
    this.isLoading = true,
  });

  GameState copyWith({
    String? playerX,
    String? playerO,
    String? turn,
    List<dynamic>? board,
    List<dynamic>? xMoves,
    List<dynamic>? oMoves,
    String? status,
    String? winner,
    bool? isLoading,
  }) {
    return GameState(
      gameId: gameId,
      playerX: playerX ?? this.playerX,
      playerO: playerO ?? this.playerO,
      turn: turn ?? this.turn,
      board: board ?? this.board,
      xMoves: xMoves ?? this.xMoves,
      oMoves: oMoves ?? this.oMoves,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory GameState.fromMap(String gameId, Map<String, dynamic> map) {
    return GameState(
      gameId: gameId,
      playerX: map['player_x'] as String?,
      playerO: map['player_o'] as String?,
      turn: map['turn'] as String?,
      board: (map['board'] as List<dynamic>?) ??
          List.filled(9, null),
      xMoves: (map['x_moves'] as List<dynamic>?) ?? [],
      oMoves: (map['o_moves'] as List<dynamic>?) ?? [],
      status: (map['status'] as String?) ?? 'playing',
      winner: map['winner'] as String?,
      isLoading: false,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final GameService _service;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  GameNotifier(this._service, String gameId)
      : super(GameState(gameId: gameId)) {
    _init();
  }

  Future<void> _init() async {
    // Fetch initial state
    try {
      final data = await _service.getGame(state.gameId);
      state = GameState.fromMap(state.gameId, data);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }

    // Subscribe to realtime updates
    final stream = _service.subscribeToGame(state.gameId);
    _subscription = stream.listen((data) {
      state = GameState.fromMap(state.gameId, data);
    });
  }

  Future<void> makeMove(int cellIndex) async {
    try {
      await _service.makeMove(state.gameId, cellIndex);
    } catch (_) {
      // Server will reject invalid moves — no client-side handling needed
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.unsubscribe();
    super.dispose();
  }
}

final gameProvider =
    StateNotifierProvider.family<GameNotifier, GameState, String>(
  (ref, gameId) {
    final service = ref.watch(gameServiceProvider);
    return GameNotifier(service, gameId);
  },
);
