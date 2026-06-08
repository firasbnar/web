import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../widgets/app_back_button.dart';
import 'package:easy_localization/easy_localization.dart';

class AddEditProductScreen extends StatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});
  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _comparePriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _colorsCtrl = TextEditingController();
  final _sizesCtrl = TextEditingController();
  String? _categoryId;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _saving = false;
  final QuillController _quillCtrl = QuillController.basic();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = [];

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique == null && bp.boutiques.isEmpty) {
      await bp.loadBoutiques();
    }
    if (!mounted) return;
    final boutiqueId = bp.activeBoutique?.id;
    if (boutiqueId != null) {
      context.read<ProductsProvider>().loadCategories(boutiqueId);
    }
    if (isEditing) {
      final pp = context.read<ProductsProvider>();
      final product = _findLoadedProduct(pp, widget.productId!);
      if (product != null) {
        _fillForm(product);
      } else if (widget.productId != null) {
        final fetched = await pp.getProduct(widget.productId!);
        if (mounted && fetched != null) _fillForm(fetched);
      }
    }
  }

  void _fillForm(Product product) {
    _nameCtrl.text = product.name;
    _qtyCtrl.text = product.stock.toString();
    _purchasePriceCtrl.text = product.purchasePrice?.toString() ?? '';
    _comparePriceCtrl.text = product.comparePrice?.toString() ?? '';
    _sellingPriceCtrl.text = product.price.toString();
    _categoryId = product.categoryId;
    _colorsCtrl.text = product.colors ?? '';
    _sizesCtrl.text = product.sizes ?? '';
    _uploadedImageUrls = List.from(product.images);
    if (_quillCtrl.document.toPlainText().trim().isEmpty) {
      final descriptionHtml = product.descriptionHtml;
      final description = product.description ?? '';
      if (descriptionHtml != null && descriptionHtml.isNotEmpty) {
        try {
          final delta = jsonDecode(descriptionHtml) as List<dynamic>;
          _quillCtrl.document = Document.fromJson(delta);
        } catch (_) {
          if (description.isNotEmpty) {
            _quillCtrl.document.insert(0, description);
          }
        }
      } else if (description.isNotEmpty) {
        _quillCtrl.document.insert(0, description);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _comparePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _colorsCtrl.dispose();
    _sizesCtrl.dispose();
    _quillCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    setState(() {
      _selectedImages.addAll(picked);
      _isUploading = true;
      _uploadProgress = 0;
    });
    try {
      final total = picked.length;
      int done = 0;
      for (final img in picked) {
        try {
          final url = await ApiClient.uploadImage(img);
          _uploadedImageUrls.add(url);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${'common.error'.tr()} ${img.name}: $e'),
              backgroundColor: AppColors.danger,
            ));
          }
        }
        done++;
        if (!mounted) return;
        setState(() => _uploadProgress = done / total);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      }
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('common.upload'.tr()),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    setState(() => _saving = true);
    final bp = context.read<BoutiqueProvider>();
    final pp = context.read<ProductsProvider>();
    final boutiqueId = bp.activeBoutique?.id;
    if (boutiqueId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr())),
        );
      }
      setState(() => _saving = false);
      return;
    }

    double? price;
    try {
      price = double.parse(_sellingPriceCtrl.text.trim());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
      setState(() => _saving = false);
      return;
    }

    final data = <String, dynamic>{
      'boutiqueId': boutiqueId,
      'categoryId': _categoryId,
      'name': _nameCtrl.text.trim(),
      'description': _quillCtrl.document.toPlainText(),
      'descriptionHtml': jsonEncode(_quillCtrl.document.toDelta().toJson()),
      'price': price,
      'comparePrice': _comparePriceCtrl.text.isNotEmpty
          ? double.tryParse(_comparePriceCtrl.text.trim()) : null,
      'purchasePrice': _purchasePriceCtrl.text.isNotEmpty
          ? double.tryParse(_purchasePriceCtrl.text.trim()) : null,
      'stock': int.tryParse(_qtyCtrl.text.trim()) ?? 0,
      'colors': _colorsCtrl.text.trim(),
      'sizes': _sizesCtrl.text.trim(),
      'images': jsonEncode(_uploadedImageUrls),
      'isActive': true,
      'isFeatured': false,
    };

    try {
      Product? product;
      if (isEditing) {
        product = await pp.updateProduct(widget.productId!, data);
      } else {
        product = await pp.createProduct(data);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      if (!context.mounted) return;
      if (product != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEditing ? 'products.product_updated'.tr() : 'products.product_created'.tr()),
          backgroundColor: AppColors.success,
        ));
        if (!context.mounted) return;
          context.pop();
        } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pp.error ?? 'common.operation_failed'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${'common.error'.tr()}: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductsProvider>().categories;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_button_unchecked, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(isEditing ? 'products.edit_product'.tr() : 'products.add_product'.tr()),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE4E2F5), height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth, maxWidth: constraints.maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('products.product_details'.tr()),
                    const SizedBox(height: 16),
                    _buildLabel('products.product_name'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration(hint: 'products.product_name'.tr()),
                      validator: (v) => v?.isEmpty == true ? 'common.required'.tr() : null,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('products.stock'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(hint: 'products.stock'.tr()),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('products.price'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _purchasePriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(hint: 'products.price'.tr()),
                    ),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('products.compare_price'.tr()),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _comparePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(hint: 'products.compare_price'.tr()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('products.price'.tr()),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _sellingPriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecoration(hint: 'products.price'.tr()),
                                  validator: (v) {
                                    if (v?.isEmpty == true) return 'common.required'.tr();
                                    if (double.tryParse(v!.trim()) == null) return 'common.error'.tr();
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('products.category'.tr()),
                    const SizedBox(height: 6),
                    InputDecorator(
                      decoration: _inputDecoration(hint: 'products.select_category'.tr()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoryId,
                          isExpanded: true,
                          isDense: true,
                          hint: Text('products.select_category'.tr(),
                              style: const TextStyle(color: Color(0xFF9B97B8), fontSize: 14)),
                          items: categories
                              .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('products.product_description'.tr()),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE4E2F5)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          QuillSimpleToolbar(
                            controller: _quillCtrl,
                            config: const QuillSimpleToolbarConfig(
                              showBoldButton: true,
                              showItalicButton: true,
                              showUnderLineButton: true,
                              showStrikeThrough: true,
                              showColorButton: true,
                              showHeaderStyle: true,
                              showListNumbers: true,
                              showListBullets: true,
                              showQuote: true,
                              showIndent: true,
                              showAlignmentButtons: true,
                              showLink: true,
                              showSearchButton: true,
                              multiRowsDisplay: false,
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minHeight: 200),
                            padding: const EdgeInsets.all(12),
                            child: QuillEditor.basic(
                              controller: _quillCtrl,
                              config: QuillEditorConfig(
                                placeholder: 'products.product_description'.tr(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('products.variants'.tr()),
                    const SizedBox(height: 16),
                    _buildLabel('products.colors'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _colorsCtrl,
                      decoration: _inputDecoration(hint: 'products.colors'.tr()),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('products.sizes'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _sizesCtrl,
                      decoration: _inputDecoration(hint: 'products.sizes'.tr()),
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader('products.images'.tr()),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isUploading ? null : _pickImages,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.surfaceAlt,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _isUploading ? Icons.cloud_upload : Icons.add_photo_alternate_outlined,
                              size: 40, color: AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isUploading ? 'common.upload'.tr() : 'products.images'.tr(),
                              style: AppTypography.body2.copyWith(color: AppColors.textHint),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'products.images'.tr(),
                              style: AppTypography.caption.copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 4),
                      Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: AppTypography.caption),
                    ],
                    const SizedBox(height: 8),
                    if (_uploadedImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...List.generate(_uploadedImageUrls.length, (i) {
                              return _imageThumbnail(i);
                            }),
                            GestureDetector(
                              onTap: _isUploading ? null : _pickImages,
                              child: Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border, width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.surfaceAlt,
                                ),
                                child: const Icon(Icons.add_photo_alternate_outlined,
                                    color: AppColors.primary, size: 28),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save, size: 16),
                        label: Text(isEditing ? 'common.save'.tr() : 'products.add_product'.tr()),
                        onPressed: (_saving || _isUploading) ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withAlpha(100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _imageThumbnail(int index) {
    final url = index < _uploadedImageUrls.length ? _uploadedImageUrls[index] : null;
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.surfaceAlt,
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url.isNotEmpty
              ? Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.broken_image, color: AppColors.textHint),
                  ))
              : const Icon(Icons.broken_image, color: AppColors.textHint),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.danger,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Product? _findLoadedProduct(ProductsProvider provider, String id) {
    for (final product in provider.products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E2F5))),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F0A2E)),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F0A2E)));
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9B97B8), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE4E2F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE4E2F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
