import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/matchmaking_service.dart';
import '../domain/time_control.dart';

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(Supabase.instance.client);
});

enum MatchmakingStatus { idle, searching, matched, timeout, error }

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
  Timer? _timeoutTimer;
  Timer? _pollTimer;

  MatchmakingNotifier(this._service) : super(const MatchmakingState());

  Future<void> findMatch(TimeControl timeControl) async {
    state = const MatchmakingState(status: MatchmakingStatus.searching);

    try {
      // Subscribe to realtime game creation first
      final matchStream = _service.subscribeToMatchFound();
      _matchSub = matchStream.listen((gameId) {
        _cleanup();
        state = MatchmakingState(
          status: MatchmakingStatus.matched,
          gameId: gameId,
        );
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

  Future<void> _tryMatch() async {
    if (state.status != MatchmakingStatus.searching) return;
    try {
      final gameId = await _service.callMatchPlayers();
      if (gameId != null && state.status == MatchmakingStatus.searching) {
        _cleanup();
        state = MatchmakingState(
          status: MatchmakingStatus.matched,
          gameId: gameId,
        );
      }
    } catch (_) {
      // Match not found yet — keep waiting
    }
  }

  Future<void> cancelSearch() async {
    _cleanup();
    try {
      await _service.leaveQueue();
    } catch (_) {}
    state = const MatchmakingState(status: MatchmakingStatus.idle);
  }

  void _cleanup() {
    _matchSub?.cancel();
    _matchSub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
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
