import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class _StoreInfo {
  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? description;
  final String? currency;
  _StoreInfo({required this.id, required this.name, this.slug, this.logoUrl, this.description, this.currency});
  factory _StoreInfo.fromJson(Map<String, dynamic> j) => _StoreInfo(
    id: j['id']?.toString() ?? '',
    name: j['name'] ?? '',
    slug: j['slug'],
    logoUrl: j['logoUrl'],
    description: j['description'],
    currency: j['currency'],
  );
}

class StoresBrowserScreen extends StatefulWidget {
  const StoresBrowserScreen({super.key});
  @override
  State<StoresBrowserScreen> createState() => _StoresBrowserScreenState();
}

class _StoresBrowserScreenState extends State<StoresBrowserScreen> {
  final _api = ApiClient();
  final _searchCtrl = TextEditingController();
  List<_StoreInfo> _stores = [];
  List<_StoreInfo> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/boutiques/public');
      _stores = (res['data'] as List).map((e) => _StoreInfo.fromJson(e)).toList();
      _filtered = List.from(_stores);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _search(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _stores.where((s) =>
        s.name.toLowerCase().contains(query) ||
        (s.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boutiques')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher une boutique...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                ? const Center(child: Text('Aucune boutique trouvée'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      return InkWell(
                        onTap: () => context.go('/store/${s.id}', extra: s.name),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: s.logoUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(s.logoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, color: AppColors.primary)),
                                    )
                                  : const Icon(Icons.store, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: AppTypography.heading4),
                                    if (s.description != null && s.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(s.description!, style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
