import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? debugMessage;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.debugMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.danger),
            const SizedBox(height: 20),
            Text('Une erreur est survenue', style: AppTypography.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppTypography.body2.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (debugMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withAlpha(80)),
                ),
                child: Text(debugMessage!,
                  style: AppTypography.caption.copyWith(color: AppColors.warning, fontSize: 11),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
