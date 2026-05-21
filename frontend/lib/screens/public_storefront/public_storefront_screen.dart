import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/env_config.dart';
import '../../providers/public_cart_provider.dart';
import '../../services/social_meta.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PublicStorefrontScreen extends StatefulWidget {
  final String slug;
  const PublicStorefrontScreen({super.key, required this.slug});
  @override
  State<PublicStorefrontScreen> createState() => _PublicStorefrontScreenState();
}

class _PublicStorefrontScreenState extends State<PublicStorefrontScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _store;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('OPENING PUBLIC STORE SLUG: ${widget.slug}');
    _loadStore();
  }

  Future<void> _trackVisit(double? lat, double? lng) async {
    try {
      final boutiqueId = _store?['id'];
      if (boutiqueId == null) return;
      final payload = <String, dynamic>{
        'page': '/store/${widget.slug}',
        'referrer': html.window.location.href,
        'userAgent': html.window.navigator.userAgent,
        'latitude': lat,
        'longitude': lng,
      };
      print('[Geo] Sending visit payload: $payload');
      await _api.post('/public/stores/${widget.slug}/visit', data: payload);
      print('[Geo] Visit tracked successfully: lat=$lat lng=$lng');
    } catch (e) {
      print('[Geo] Visit tracking error: $e');
    }
  }

  void _requestGeolocation() {
    try {
      print('[Geo] Requesting browser geolocation...');

      js_util.callMethod(
        html.window.navigator.geolocation,
        'getCurrentPosition',
        [
          (position) {
            final coords = js_util.getProperty(position, 'coords');
            final lat = js_util.getProperty(coords, 'latitude') as num?;
            final lng = js_util.getProperty(coords, 'longitude') as num?;

            print('[Geo] Geolocation granted: lat=$lat lng=$lng');
            _trackVisit(lat?.toDouble(), lng?.toDouble());
          },
          (error) {
            print('[Geo] Geolocation denied or error: $error');
            _trackVisit(null, null);
          },
          {
            'enableHighAccuracy': false,
            'timeout': 10000,
          }
        ],
      );
    } catch (e) {
      print('[Geo] Geolocation exception: $e');
      _trackVisit(null, null);
    }
  }

  Future<void> _loadStore() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get('/public/stores/${widget.slug}');
      if (mounted) {
        setState(() { _store = res; _loading = false; });
        _setSocialMeta(res);
        _requestGeolocation();
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Boutique introuvable'; _loading = false; });
    }
  }

  void _setSocialMeta(Map<String, dynamic> s) {
    SocialMeta.setStoreMeta(
      title: s['name'] ?? 'Boutique en ligne',
      description: s['description'] ?? 'Découvrez nos produits',
      image: s['logoUrl'] as String?,
      url: '${EnvConfig.frontendPublicUrl}/store/${widget.slug}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _store == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(_error ?? 'Boutique introuvable', style: AppTypography.heading3),
                const SizedBox(height: 8),
                Text('Vérifiez le lien ou réessayez.', style: AppTypography.caption),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _loadStore, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    }

    final s = _store!;
    final status = s['publicationStatus'] ?? 'PUBLISHED';
    final isFrozen = status == 'FROZEN';
    final isDraft = status == 'DRAFT';

    if (isFrozen || status == 'SUSPENDED') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade300),
                const SizedBox(height: 16),
                Text(s['name'] ?? '', style: AppTypography.heading2),
                const SizedBox(height: 8),
                Text('Cette boutique est temporairement indisponible.',
                  style: AppTypography.body1, textAlign: TextAlign.center),
                if (status == 'FROZEN' && s['freezeReason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Motif: ${s['freezeReason']}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (isDraft) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(s['name'] ?? '', style: AppTypography.heading2),
                const SizedBox(height: 8),
                Text('Cette boutique est en cours de configuration et sera bientôt disponible.',
                  style: AppTypography.body1, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final name = s['name'] ?? '';
    final logo = s['logoUrl'] as String?;
    final banner = s['bannerUrl'] as String?;
    final description = s['description'] as String?;
    final primaryColor = s['primaryColor'] as String? ?? '#2710BF';
    final products = (s['products'] as List? ?? []).cast<Map<String, dynamic>>();
    final categories = (s['categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final phone = s['whatsappNumber'] as String?;
    final cart = context.watch<PublicCartProvider>();
    final cartCount = cart.itemCount(widget.slug);

    final filteredProducts = products.where((p) {
      if (_selectedCategoryId != null && p['categoryId']?.toString() != _selectedCategoryId) return false;
      if (_searchQuery.isNotEmpty && !(p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(fontSize: 16)),
        actions: [
          if (phone != null && phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone),
              tooltip: 'Nous contacter',
              onPressed: () {},
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/store/${widget.slug}/cart'),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner != null && banner.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(banner, width: double.infinity, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            if (logo != null && logo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(logo, height: 80, fit: BoxFit.contain))),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(description, style: AppTypography.body1),
            ],
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            if (categories.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final isAll = i == 0;
                    final c = isAll ? null : categories[i - 1];
                    final selected = isAll ? _selectedCategoryId == null : _selectedCategoryId == c!['id'].toString();
                    return ChoiceChip(
                      label: Text(isAll ? 'Tout' : '${c!['name']} (${c['productCount'] ?? 0})', style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
                      selected: selected,
                      selectedColor: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
                      onSelected: (_) => setState(() => _selectedCategoryId = isAll ? null : c!['id'].toString()),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Produits', style: AppTypography.heading3),
                Text('${filteredProducts.length} article(s)', style: AppTypography.caption),
              ],
            ),
            const SizedBox(height: 8),
            if (filteredProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Aucun produit trouvé', style: AppTypography.body2),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (_, i) {
                  final p = filteredProducts[i];
                  final pid = p['id'].toString();
                  final images = p['images'] as String?;
                  final firstImg = _firstImage(images);
                  final stockStatus = p['stockStatus'] ?? 'IN_STOCK';
                  final outOfStock = stockStatus == 'OUT_OF_STOCK' || (p['stock'] ?? 0) <= 0;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push('/store/${widget.slug}/product/$pid'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                if (firstImg != null)
                                  Image.network(firstImg, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 40, color: AppColors.textHint)))
                                else
                                  Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 40, color: AppColors.textHint)),
                                if (outOfStock)
                                  Positioned.fill(
                                    child: Container(color: Colors.black45, child: const Center(child: Text('Indisponible', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(_fmtPrice(p['price']), style: AppTypography.caption.copyWith(color: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))), fontWeight: FontWeight.w700)),
                                    if (p['promotionalPrice'] != null && (p['promotionalPrice'] as num) > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(_fmtPrice(p['promotionalPrice']), style: AppTypography.caption.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textHint)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 28,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: outOfStock ? Colors.grey.shade300 : Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
                                      foregroundColor: outOfStock ? Colors.grey.shade600 : Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: outOfStock ? null : () {
                                      cart.addItem(widget.slug, PublicCartItem(
                                        productId: pid,
                                        name: p['name'] ?? '',
                                        price: (p['price'] ?? 0).toDouble(),
                                        promotionalPrice: p['promotionalPrice']?.toDouble(),
                                        image: firstImg,
                                        stock: p['stock'] ?? 0,
                                      ));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${p['name']} ajouté au panier'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
                                      );
                                    },
                                    child: Text(outOfStock ? 'Indisponible' : 'Ajouter'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
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

  String _fmtPrice(dynamic price) {
    if (price == null) return '0.00 TND';
    final n = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
    return '${n.toStringAsFixed(3)} TND';
  }
}
