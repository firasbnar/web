import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../services/traffic_tracker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/product_card.dart';

class StoreCatalogScreen extends StatefulWidget {
  final String boutiqueId;
  final String? boutiqueName;
  final String? boutiqueSlug;
  const StoreCatalogScreen({super.key, required this.boutiqueId, this.boutiqueName, this.boutiqueSlug});

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

  void _showContactDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Contacter le vendeur'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(labelText: 'Message *', border: OutlineInputBorder()),
                    maxLines: 4,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        await _api.post('/messages/public', queryParameters: {'boutiqueId': widget.boutiqueId}, data: {
                          'customerName': nameCtrl.text.trim(),
                          'customerEmail': emailCtrl.text.trim(),
                          'customerPhone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          'content': msgCtrl.text.trim(),
                        });
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message envoyé !')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => sending = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(ApiClient.extractErrorMessage(e))),
                        );
                      }
                    },
              child: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    TrafficTracker.trackStoreVisit(
      boutiqueId: widget.boutiqueId,
      slug: widget.boutiqueSlug ?? widget.boutiqueId,
      route: '/catalog/${widget.boutiqueId}',
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final catRes = await _api.get('/categories', queryParameters: {'boutiqueId': widget.boutiqueId});
      _categories = catRes['data'] as List? ?? [];
      await _loadProducts();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
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
    try { await _loadProducts(); } catch (e) { _error = ApiClient.extractErrorMessage(e); }
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
      appBar: AppBar(
        title: Text(widget.boutiqueName ?? 'Boutique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Contacter le vendeur',
            onPressed: _showContactDialog,
          ),
        ],
      ),
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
