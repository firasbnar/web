import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/url_utils.dart';
import '../../providers/public_cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PublicCartScreen extends StatefulWidget {
  final String slug;
  const PublicCartScreen({super.key, required this.slug});
  @override
  State<PublicCartScreen> createState() => _PublicCartScreenState();
}

class _PublicCartScreenState extends State<PublicCartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicCartProvider>().loadCart(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PublicCartProvider>();
    final items = cart.items(widget.slug);
    final total = cart.subtotal(widget.slug);
    final count = cart.itemCount(widget.slug);

    return Scaffold(
      appBar: AppBar(
        title: Text('Panier ($count)', style: AppTypography.heading3),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Votre panier est vide', style: AppTypography.heading3),
                  const SizedBox(height: 8),
                  Text('Parcourez la boutique pour ajouter des articles.', style: AppTypography.caption),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/store/${widget.slug}'),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                    child: const Text('Voir la boutique'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final img = item.image;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            if (img != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(resolveImageUrl(img)!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: AppColors.surfaceAlt, child: const Icon(Icons.image, color: AppColors.textHint))),
                              )
                            else
                              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: AppColors.textHint)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('${item.effectivePrice.toStringAsFixed(3)} TND', style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => cart.updateQuantity(widget.slug, item.productId, item.quantity - 1),
                                              child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16)),
                                            ),
                                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${item.quantity}', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600))),
                                            InkWell(
                                              onTap: item.quantity < item.stock ? () => cart.updateQuantity(widget.slug, item.productId, item.quantity + 1) : null,
                                              child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add, size: 16, color: item.quantity >= item.stock ? Colors.grey : null)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => cart.removeItem(widget.slug, item.productId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sous-total', style: AppTypography.body1),
                            Text('${total.toStringAsFixed(3)} TND', style: AppTypography.heading3),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                            onPressed: () => context.push('/store/${widget.slug}/checkout'),
                            child: Text('Commander', style: AppTypography.button),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
