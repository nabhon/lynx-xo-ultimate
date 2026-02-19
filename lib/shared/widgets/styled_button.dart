import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StyledButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isPrimary;

  const StyledButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.background,
            ),
          )
        : Text(label);

    if (isPrimary) {
      return icon != null
          ? ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Icon(icon),
              label: child,
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              child: child,
            );
    }

    return icon != null
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon),
            label: child,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          );
  }
}
