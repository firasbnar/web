import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final bool fullWidth;
  final Color? color;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.fullWidth = true,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (loading) {
      child = const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: outlined ? AppColors.primary : Colors.white),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.button.copyWith(
            color: outlined ? AppColors.primary : Colors.white,
          )),
        ],
      );
    } else {
      child = Text(label, style: AppTypography.button.copyWith(
        color: outlined ? AppColors.primary : Colors.white,
      ));
    }

    final Widget button = outlined
        ? OutlinedButton(
            onPressed: loading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              side: BorderSide(color: color ?? AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 50),
              backgroundColor: color ?? AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withAlpha(100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: child,
          );

    if (!fullWidth) return button;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (MediaQuery.maybeOf(context)?.size.width ?? 400);
        return SizedBox(width: width < 50 ? 400 : width, height: 50, child: button);
      },
    );
  }
}
