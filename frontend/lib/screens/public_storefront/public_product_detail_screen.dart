import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../providers/public_cart_provider.dart';
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
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/public/stores/${widget.slug}/products/${widget.productId}');
      if (mounted) {
        setState(() { _product = res; _loading = false; });
        _loadReviews();
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Produit introuvable'; _loading = false; });
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
              Center(child: Text('Donner votre avis', style: AppTypography.heading4)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Votre nom *', border: OutlineInputBorder())),
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
              TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Votre commentaire', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(label: 'Envoyer', onPressed: () async {
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
                        content: Text(res['message'] ?? 'Merci pour votre avis !'),
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
                  child: const Text('Annuler'),
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
                Text('Avis', style: AppTypography.heading4),
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
              label: const Text('Écrire'),
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
                    'Votre avis a été soumis et sera visible après validation par le marchand.',
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
                Text('Soyez le premier à donner votre avis', style: AppTypography.body2),
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

  List<String> _parseList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String? _firstImage(String? images) {
    if (images == null || images.isEmpty || images == '[]') return null;
    try {
      final t = images.trim();
      if (t.startsWith('[')) {
        final c = t.substring(1, t.length - 1).trim();
        if (c.startsWith('"')) return c.substring(1, c.indexOf('"', 1));
        return c;
      }
      return t;
    } catch (_) { return null; }
  }

  List<String> _imageList(String? images) {
    if (images == null || images.isEmpty || images == '[]') return [];
    try {
      final t = images.trim();
      if (t.startsWith('[')) {
        final inner = t.substring(1, t.length - 1);
        final items = <String>[];
        var i = 0;
        while (i < inner.length) {
          if (inner[i] == '"') {
            final end = inner.indexOf('"', i + 1);
            if (end > i) { items.add(inner.substring(i + 1, end)); i = end + 1; }
            else { i++; }
          } else if (inner[i] != ',' && inner[i] != ' ') {
            final end = inner.indexOf(',', i);
            if (end > i) { items.add(inner.substring(i, end).trim()); i = end; }
            else { items.add(inner.substring(i).trim()); break; }
          } else { i++; }
        }
        return items;
      }
      return [t.trim()];
    } catch (_) { return []; }
  }

  void _addToCart() {
    final cart = context.read<PublicCartProvider>();
    final p = _product!;
    final img = _firstImage(p['images'] as String?);
    cart.addItem(widget.slug, PublicCartItem(
      productId: widget.productId,
      name: p['name'] ?? '',
      price: (p['price'] ?? 0).toDouble(),
      promotionalPrice: p['promotionalPrice']?.toDouble(),
      image: img,
      stock: p['stock'] ?? 0,
      quantity: _quantity,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_quantity x ${p['name']} ajouté au panier'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produit')),
        body: Center(child: Text(_error!, style: AppTypography.body1)),
      );
    }
    final p = _product!;
    final name = p['name'] ?? '';
    final price = (p['price'] ?? 0).toDouble();
    final promo = p['promotionalPrice']?.toDouble();
    final stock = p['stock'] ?? 0;
    final stockStatus = p['stockStatus'] ?? 'IN_STOCK';
    final description = p['description'] as String?;
    final images = _imageList(p['images'] as String?);
    final colors = _parseList(p['colors'] as String?);
    final sizes = _parseList(p['sizes'] as String?);
    final outOfStock = stockStatus == 'OUT_OF_STOCK' || stock <= 0;

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
                      Text('${price.toStringAsFixed(3)} TND', style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                      if (promo != null && promo > 0) ...[
                        const SizedBox(width: 12),
                        Text('${promo.toStringAsFixed(3)} TND', style: AppTypography.body1.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textHint)),
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
                    Text('Couleurs', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
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
                    Text('Tailles', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
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
                    Text('Description', style: AppTypography.heading4),
                    const SizedBox(height: 8),
                    Text(description, style: AppTypography.body2),
                  ],
                  if (!outOfStock) ...[
                    const SizedBox(height: 24),
                    Text('Quantité', style: AppTypography.body2),
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
                      child: Text(outOfStock ? 'Produit indisponible' : 'Ajouter au panier', style: AppTypography.button),
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
      color = AppColors.danger; text = 'Rupture de stock';
    } else if (status == 'LOW_STOCK' || stock <= 5) {
      color = AppColors.warning; text = 'Plus que $stock en stock';
    } else {
      color = AppColors.success; text = '$stock en stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
