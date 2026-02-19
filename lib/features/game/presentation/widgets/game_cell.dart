import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class GameCell extends StatelessWidget {
  final dynamic value; // 'X', 'O', or null
  final bool isOldest;
  final bool isWinningCell;
  final bool enabled;
  final VoidCallback? onTap;

  const GameCell({
    super.key,
    required this.value,
    this.isOldest = false,
    this.isWinningCell = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && value == null ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWinningCell
                ? AppColors.win.withValues(alpha: 0.8)
                : AppColors.surfaceLight.withValues(alpha: 0.5),
            width: isWinningCell ? 2 : 1,
          ),
          boxShadow: isWinningCell
              ? [
                  BoxShadow(
                    color: AppColors.win.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: value != null
              ? _PieceWidget(
                  piece: value as String,
                  isOldest: isOldest,
                )
              : null,
        ),
      ),
    );
  }
}

class _PieceWidget extends StatefulWidget {
  final String piece;
  final bool isOldest;

  const _PieceWidget({required this.piece, required this.isOldest});

  @override
  State<_PieceWidget> createState() => _PieceWidgetState();
}

class _PieceWidgetState extends State<_PieceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isOldest) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PieceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOldest && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isOldest && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.piece == 'X' ? AppColors.playerX : AppColors.playerO;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: widget.isOldest ? _opacity.value : 1.0,
          child: Text(
            widget.piece,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: color,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
