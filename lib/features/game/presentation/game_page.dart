import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/game_logic.dart';
import '../providers/game_providers.dart';
import 'widgets/game_board.dart';
import 'widgets/player_clock.dart';

class GamePage extends ConsumerWidget {
  final String gameId;
  const GamePage({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider(gameId));
    final myUserId = Supabase.instance.client.auth.currentUser!.id;

    // Show game over dialog when status changes
    ref.listen<GameState>(gameProvider(gameId), (prev, next) {
      if (prev?.status == 'playing' &&
          (next.status == 'won' || next.status == 'draw')) {
        _showGameOverDialog(context, next, myUserId);
      }
    });

    if (game.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.playerX),
        ),
      );
    }

    final myPiece =
        GameLogic.getPieceForUser(myUserId, game.playerX ?? '', game.playerO ?? '');
    final isMyTurn = GameLogic.isMyTurn(game.turn, myUserId);
    final isPlayerX = myUserId == game.playerX;

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textSecondary),
                      onPressed: () => context.go('/menu'),
                    ),
                    Text(
                      'YOU ARE ${myPiece ?? '?'}',
                      style: TextStyle(
                        color: myPiece == 'X'
                            ? AppColors.playerX
                            : AppColors.playerO,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48), // balance
                  ],
                ),
                const SizedBox(height: 16),
                // Clock row
                Row(
                  children: [
                    Expanded(
                      child: PlayerClock(
                        deadline: isPlayerX ? game.oDeadline : game.xDeadline,
                        remainingMs: isPlayerX
                            ? game.oTimeRemainingMs
                            : game.xTimeRemainingMs,
                        piece: isPlayerX ? 'O' : 'X',
                        isActive: game.status == 'playing' &&
                            game.turn == (isPlayerX ? game.playerO : game.playerX),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PlayerClock(
                        deadline: isPlayerX ? game.xDeadline : game.oDeadline,
                        remainingMs: isPlayerX
                            ? game.xTimeRemainingMs
                            : game.oTimeRemainingMs,
                        piece: isPlayerX ? 'X' : 'O',
                        isActive: game.status == 'playing' &&
                            game.turn == (isPlayerX ? game.playerX : game.playerO),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Turn indicator
                _TurnIndicator(
                  status: game.status,
                  isMyTurn: isMyTurn,
                  winner: game.winner,
                  myUserId: myUserId,
                ),
                const SizedBox(height: 24),
                // Game board
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: GameBoard(
                    board: game.board,
                    xMoves: game.xMoves,
                    oMoves: game.oMoves,
                    myPiece: myPiece,
                    isMyTurn: isMyTurn,
                    status: game.status,
                    onCellTap: (index) {
                      ref.read(gameProvider(gameId).notifier).makeMove(index);
                    },
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog(
      BuildContext context, GameState game, String myUserId) {
    final isWin = game.winner == myUserId;
    final isDraw = game.status == 'draw';
    final isTimeout = game.finishReason == 'timeout';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDraw
                    ? Icons.handshake
                    : isTimeout
                        ? Icons.timer_off
                        : isWin
                            ? Icons.emoji_events
                            : Icons.sentiment_dissatisfied,
                color: isDraw
                    ? AppColors.draw
                    : isWin
                        ? AppColors.win
                        : AppColors.loss,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isDraw
                    ? 'DRAW!'
                    : isTimeout
                        ? (isWin ? 'OPPONENT TIMED OUT' : "TIME'S UP!")
                        : isWin
                            ? 'YOU WIN!'
                            : 'YOU LOSE',
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                      color: isDraw
                          ? AppColors.draw
                          : isWin
                              ? AppColors.win
                              : AppColors.loss,
                      fontSize: isTimeout ? 18 : null,
                    ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/menu');
                },
                child: const Text('BACK TO MENU'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final String status;
  final bool isMyTurn;
  final String? winner;
  final String myUserId;

  const _TurnIndicator({
    required this.status,
    required this.isMyTurn,
    required this.winner,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'won') {
      final didWin = winner == myUserId;
      return Text(
        didWin ? 'You Won!' : 'You Lost',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: didWin ? AppColors.win : AppColors.loss,
        ),
      );
    }
    if (status == 'draw') {
      return const Text(
        "It's a Draw!",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.draw,
        ),
      );
    }

    return Text(
      isMyTurn ? 'YOUR TURN' : "OPPONENT'S TURN",
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isMyTurn ? AppColors.playerX : AppColors.textMuted,
      ),
    );
  }
}
