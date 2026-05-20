import 'package:flutter/material.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;
  final void Function(String)? onReply;

  const ReviewCard({
    super.key,
    required this.review,
    this.onApprove,
    this.onReject,
    this.onDelete,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    review.customerName.isNotEmpty
                        ? review.customerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.customerName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: AppColors.star,
                        )),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: review.status),
              ],
            ),
            if (review.productName != null) ...[
              const SizedBox(height: 8),
              Text('Produit: ${review.productName}', style: AppTypography.caption),
            ],
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment!, style: AppTypography.body2),
            ],
            const SizedBox(height: 4),
            Text(_formatDate(review.createdAt), style: AppTypography.caption.copyWith(color: AppColors.textHint)),
            if (review.ownerReply != null && review.ownerReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Votre réponse:', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(review.ownerReply!, style: AppTypography.body2),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (review.isPending) ...[
                  _ActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Approuver',
                    color: AppColors.success,
                    onTap: onApprove,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.cancel_outlined,
                    label: 'Rejeter',
                    color: AppColors.danger,
                    onTap: onReject,
                  ),
                ],
                if (onReply != null)
                  _ActionButton(
                    icon: Icons.reply_outlined,
                    label: 'Répondre',
                    color: AppColors.primary,
                    onTap: () => _showReplyDialog(context),
                  ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Supprimer',
                  color: AppColors.danger,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context) {
    final ctrl = TextEditingController(text: review.ownerReply ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Répondre à l\'avis'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Votre réponse...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              onReply?.call(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      'APPROVED' => (AppColors.success, 'Approuvé'),
      'REJECTED' => (AppColors.danger, 'Rejeté'),
      _ => (AppColors.warning, 'En attente'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: const Size(36, 36),
      ),
    );
  }
}
