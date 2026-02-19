import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label);

    if (outlined) {
      return icon != null
          ? OutlinedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: Icon(icon, size: 16),
              label: child,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                side: foregroundColor != null
                    ? BorderSide(color: foregroundColor!)
                    : null,
              ),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                side: foregroundColor != null
                    ? BorderSide(color: foregroundColor!)
                    : null,
              ),
              child: child,
            );
    }

    return icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon, size: 16),
            label: child,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
            child: child,
          );
  }
}
