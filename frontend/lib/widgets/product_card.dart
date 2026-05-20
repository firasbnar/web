import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onToggleActive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: AppColors.surfaceAlt,
                child: product.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(Icons.image, color: AppColors.textHint, size: 40),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint, size: 32),
                        ),
                      )
                    : const Icon(Icons.image, color: AppColors.textHint, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: AppTypography.body2, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${product.price.toStringAsFixed(2)} TND', style: AppTypography.heading4.copyWith(color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.stock > 0 ? AppColors.success.withAlpha(30) : AppColors.danger.withAlpha(30),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          product.stock > 0 ? '${product.stock} en stock' : 'Rupture',
                          style: TextStyle(fontSize: 10, color: product.stock > 0 ? AppColors.success : AppColors.danger),
                        ),
                      ),
                      const Spacer(),
                      if (onToggleActive != null)
                        IconButton(
                          onPressed: onToggleActive,
                          icon: Icon(
                            product.isActive ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                            color: product.isActive ? AppColors.primary : AppColors.textHint,
                          ),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          splashRadius: 18,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
