/// Display-only helpers for the game UI.
/// All authoritative game logic lives in the Postgres RPCs.
class GameLogic {
  GameLogic._();

  /// Returns the index of the oldest move that would be removed
  /// if the player places a new piece (4th move → removes 1st).
  static int? oldestMoveToRemove(List<int> playerMoves) {
    if (playerMoves.length >= 3) {
      return playerMoves.first;
    }
    return null;
  }

  /// Check if it's the current user's turn.
  static bool isMyTurn(String? turn, String myUserId) {
    return turn == myUserId;
  }

  /// Get the piece type ('X' or 'O') for a given user in the game.
  static String? getPieceForUser(
      String userId, String playerX, String playerO) {
    if (userId == playerX) return 'X';
    if (userId == playerO) return 'O';
    return null;
  }

  static const List<List<int>> winPatterns = [
    [0, 1, 2], // rows
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6], // columns
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8], // diagonals
    [2, 4, 6],
  ];

  /// Returns the winning line indices if there is a winner, null otherwise.
  /// Used for highlighting the winning line on the board.
  static List<int>? getWinningLine(List<dynamic> board) {
    for (final pattern in winPatterns) {
      final a = board[pattern[0]];
      final b = board[pattern[1]];
      final c = board[pattern[2]];
      if (a != null && a == b && b == c) {
        return pattern;
      }
    }
    return null;
  }
}
