import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../providers/customers_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique == null && bp.boutiques.isEmpty) {
        await bp.loadBoutiques();
      }
      if (bp.activeBoutique != null) {
        context.read<CustomersProvider>().loadCustomers(bp.activeBoutique!.id, refresh: true);
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final bp = context.read<BoutiqueProvider>();
      if (bp.activeBoutique != null) {
        context.read<CustomersProvider>().loadCustomers(bp.activeBoutique!.id);
      }
    }
  }

  void _search() {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique != null) {
      context.read<CustomersProvider>().loadCustomers(
        bp.activeBoutique!.id,
        refresh: true,
        search: _searchController.text.trim(),
      );
    }
  }

  Future<void> _exportCsv() async {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique == null) return;
    try {
      await _api.get('/customers/export', queryParameters: {'boutiqueId': bp.activeBoutique!.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export démarré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export: ${ApiClient.extractErrorMessage(e)}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mes Clients'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exporter CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _search(); })
                    : null,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: Consumer<CustomersProvider>(
              builder: (_, cp, __) {
                if (cp.loading && cp.customers.isEmpty) return const LoadingSkeleton();
                if (cp.error != null) {
                  return ErrorState(message: cp.error!, onRetry: () {
                    final bp = context.read<BoutiqueProvider>();
                    if (bp.activeBoutique != null) cp.loadCustomers(bp.activeBoutique!.id, refresh: true);
                  });
                }
                if (cp.customers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'Aucun client',
                    subtitle: 'Les clients apparaîtront ici après leurs commandes',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final bp = context.read<BoutiqueProvider>();
                    if (bp.activeBoutique != null) {
                      await cp.loadCustomers(bp.activeBoutique!.id, refresh: true);
                    }
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollController,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.white),
                      dividerThickness: 1,
                      dataRowColor: WidgetStateProperty.all(Colors.white),
                      border: const TableBorder(
                        horizontalInside: BorderSide(color: AppColors.border, width: 1),
                        bottom: BorderSide(color: AppColors.border, width: 1),
                      ),
                      columns: [
                        _col('Nom'),
                        _col('Contact'),
                        _col('Adresse'),
                        _col('Commandes'),
                        _col('Total dépensé'),
                        _col('Dernière commande'),
                        _col(''),
                      ],
                      rows: cp.customers.map((c) => DataRow(cells: [
                        DataCell(Text(c.fullName.isNotEmpty ? c.fullName : 'Inconnu',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.email != null) Text(c.email!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            if (c.phone != null) Text(c.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ],
                        )),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.address ?? '', style: const TextStyle(fontSize: 12)),
                            Text('${c.city ?? ''}${c.governorate != null ? ", ${c.governorate}" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ],
                        )),
                        DataCell(Text('${c.totalOrders}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        DataCell(Text('${c.totalSpent.toStringAsFixed(3)} TND', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        DataCell(c.lastOrderDate != null
                            ? Text(_formatDate(c.lastOrderDate!), style: const TextStyle(fontSize: 12))
                            : const Text('-', style: TextStyle(fontSize: 12))),
                        DataCell(
                          ElevatedButton.icon(
                            icon: const Icon(Icons.visibility, size: 14, color: Colors.white),
                            label: const Text('Profil', style: TextStyle(fontSize: 12)),
                            onPressed: () => context.go('/customers/${c.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ])).toList(),
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

  DataColumn _col(String label) => DataColumn(
    label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w500)));

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
