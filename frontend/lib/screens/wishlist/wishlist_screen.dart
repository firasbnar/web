import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/app_back_arrow.dart';
import '../../models/wishlist_item.dart';
import '../../utils/format_utils.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('wishlist.title'.tr()),
      ),
      body: Consumer<WishlistProvider>(
        builder: (_, wl, __) {
          if (wl.loading && wl.items.isEmpty) return const LoadingSkeleton();
          if (wl.error != null && wl.items.isEmpty) return ErrorState(message: wl.error!, onRetry: () => wl.loadWishlist());
          if (wl.items.isEmpty) return EmptyState(title: 'wishlist.empty'.tr(), icon: Icons.favorite_border);
          return RefreshIndicator(
            onRefresh: () => wl.loadWishlist(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: wl.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _WishlistCard(item: wl.items[i], onRemove: () => wl.toggle(wl.items[i].productId!)),
            ),
          );
        },
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final WishlistItem item;
  final VoidCallback onRemove;

  const _WishlistCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 72, height: 72,
              color: AppColors.surfaceAlt,
              child: item.productImage != null
                  ? Image.network(item.productImage!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textHint))
                  : const Icon(Icons.image, color: AppColors.textHint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName ?? '', style: AppTypography.body2, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  FormatUtils.money(context, item.price, currencyCode: 'TND'),
                  style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                if (item.boutiqueName != null)
                  Text(item.boutiqueName!, style: AppTypography.caption.copyWith(color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.favorite, color: AppColors.danger),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
