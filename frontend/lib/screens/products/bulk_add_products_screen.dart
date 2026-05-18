import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/api_client.dart';
import '../../providers/products_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../models/product.dart';

class ProductFormData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController comparePriceCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController colorsCtrl = TextEditingController();
  final TextEditingController sizesCtrl = TextEditingController();
  final TextEditingController descriptionCtrl = TextEditingController();
  String? categoryId;
  List<String> imageUrls = [];

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    comparePriceCtrl.dispose();
    qtyCtrl.dispose();
    colorsCtrl.dispose();
    sizesCtrl.dispose();
    descriptionCtrl.dispose();
  }
}

class BulkAddProductsScreen extends StatefulWidget {
  const BulkAddProductsScreen({super.key});
  @override
  State<BulkAddProductsScreen> createState() => _BulkAddProductsScreenState();
}

class _BulkAddProductsScreenState extends State<BulkAddProductsScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<ProductFormData> _products = [ProductFormData()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().loadCategories(
          context.read<BoutiqueProvider>().activeBoutique?.id ?? '');
    });
  }

  @override
  void dispose() {
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  void _addAnotherProduct() {
    setState(() => _products.add(ProductFormData()));
  }

  void _removeProduct(int index) {
    if (_products.length > 1) {
      _products[index].dispose();
      setState(() => _products.removeAt(index));
    }
  }

  Future<void> _pickImagesForProduct(int index) async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() => _isUploadingForIndex.add(index));
    try {
      final futures = picked.map((img) => ApiClient.uploadImage(img));
      final urls = await Future.wait(futures);
      _products[index].imageUrls.addAll(urls);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: ${ApiClient.extractErrorMessage(e)}'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _isUploadingForIndex.remove(index));
    }
  }

  final Set<int> _isUploadingForIndex = {};

  Future<void> _saveAllProducts() async {
    setState(() => _saving = true);
    final bp = context.read<BoutiqueProvider>();
    final pp = context.read<ProductsProvider>();
    final boutiqueId = bp.activeBoutique?.id;
    if (boutiqueId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune boutique sélectionnée')));
      }
      setState(() => _saving = false);
      return;
    }
    int successCount = 0;
    for (final p in _products) {
      if (p.nameCtrl.text.trim().isEmpty) continue;
      final data = {
        'boutiqueId': boutiqueId,
        'categoryId': p.categoryId,
        'name': p.nameCtrl.text.trim(),
        'description': p.descriptionCtrl.text.trim(),
        'price': double.tryParse(p.priceCtrl.text.trim()) ?? 0,
        'comparePrice': p.comparePriceCtrl.text.isNotEmpty
            ? double.tryParse(p.comparePriceCtrl.text.trim())
            : null,
        'stock': int.tryParse(p.qtyCtrl.text.trim()) ?? 0,
        'colors': p.colorsCtrl.text.trim(),
        'sizes': p.sizesCtrl.text.trim(),
        'images': jsonEncode(p.imageUrls),
      };
      final result = await pp.createProduct(data);
      if (result != null) successCount++;
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$successCount produit(s) créé(s)'),
        backgroundColor: AppColors.success));
    if (successCount > 0) {
      if (!context.mounted) return;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductsProvider>().categories;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ajout en Masse de Produits'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _products.length,
        itemBuilder: (ctx, index) => _ProductCard(
          index: index,
          data: _products[index],
          categories: categories,
          onDelete: () => _removeProduct(index),
          onPickImages: () => _pickImagesForProduct(index),
          isUploading: _isUploadingForIndex.contains(index),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Ajouter un Autre Produit'),
              onPressed: _addAnotherProduct,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Annuler'),
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
            ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Enregistrer Tous les Produits'),
              onPressed: _saving ? null : _saveAllProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final int index;
  final ProductFormData data;
  final List<Category> categories;
  final VoidCallback onDelete;
  final VoidCallback onPickImages;
  final bool isUploading;

  // ignore: prefer_const_constructors_in_immutables
  _ProductCard({
    required this.index,
    required this.data,
    required this.categories,
    required this.onDelete,
    required this.onPickImages,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('Produit #${index + 1}',
                    style: AppTypography.heading3
                        .copyWith(color: AppColors.primary)),
                const Spacer(),
                if (true) // always show delete
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Nom du Produit *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: data.nameCtrl,
                  decoration: _decoration(hint: 'T-shirts ...'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Catégorie *'),
                            const SizedBox(height: 6),
                            InputDecorator(
                              decoration: _decoration(
                                  hint: 'Choisir une catégorie'),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: data.categoryId,
                                  isExpanded: true,
                                  isDense: true,
                                  hint: const Text('Choisir une catégorie',
                                      style: TextStyle(
                                          color: Color(0xFF9B97B8),
                                          fontSize: 13)),
                                  items: categories
                                      .map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.name,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      data.categoryId = v,
                                ),
                              ),
                            ),
                          ],
                        )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Prix *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: data.priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _decoration(hint: '12'),
                        ),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Ancien Prix'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: data.comparePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(hint: '15'),
                        ),
                      ],
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Quantité'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: data.qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration(hint: '0'),
                        ),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Couleurs'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: data.colorsCtrl,
                          decoration: _decoration(hint: 'Rouge, Bleu, Vert'),
                        ),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tailles'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: data.sizesCtrl,
                          decoration: _decoration(hint: 'S, M, L, XL'),
                        ),
                      ],
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                _label('Description du Produit'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: data.descriptionCtrl,
                  maxLines: 3,
                  decoration: _decoration(hint: 'Description...'),
                ),
                const SizedBox(height: 12),
                _label('Images du Produit (Sélectionnez plusieurs images)'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onPickImages,
                      child: const Text('Sélect. fichiers'),
                    ),
                    Text(
                      data.imageUrls.isEmpty
                          ? 'Aucun fichier choisi'
                          : '${data.imageUrls.length} image(s)',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 4),
                const Text(
                    'Vous pouvez sélectionner plusieurs images à la fois',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F0A2E)));

  InputDecoration _decoration({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9B97B8), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE4E2F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE4E2F5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        isDense: true,
      );
}
