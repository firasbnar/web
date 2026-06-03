import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_skeleton.dart';
import '../../providers/pos_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/boutique_provider.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _showCart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.currentBoutique != null) {
        context.read<ProductsProvider>().loadProducts(bp.currentBoutique!.id, refresh: true);
        context.read<PosProvider>().loadActiveSession(bp.currentBoutique!.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showOpenSessionDialog() {
    final cashCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ouvrir session POS'),
        content: TextField(
          controller: cashCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montant caisse (TND)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final bp = context.read<BoutiqueProvider>();
              if (bp.currentBoutique != null) {
                context.read<PosProvider>().openSession(
                  bp.currentBoutique!.id,
                  double.tryParse(cashCtrl.text) ?? 0,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }

  void _confirmSale() async {
    final pp = context.read<PosProvider>();
    if (pp.cartItems.isEmpty) return;
    if (pp.activeSession == null) {
      _showOpenSessionDialog();
      return;
    }
    final items = pp.cartItems.map((p) => {
      'productId': p.id,
      'productName': p.name,
      'unitPrice': p.price,
      'quantity': 1,
    }).toList();

    final result = await pp.createTransaction(
      pp.activeSession!['id'],
      items,
      _paymentMethod,
      pp.cartTotal,
    );
    if (result != null && mounted) {
      pp.clearCart();
      if (mounted) _showReceipt(result);
    }
  }

  void _showReceipt(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 60),
            const SizedBox(height: 16),
            Text('Vente confirmée!', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text('Total: ${(transaction['total'] ?? 0).toStringAsFixed(2)} TND', style: AppTypography.heading3.copyWith(color: AppColors.primary)),
            const SizedBox(height: 20),
            AppButton(label: 'Nouvelle vente', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PosProvider>();
    final pr = context.watch<ProductsProvider>();
    final hasSession = pp.activeSession != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Point de vente'),
        actions: [
          if (!hasSession)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _showOpenSessionDialog,
              tooltip: 'Ouvrir session',
            )
          else
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                final closeCtrl = TextEditingController();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Fermer session'),
                    content: TextField(
                      controller: closeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Clôture caisse (TND)'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () {
                          pp.closeSession(pp.activeSession!['id'], double.tryParse(closeCtrl.text) ?? 0);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Fermer session',
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasSession)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.success.withAlpha(20),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Session ouverte', style: AppTypography.caption.copyWith(color: AppColors.success)),
                  const Spacer(),
                  Text('${pp.cartItems.length} article(s)', style: AppTypography.caption),
                ],
              ),
            ),
          if (_showCart)
            Expanded(
              child: _buildCartSection(pp),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un produit...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.shopping_cart),
                          onPressed: () => setState(() => _showCart = true),
                        ),
                      ),
                      onChanged: (v) {
                        final bp = context.read<BoutiqueProvider>();
                        if (bp.currentBoutique != null) {
                          context.read<ProductsProvider>().setSearch(v, bp.currentBoutique!.id);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: pr.loading
                        ? const LoadingSkeleton(isGrid: true)
                        : LayoutBuilder(
                            builder: (_, constraints) => GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: constraints.maxWidth > 600 ? 4 : constraints.maxWidth > 400 ? 3 : 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: pr.products.length,
                            itemBuilder: (_, i) {
                              final product = pr.products[i];
                              return GestureDetector(
                                onTap: () => pp.addToCart(product),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(product.name, style: AppTypography.caption, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('${product.price.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: pp.cartItems.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pp.cartItems.length} article(s)', style: AppTypography.caption),
                              Text('${pp.cartTotal.toStringAsFixed(2)} TND', style: AppTypography.heading3.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ),
                        AppButton(
                          label: 'Voir panier',
                          fullWidth: false,
                          onPressed: () => setState(() => _showCart = !_showCart),
                        ),
                      ],
                    ),
                  )
                : null,
          );
        }

  Widget _buildCartSection(PosProvider pp) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pp.cartItems.length,
            itemBuilder: (_, i) {
              final product = pp.cartItems[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: AppTypography.body2),
                          Text('${product.price.toStringAsFixed(2)} TND', style: AppTypography.body2.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                      onPressed: () => pp.removeFromCart(i),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                items: ['Cash', 'Carte', 'D17'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                decoration: const InputDecoration(labelText: 'Moyen de paiement'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: AppTypography.heading3),
                  Text('${pp.cartTotal.toStringAsFixed(2)} TND', style: AppTypography.heading2.copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(label: 'Confirmer la vente', loading: pp.loading, onPressed: _confirmSale),
            ],
          ),
        ),
      ],
    );
  }
}
