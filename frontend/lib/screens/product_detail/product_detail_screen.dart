import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final String? boutiqueId;
  const ProductDetailScreen({super.key, required this.productId, this.boutiqueId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _api = ApiClient();
  Product? _product;
  bool _loading = true;
  bool _inWishlist = false;
  int _quantity = 1;
  int _currentImage = 0;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  int _totalReviews = 0;
  bool _reviewsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/products/${widget.productId}');
      final p = Product.fromJson(res['data']);
      setState(() { _product = p; _loading = false; });
      _loadReviews();
      if (widget.boutiqueId != null) {
        if (!mounted) return;
        final wl = context.read<WishlistProvider>();
        _inWishlist = await wl.isInWishlist(widget.productId);
        if (mounted) setState(() {});
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleWishlist() async {
    final wl = context.read<WishlistProvider>();
    final ok = await wl.toggle(widget.productId);
    if (ok) setState(() => _inWishlist = !_inWishlist);
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
    setState(() => _reviewsLoading = false);
  }

  Future<void> _showReviewDialog() async {
    final nameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int rating = 5;
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Donner votre avis'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Votre nom *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
            icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
            onPressed: () => setD(() => rating = i + 1),
          ))),
          const SizedBox(height: 8),
          TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Votre commentaire', border: OutlineInputBorder()), maxLines: 3),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        AppButton(label: 'Envoyer', onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          try {
            final res = await _api.post('/products/${widget.productId}/reviews', data: {
              'customerName': nameCtrl.text.trim(),
              'rating': rating,
              'comment': commentCtrl.text.trim().isNotEmpty ? commentCtrl.text.trim() : null,
            });
            Navigator.pop(ctx, true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(res['message'] ?? 'Avis envoyé'),
                backgroundColor: AppColors.success,
              ));
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
          }
        }),
      ],
    )));
    if (saved == true) _loadReviews();
  }

  Future<void> _addToCart() async {
    if (_product == null || widget.boutiqueId == null) return;
    final cart = context.read<CartProvider>();
    final ok = await cart.addItem(widget.boutiqueId!, widget.productId, _quantity);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_quantity x ${_product!.name} ajouté au panier'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    if (_product == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Produit non trouvé')));
    final p = _product!;
    final boutiqueId = widget.boutiqueId ?? p.boutiqueId ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(_inWishlist ? Icons.favorite : Icons.favorite_border, color: _inWishlist ? AppColors.danger : null),
                onPressed: _toggleWishlist,
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/cart/$boutiqueId'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: p.images.isEmpty
                  ? Container(color: AppColors.surfaceAlt, child: const Center(child: Icon(Icons.image, size: 80, color: AppColors.textHint)))
                  : Stack(
                      children: [
                        PageView.builder(
                          itemCount: p.images.length,
                          onPageChanged: (i) => setState(() => _currentImage = i),
                          itemBuilder: (_, i) => Image.network(p.images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 80, color: AppColors.textHint))),
                        ),
                        if (p.images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(p.images.length, (i) => Container(
                                width: 8, height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImage == i ? AppColors.primary : Colors.white.withAlpha(150),
                                ),
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
                  Text(p.name, style: AppTypography.heading2),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${p.price.toStringAsFixed(3)} TND', style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                      if (p.comparePrice != null && p.comparePrice! > p.price) ...[
                        const SizedBox(width: 12),
                        Text('${p.comparePrice!.toStringAsFixed(3)} TND', style: AppTypography.body1.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textHint)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _stockBadge(p.stock),
                  const SizedBox(height: 16),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    Text('Description', style: AppTypography.heading4),
                    const SizedBox(height: 8),
                    Text(p.description!, style: AppTypography.body2),
                  ],
                  const SizedBox(height: 24),
                  if (p.stock > 0) ...[
                    Text('Quantité', style: AppTypography.body2),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text('$_quantity', style: AppTypography.heading4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _quantity < p.stock ? () => setState(() => _quantity++) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  AppButton(
                    label: p.stock > 0 ? 'Ajouter au panier' : 'Rupture de stock',
                    onPressed: p.stock > 0 ? _addToCart : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/checkout/$boutiqueId'),
                      icon: const Icon(Icons.flash_on),
                      label: const Text('Acheter maintenant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
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

  Widget _stockBadge(int stock) {
    Color color;
    String text;
    if (stock <= 0) { color = AppColors.danger; text = 'Rupture de stock'; }
    else if (stock <= 10) { color = AppColors.warning; text = 'Plus que $stock en stock'; }
    else { color = AppColors.success; text = '$stock en stock'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
