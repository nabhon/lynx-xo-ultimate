import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/matchmaking_service.dart';
import '../domain/time_control.dart';

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(Supabase.instance.client);
});

enum MatchmakingStatus {
  idle,
  searching,
  waitingForOpponent,
  matched,
  abandoned,
  timeout,
  error,
}

class MatchmakingState {
  final MatchmakingStatus status;
  final String? gameId;
  final String? errorMessage;

  const MatchmakingState({
    this.status = MatchmakingStatus.idle,
    this.gameId,
    this.errorMessage,
  });

  MatchmakingState copyWith({
    MatchmakingStatus? status,
    String? gameId,
    String? errorMessage,
  }) {
    return MatchmakingState(
      status: status ?? this.status,
      gameId: gameId ?? this.gameId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class MatchmakingNotifier extends StateNotifier<MatchmakingState> {
  final MatchmakingService _service;
  StreamSubscription<String>? _matchSub;
  StreamSubscription<Map<String, dynamic>>? _gameSub;
  Timer? _timeoutTimer;
  Timer? _pollTimer;

  MatchmakingNotifier(this._service) : super(const MatchmakingState());

  Future<void> findMatch(TimeControl timeControl) async {
    state = const MatchmakingState(status: MatchmakingStatus.searching);

    try {
      // Subscribe to realtime game creation first
      final matchStream = _service.subscribeToMatchFound();
      _matchSub = matchStream.listen((gameId) {
        _handleMatchFound(gameId);
      });

      // Join the queue
      await _service.joinQueue(timeControlSeconds: timeControl.seconds);

      // Try to match immediately
      await _tryMatch();

      // Poll for matches every 3 seconds
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _tryMatch();
      });

      // Timeout after 60 seconds
      _timeoutTimer = Timer(const Duration(seconds: 60), () {
        cancelSearch();
        state = const MatchmakingState(status: MatchmakingStatus.timeout);
      });
    } catch (e) {
      state = MatchmakingState(
        status: MatchmakingStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void _handleMatchFound(String gameId) async {
    // Prevent duplicate handling if polled and matched simultaneously
    if (state.status == MatchmakingStatus.waitingForOpponent ||
        state.status == MatchmakingStatus.matched) {
      return;
    }

    _cleanupQueueTimers();

    state = MatchmakingState(
      status: MatchmakingStatus.waitingForOpponent,
      gameId: gameId,
    );

    // Subscribe to game updates to wait for status == 'playing'
    _gameSub = _service.subscribeToGameUpdates(gameId).listen((gameData) {
      final status = gameData['status'];
      if (status == 'playing') {
        _gameSub?.cancel();
        _gameSub = null;
        _timeoutTimer?.cancel();
        state = MatchmakingState(
          status: MatchmakingStatus.matched,
          gameId: gameId,
        );
      } else if (status == 'abandoned') {
        _gameSub?.cancel();
        _gameSub = null;
        _timeoutTimer?.cancel();
        state = const MatchmakingState(
          status: MatchmakingStatus.abandoned,
          errorMessage: 'Opponent failed to connect.',
        );
      }
    });

    // Mark self as ready
    try {
      await _service.markReady(gameId);
    } catch (e) {
      // Ignore if game doesn't exist or already started
    }

    // Wait 15 seconds for opponent to connect
    _timeoutTimer = Timer(const Duration(seconds: 15), () async {
      await _service.abandonGame(gameId);
      state = const MatchmakingState(
        status: MatchmakingStatus.timeout,
        errorMessage: 'Connection to opponent timed out.',
      );
    });
  }

  Future<void> _tryMatch() async {
    if (state.status != MatchmakingStatus.searching) return;
    try {
      final gameId = await _service.callMatchPlayers();
      if (gameId != null && state.status == MatchmakingStatus.searching) {
        _handleMatchFound(gameId);
      }
    } catch (_) {
      // Match not found yet — keep waiting
    }
  }

  Future<void> cancelSearch() async {
    if (state.status == MatchmakingStatus.waitingForOpponent &&
        state.gameId != null) {
      await _service.abandonGame(state.gameId!);
    }

    _cleanup();
    try {
      await _service.leaveQueue();
    } catch (_) {}
    state = const MatchmakingState(status: MatchmakingStatus.idle);
  }

  void _cleanupQueueTimers() {
    _matchSub?.cancel();
    _matchSub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _cleanup() {
    _cleanupQueueTimers();
    _gameSub?.cancel();
    _gameSub = null;
    _service.unsubscribe();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final matchmakingProvider =
    StateNotifierProvider<MatchmakingNotifier, MatchmakingState>((ref) {
      final service = ref.watch(matchmakingServiceProvider);
      return MatchmakingNotifier(service);
    });
