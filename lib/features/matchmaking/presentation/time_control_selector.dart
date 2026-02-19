import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../domain/time_control.dart';

class TimeControlSelectorDialog extends StatelessWidget {
  const TimeControlSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TIME CONTROL',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose time per player',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            for (final tc in TimeControl.values) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(tc),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tc == TimeControl.oneMinute
                        ? AppColors.playerX
                        : AppColors.playerO,
                    side: BorderSide(
                      color: tc == TimeControl.oneMinute
                          ? AppColors.playerX
                          : AppColors.playerO,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(tc.label),
                ),
              ),
              if (tc != TimeControl.values.last) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
