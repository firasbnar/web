import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../services/csv_export_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/product_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/app_back_arrow.dart';
import '../../providers/products_provider.dart';
import '../../providers/boutique_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      developer.log('[PRODUCTS] init route=${GoRouterState.of(context).uri} active=${bp.activeBoutiqueId}');
      await bp.ensureActiveBoutique();
      if (!mounted) return;
      if (bp.activeBoutique != null) {
        developer.log('[PRODUCTS] loading data active=${bp.activeBoutique!.id}');
        context.read<ProductsProvider>().loadProducts(bp.activeBoutique!.id, refresh: true);
        context.read<ProductsProvider>().loadCategories(bp.activeBoutique!.id);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique != null) {
        context.read<ProductsProvider>().loadProducts(bp.activeBoutique!.id);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    developer.log('[PRODUCTS] build width=${MediaQuery.of(context).size.width}');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Consumer<ProductsProvider>(
          builder: (_, pp, __) => Text('products.title'.tr(args: [pp.products.length.toString()])),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, size: 20),
            tooltip: 'products.bulk_add'.tr(),
            onPressed: () => context.push('/products/bulk-add'),
          ),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exporter CSV',
            onPressed: () async {
              final bp = context.read<BoutiqueProvider>();
              if (bp.activeBoutique == null) return;
              try {
                final response = await ApiClient().dio.get('/products/export',
                    queryParameters: {'boutiqueId': bp.activeBoutique!.id},
                    options: Options(responseType: ResponseType.bytes));
                final csv = utf8.decode(response.data as List<int>);
                CsvExportService.download(csv, 'produits.csv');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('common.operation_success'.tr()), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${'common.error'.tr()}: ${ApiClient.extractErrorMessage(e)}'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'products.search_products'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchController.clear(); _search(); },
                    ),
                  ),
                  onChanged: (_) => _search(),
                ),
              ),
              Consumer<ProductsProvider>(
                builder: (_, pp, __) {
                  if (pp.categories.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _categoryChip('products.all_products'.tr(), null),
                        ...pp.categories.map((c) => _categoryChip(c.name, c.id)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.tight,
                child: Consumer<ProductsProvider>(
                  builder: (_, pp, __) {
                    if (pp.loading && pp.products.isEmpty) return const LoadingSkeleton(isGrid: true);
                      if (pp.error != null) {
                        return ErrorState(message: pp.error!, onRetry: () {
                      final bp = context.read<BoutiqueProvider>();
                      if (bp.activeBoutique != null) pp.loadProducts(bp.activeBoutique!.id, refresh: true);
                    });
                      }
                    if (pp.products.isEmpty) {
                      return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'products.no_products'.tr(),
                      subtitle: 'products.add_product'.tr(),
                    );
                    }
                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.7,
                      ),
                      itemCount: pp.products.length,
                      itemBuilder: (_, i) {
                        final product = pp.products[i];
                        return ProductCard(
                          product: product,
                            onTap: () => context.push('/products/edit/${product.id}'),
                          onToggleActive: () => pp.toggleActive(product.id),
                          onDelete: () => _confirmDelete(product.id, product.name),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _categoryChip(String label, String? id) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategoryId = id);
          final bp = context.read<BoutiqueProvider>();
          if (bp.activeBoutique != null) {
            context.read<ProductsProvider>().setCategoryFilter(id, bp.activeBoutique!.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
          )),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('products.delete_product'.tr()),
        content: Text('products.delete_confirm'.tr(args: [name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final pp = context.read<ProductsProvider>();
    final ok = await pp.deleteProduct(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'products.product_deleted'.tr() : '${'common.error'.tr()}: ${pp.error ?? 'common.error'.tr()}'),
      backgroundColor: ok ? AppColors.success : AppColors.danger,
    ));
  }

  void _search() {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique != null) {
      context.read<ProductsProvider>().setSearch(_searchController.text.trim(), bp.activeBoutique!.id);
    }
  }
}
