import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../utils/format_utils.dart';

class CartScreen extends StatefulWidget {
  final String boutiqueId;
  const CartScreen({super.key, required this.boutiqueId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart(widget.boutiqueId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('cart.title'.tr()),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) => cart.items.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _clearCart(cart),
                  )
                : const SizedBox(),
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (_, cart, __) {
          if (cart.loading && cart.items.isEmpty) return const LoadingSkeleton();
          if (cart.error != null && cart.items.isEmpty) return ErrorState(message: cart.error!, onRetry: () => cart.loadCart(widget.boutiqueId));
          if (cart.items.isEmpty) return EmptyState(title: 'cart.empty'.tr(), icon: Icons.shopping_cart_outlined);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CartItemCard(
                    item: cart.items[i],
                    onIncrement: () => cart.updateItem(cart.items[i].id!, cart.items[i].quantity + 1),
                    onDecrement: () {
                      if (cart.items[i].quantity > 1) {
                        cart.updateItem(cart.items[i].id!, cart.items[i].quantity - 1);
                      }
                    },
                    onRemove: () => cart.removeItem(cart.items[i].id!),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('cart.subtotal'.tr(), style: AppTypography.caption),
                            Text(FormatUtils.money(context, cart.subtotal, currencyCode: 'TND'), style: AppTypography.heading3),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'cart.checkout'.tr(),
                        onPressed: () => context.go('/checkout/${widget.boutiqueId}'),
                        fullWidth: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clearCart(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cart.clear_cart'.tr()),
        content: Text('cart.clear_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () { Navigator.pop(ctx); cart.clearCart(widget.boutiqueId); },
            child: Text('cart.clear_cart'.tr(), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemCard({required this.item, required this.onIncrement, required this.onDecrement, required this.onRemove});

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
                  ? Image.network(item.productImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textHint))
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
                  FormatUtils.money(context, item.unitPrice, currencyCode: 'TND'),
                  style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onDecrement,
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.remove, size: 18)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(item.quantity.toString(), style: AppTypography.body2),
                ),
                InkWell(
                  onTap: onIncrement,
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add, size: 18)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
