import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../utils/image_utils.dart';
import '../../providers/public_cart_provider.dart';
import '../../providers/public_wishlist_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

class PublicProductDetailScreen extends StatefulWidget {
  final String slug;
  final String productId;
  const PublicProductDetailScreen({super.key, required this.slug, required this.productId});
  @override
  State<PublicProductDetailScreen> createState() => _PublicProductDetailScreenState();
}

class _PublicProductDetailScreenState extends State<PublicProductDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _product;
  bool _loading = true;
  String? _error;
  int _quantity = 1;
  int _currentImage = 0;
  String? _selectedColor;
  String? _selectedSize;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int _totalReviews = 0;
  bool _reviewsLoading = false;
  bool _reviewSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicWishlistProvider>().loadWishlist(widget.slug);
    });
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/public/stores/${widget.slug}/products/${widget.productId}');
      if (mounted) {
        setState(() { _product = res; _loading = false; });
        debugPrint('PUBLIC PRODUCT LOADED: ${res['name']} colors=${res['colors']} sizes=${res['sizes']} availableColors=${res['availableColors']} availableSizes=${res['availableSizes']}');
        _loadReviews();
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'public_store.product_not_found'.tr(); _loading = false; });
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    try {
      final res = await _api.get('/products/${widget.productId}/reviews');
      final data = res['data'];
      _reviews = ((data['content'] ?? []) as List).cast<Map<String, dynamic>>();
      _avgRating = (data['averageRating'] ?? 0).toDouble();
      _totalReviews = data['totalReviews'] ?? 0;
    } catch (_) {}
    if (mounted) setState(() => _reviewsLoading = false);
  }

  Future<void> _showReviewDialog() async {
    final nameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int rating = 5;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(builder: (ctx, setD) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('public_store.write_review'.tr(), style: AppTypography.heading4)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'public_store.your_name'.tr(), border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) => IconButton(
                    icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                    onPressed: () => setD(() => rating = i + 1),
                  )),
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: commentCtrl, decoration: InputDecoration(labelText: 'public_store.your_comment'.tr(), border: const OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(label: 'public_store.submit_review'.tr(), onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    final res = await _api.post('/products/${widget.productId}/reviews', data: {
                      'customerName': nameCtrl.text.trim(),
                      'rating': rating,
                      'comment': commentCtrl.text.trim().isNotEmpty ? commentCtrl.text.trim() : null,
                    });
                    Navigator.pop(ctx, true);
                    if (mounted) {
                      setState(() => _reviewSubmitted = true);
                      _loadReviews();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] ?? 'public_store.review_thanks'.tr()),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 4),
                      ));
                    }
                  } catch (e) {
                    Navigator.pop(ctx, false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
                    }
                  }
                }),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr()),
                ),
                ),
              ],
            ),
          )),
        ),
      );
    if (saved == true) {
      if (mounted) setState(() => _reviewSubmitted = true);
    }
  }

  Widget _reviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('public_store.reviews'.tr(), style: AppTypography.heading4),
                if (_totalReviews > 0) ...[
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < _avgRating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 18,
                    )),
                  ),
                  const SizedBox(width: 6),
                  Text('$_avgRating', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                  Text(' ($_totalReviews)', style: AppTypography.caption),
                ],
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: Text('public_store.write_review'.tr()),
              onPressed: _showReviewDialog,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_reviewSubmitted)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'public_store.review_submitted'.tr(),
                    style: AppTypography.body2.copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
        if (_reviewsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.rate_review_outlined, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text('public_store.no_reviews'.tr(), style: AppTypography.body2),
              ],
            ),
          )
        else
          ..._reviews.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r['customerName'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) => Icon(
                        i < (r['rating'] ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 16,
                      )),
                    ),
                  ],
                ),
                if (r['comment'] != null) ...[
                  const SizedBox(height: 8),
                  Text(r['comment'], style: AppTypography.body2),
                ],
                if (r['createdAt'] != null) ...[
                  const SizedBox(height: 4),
                  Text(r['createdAt'].toString().substring(0, 10), style: AppTypography.caption),
                ],
              ],
            ),
          )),
      ],
    );
  }

  List<String> _parseVariantList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return [];
      if (s.startsWith('[')) {
        try {
          return s.substring(1, s.length - 1)
              .split(',')
              .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (_) {}
      }
      return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [value.toString()];
  }

  List<String> _getColors(Map<String, dynamic> p) {
    for (final key in ['colors', 'availableColors', 'color']) {
      final val = p[key];
      if (val != null) {
        final parsed = _parseVariantList(val);
        if (parsed.isNotEmpty) return parsed;
      }
    }
    return [];
  }

  List<String> _getSizes(Map<String, dynamic> p) {
    for (final key in ['sizes', 'availableSizes', 'size']) {
      final val = p[key];
      if (val != null) {
        final parsed = _parseVariantList(val);
        if (parsed.isNotEmpty) return parsed;
      }
    }
    return [];
  }

  void _addToCart() {
    final colors = _getColors(_product!);
    final sizes = _getSizes(_product!);
    if (colors.isNotEmpty && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('public_store.select_color'.tr()), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (sizes.isNotEmpty && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('public_store.select_size'.tr()), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final cart = context.read<PublicCartProvider>();
    final p = _product!;
    final img = resolveImageUrl(firstImageUrl(p['images']));
    cart.addItem(widget.slug, PublicCartItem(
      productId: widget.productId,
      name: p['name'] ?? '',
      price: (p['price'] ?? 0).toDouble(),
      promotionalPrice: p['promotionalPrice']?.toDouble(),
      image: img,
      stock: p['stock'] ?? 0,
      quantity: _quantity,
      selectedColor: _selectedColor,
      selectedSize: _selectedSize,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_quantity x ${p['name']} ${'public_store.added_to_cart'.tr()}'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_error != null || _product == null) {
      return Scaffold(
        appBar: AppBar(title: Text('public_store.product'.tr())),
        body: Center(child: Text(_error ?? 'public_store.product_not_found'.tr(), style: AppTypography.body1)),
      );
    }
    final p = _product!;
    debugPrint('PUBLIC PRODUCT DETAIL: $p');
    final name = p['name'] ?? '';
    final price = (p['price'] ?? 0).toDouble();
    final promo = p['promotionalPrice']?.toDouble();
    final stock = p['stock'] ?? 0;
    final stockStatus = p['stockStatus'] ?? 'IN_STOCK';
    final description = p['description'] as String?;
    final images = parseImageUrls(p['images']).map((u) => resolveImageUrl(u) ?? u).toList();
    final colors = _getColors(p);
    final sizes = _getSizes(p);
    final outOfStock = stockStatus == 'OUT_OF_STOCK' || stock <= 0;
    final wishlist = context.watch<PublicWishlistProvider>();
    final inWishlist = wishlist.isInWishlist(widget.slug, widget.productId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(inWishlist ? Icons.favorite : Icons.favorite_border, color: inWishlist ? AppColors.danger : null),
                onPressed: () {
                  wishlist.toggle(widget.slug, PublicWishlistItem(
                    productId: widget.productId,
                    name: p['name'] ?? '',
                    price: price,
                    promotionalPrice: promo,
                    image: resolveImageUrl(firstImageUrl(p['images'])),
                    stock: stock,
                  ));
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isEmpty
                  ? Container(color: AppColors.surfaceAlt, child: const Center(child: Icon(Icons.image, size: 80, color: AppColors.textHint)))
                  : Stack(
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _currentImage = i),
                          itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 80, color: AppColors.textHint))),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 16, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (i) => Container(
                                width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: _currentImage == i ? AppColors.primary : Colors.white.withAlpha(150)),
                              )),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.heading2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('DT ${(promo != null && promo > 0 ? promo : price).toStringAsFixed(2)}', style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                      if (promo != null && promo > 0) ...[
                        const SizedBox(width: 12),
                        Text('DT ${price.toStringAsFixed(2)}', style: AppTypography.body1.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textHint)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.danger.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                          child: Text('-${((1 - promo / price) * 100).round()}%', style: AppTypography.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _stockBadge(stock, stockStatus),
                  if (colors.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('public_store.color'.tr(), style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: colors.map((c) => ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 13)),
                        selected: _selectedColor == c,
                        onSelected: outOfStock ? null : (v) => setState(() => _selectedColor = v ? c : null),
                      )).toList(),
                    ),
                  ],
                  if (sizes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('public_store.size'.tr(), style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: sizes.map((s) => ChoiceChip(
                        label: Text(s, style: const TextStyle(fontSize: 13)),
                        selected: _selectedSize == s,
                        onSelected: outOfStock ? null : (v) => setState(() => _selectedSize = v ? s : null),
                      )).toList(),
                    ),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('public_store.description'.tr(), style: AppTypography.heading4),
                    const SizedBox(height: 8),
                    Text(description, style: AppTypography.body2),
                  ],
                  if (!outOfStock) ...[
                    const SizedBox(height: 24),
                    Text('public_store.quantity'.tr(), style: AppTypography.body2),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('$_quantity', style: AppTypography.heading4)),
                          IconButton(icon: const Icon(Icons.add), onPressed: _quantity < stock ? () => setState(() => _quantity++) : null),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: outOfStock ? Colors.grey : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: outOfStock ? null : _addToCart,
                      child: Text(outOfStock ? 'public_store.out_of_stock'.tr() : 'public_store.add_to_cart'.tr(), style: AppTypography.button),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _reviewsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBadge(int stock, String status) {
    Color color;
    String text;
    if (status == 'OUT_OF_STOCK' || stock <= 0) {
      color = AppColors.danger; text = 'public_store.out_of_stock'.tr();
    } else if (status == 'LOW_STOCK' || stock <= 5) {
      color = AppColors.warning; text = 'public_store.low_stock'.tr(args: [stock.toString()]);
    } else {
      color = AppColors.success; text = 'public_store.in_stock'.tr(args: [stock.toString()]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
