import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _api = ApiClient();
  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  String? get _boutiqueId => context.read<BoutiqueProvider>().currentBoutique?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  Future<void> _loadProducts() async {
    final bid = _boutiqueId;
    if (bid == null) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/products', queryParameters: {'boutiqueId': bid, 'page': 0, 'size': 100});
      final data = res['data'];
      final content = data?['content'] ?? [];
      _products = (content as List).map((e) => Product.fromJson(e)).toList();
      _products.sort((a, b) => a.stock.compareTo(b.stock));
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    setState(() => _loading = false);
  }

  Future<void> _editStock(Product product) async {
    final ctrl = TextEditingController(text: product.stock.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'inventory.stock'.tr(), border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (result != null && result >= 0) {
      try {
        await _api.put('/products/${product.id}/stock', data: {'stock': result});
        await _loadProducts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e'), backgroundColor: AppColors.danger));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackArrow(), title: Text('inventory.title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadProducts)
              : _products.isEmpty
                  ? EmptyState(title: 'inventory.title'.tr(), subtitle: 'inventory.update_stock'.tr())
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (_, i) => _inventoryItem(_products[i]),
                      ),
                    ),
    );
  }

  Widget _inventoryItem(Product product) {
    final isLow = product.stock <= 10;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLow ? AppColors.warning : AppColors.border),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48, height: 48,
            color: AppColors.surfaceAlt,
            child: product.images.isNotEmpty
                ? Image.network(product.images.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24, color: AppColors.textHint))
                : const Icon(Icons.image, size: 24, color: AppColors.textHint),
          ),
        ),
        title: Text(product.name, style: AppTypography.body2, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(product.sku ?? 'inventory.sku'.tr(), style: AppTypography.caption),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLow ? AppColors.warning.withAlpha(30) : AppColors.success.withAlpha(30),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${product.stock}',
                style: AppTypography.body2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isLow ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editStock(product),
            ),
          ],
        ),
      ),
    );
  }
}
