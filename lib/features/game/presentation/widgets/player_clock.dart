import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class PlayerClock extends StatefulWidget {
  final DateTime? deadline;
  final int remainingMs;
  final String piece; // 'X' or 'O'
  final bool isActive;

  const PlayerClock({
    super.key,
    required this.deadline,
    required this.remainingMs,
    required this.piece,
    required this.isActive,
  });

  @override
  State<PlayerClock> createState() => _PlayerClockState();
}

class _PlayerClockState extends State<PlayerClock> {
  Timer? _ticker;
  int _displayMs = 0;

  @override
  void initState() {
    super.initState();
    _updateDisplay();
    _startTicker();
  }

  @override
  void didUpdateWidget(PlayerClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline ||
        oldWidget.remainingMs != widget.remainingMs ||
        oldWidget.isActive != widget.isActive) {
      _updateDisplay();
      _startTicker();
    }
  }

  void _updateDisplay() {
    if (widget.isActive && widget.deadline != null) {
      final remaining =
          widget.deadline!.difference(DateTime.now().toUtc()).inMilliseconds;
      _displayMs = remaining.clamp(0, widget.remainingMs);
    } else {
      _displayMs = widget.remainingMs;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (widget.isActive && widget.deadline != null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        final remaining =
            widget.deadline!.difference(DateTime.now().toUtc()).inMilliseconds;
        setState(() {
          _displayMs = remaining.clamp(0, widget.remainingMs);
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '0:00';
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pieceColor =
        widget.piece == 'X' ? AppColors.playerX : AppColors.playerO;
    final isLow = _displayMs < 10000; // under 10 seconds
    final displayColor = isLow ? AppColors.loss : pieceColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive ? displayColor : AppColors.textMuted,
          width: widget.isActive ? 2 : 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: displayColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.piece,
            style: TextStyle(
              color: widget.isActive ? pieceColor : AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(_displayMs),
            style: TextStyle(
              color: widget.isActive ? displayColor : AppColors.textMuted,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
