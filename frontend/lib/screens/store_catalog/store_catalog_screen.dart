import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/product_card.dart';

class StoreCatalogScreen extends StatefulWidget {
  final String boutiqueId;
  final String? boutiqueName;
  const StoreCatalogScreen({super.key, required this.boutiqueId, this.boutiqueName});

  @override
  State<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends State<StoreCatalogScreen> {
  final _api = ApiClient();
  List<Product> _products = [];
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final catRes = await _api.get('/categories', queryParameters: {'boutiqueId': widget.boutiqueId});
      _categories = catRes['data'] as List? ?? [];
      await _loadProducts();
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    final params = <String, dynamic>{'boutiqueId': widget.boutiqueId, 'page': 0, 'size': 50};
    if (_selectedCategoryId != null) params['categoryId'] = _selectedCategoryId;
    if (_searchCtrl.text.trim().isNotEmpty) params['search'] = _searchCtrl.text.trim();
    final res = await _api.get('/products', queryParameters: params);
    _products = ((res['data']?['content'] ?? res['data'] ?? []) as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try { await _loadProducts(); } catch (e) { _error = e.toString(); }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.boutiqueName ?? 'Boutique')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _search(); })
                    : null,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _filterChip('Tout', null),
                  ..._categories.map((c) => _filterChip(c['name'] ?? '', c['id'].toString())),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _loadData)
                    : _products.isEmpty
                        ? const EmptyState(title: 'Aucun produit', subtitle: 'Cette boutique n\'a pas encore de produits')
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _products.length,
                              itemBuilder: (_, i) => ProductCard(
                                product: _products[i],
                                onTap: () => context.push('/product/${_products[i].id}', extra: widget.boutiqueId),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategoryId = categoryId);
          _search();
        },
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySurface,
        checkmarkColor: AppColors.primary,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
    );
  }
}
