import 'package:flutter/material.dart';

import '../../domain/game_logic.dart';
import 'game_cell.dart';

class GameBoard extends StatelessWidget {
  final List<dynamic> board;
  final List<dynamic> xMoves;
  final List<dynamic> oMoves;
  final String? myPiece; // 'X' or 'O'
  final bool isMyTurn;
  final String status;
  final ValueChanged<int>? onCellTap;

  const GameBoard({
    super.key,
    required this.board,
    required this.xMoves,
    required this.oMoves,
    required this.myPiece,
    required this.isMyTurn,
    required this.status,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final winLine = status == 'won' ? GameLogic.getWinningLine(board) : null;

    // Determine which cell has the oldest piece that will be removed next
    final int? oldestXCell =
        xMoves.length >= 3 ? (xMoves.first as int) : null;
    final int? oldestOCell =
        oMoves.length >= 3 ? (oMoves.first as int) : null;

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final cellValue = board[index];
          final isWinCell = winLine?.contains(index) ?? false;

          // A cell's piece is "oldest" if it's the next to be removed
          // when that player makes their next move
          bool isOldest = false;
          if (status == 'playing') {
            if (cellValue == 'X' && index == oldestXCell) {
              isOldest = true;
            } else if (cellValue == 'O' && index == oldestOCell) {
              isOldest = true;
            }
          }

          return GameCell(
            value: cellValue,
            isOldest: isOldest,
            isWinningCell: isWinCell,
            enabled: isMyTurn && status == 'playing',
            onTap: () => onCellTap?.call(index),
          );
        },
      ),
    );
  }
}
