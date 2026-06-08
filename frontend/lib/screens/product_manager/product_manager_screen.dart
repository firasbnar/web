import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../widgets/app_button.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductManagerScreen extends StatefulWidget {
  final String? productId;
  const ProductManagerScreen({super.key, this.productId});
  @override
  State<ProductManagerScreen> createState() => _ProductManagerScreenState();
}

class _ProductManagerScreenState extends State<ProductManagerScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _variants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    if (widget.productId == null) { setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final res = await _api.get('/products/${widget.productId}/variants');
      _variants = (res['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _showVariantDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing?['stock']?.toString() ?? '');
    final skuCtrl = TextEditingController(text: existing?['sku'] ?? '');
    final orderCtrl = TextEditingController(text: existing?['sortOrder']?.toString() ?? '');

    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing != null ? 'products.edit_product'.tr() : 'products.add_variant'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'products.product_name'.tr(), hintText: 'products.product_name'.tr(), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl, decoration: InputDecoration(labelText: 'products.price'.tr(), border: const OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: stockCtrl, decoration: InputDecoration(labelText: 'products.stock'.tr(), border: const OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: skuCtrl, decoration: InputDecoration(labelText: 'products.sku'.tr(), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: orderCtrl, decoration: InputDecoration(labelText: 'Ordre'.tr(), border: const OutlineInputBorder()), keyboardType: TextInputType.number),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
        AppButton(label: 'common.save'.tr(), onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          final data = <String, dynamic>{
            'name': nameCtrl.text.trim(),
            'price': double.tryParse(priceCtrl.text),
            'stock': int.tryParse(stockCtrl.text),
            'sku': skuCtrl.text.trim().isNotEmpty ? skuCtrl.text.trim() : null,
            'sortOrder': int.tryParse(orderCtrl.text) ?? 0,
          };
          try {
            if (existing != null) {
              await _api.put('/products/${widget.productId}/variants/${existing['id']}', data: data);
            } else {
              await _api.post('/products/${widget.productId}/variants', data: data);
            }
            Navigator.pop(ctx, true);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e'), backgroundColor: AppColors.danger));
          }
        }),
      ],
    ));
    if (saved == true) _loadVariants();
  }

  Future<void> _deleteVariant(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('common.confirm_delete'.tr()),
      content: Text('products.delete_confirm'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.delete'.tr(), style: const TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) {
      try { await _api.delete('/products/${widget.productId}/variants/$id'); _loadVariants(); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e'), backgroundColor: AppColors.danger)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('products.variant_manager'.tr()),
        actions: [
          if (widget.productId != null)
            IconButton(icon: const Icon(Icons.add), onPressed: () => _showVariantDialog()),
        ],
      ),
      body: widget.productId == null
          ? Center(child: Text('products.all_products'.tr()))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _variants.isEmpty
                  ? Center(child: Text('products.no_products'.tr()))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _variants.length,
                      onReorder: (oldI, newI) async {
                        setState(() {
                          final item = _variants.removeAt(oldI);
                          _variants.insert(newI, item);
                        });
                        for (var i = 0; i < _variants.length; i++) {
                          try {
                            await _api.put('/products/${widget.productId}/variants/${_variants[i]['id']}', data: {'sortOrder': i, 'name': _variants[i]['name']});
                          } catch (_) {}
                        }
                      },
                      itemBuilder: (_, i) {
                        final v = _variants[i];
                        return Container(
                          key: ValueKey(v['id']),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_handle, color: AppColors.textHint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v['name'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: [
                                        if (v['price'] != null) Text('${v['price'].toString()} TND', style: AppTypography.caption),
                                        if (v['stock'] != null) ...[
                                          if (v['price'] != null) Text(' · ', style: AppTypography.caption),
                                          Flexible(child: Text('Stock: ${v['stock']}', style: AppTypography.caption.copyWith(color: (v['stock'] as num) <= 5 ? AppColors.danger : AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                                        ],
                                        if (v['sku'] != null) ...[
                                          Text(' · ', style: AppTypography.caption),
                                          Flexible(child: Text('SKU: ${v['sku']}', style: AppTypography.caption, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showVariantDialog(existing: v), visualDensity: VisualDensity.compact),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger), onPressed: () => _deleteVariant(v['id']), visualDensity: VisualDensity.compact),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
