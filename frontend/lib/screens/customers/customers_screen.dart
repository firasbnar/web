import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mes Clients'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<CustomersProvider>(
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
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white),
              dividerThickness: 1,
              dataRowColor: WidgetStateProperty.all(Colors.white),
              border: const TableBorder(
                horizontalInside: BorderSide(color: AppColors.border, width: 1),
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
              columns: [
                _col('Nom du client'),
                _col('Informations de contact'),
                _col('Adresse'),
                _col('Actions'),
              ],
              rows: cp.customers.map((c) => DataRow(cells: [
                DataCell(Text(c.fullName.isNotEmpty ? c.fullName : 'Inconnu',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.email ?? '', style: const TextStyle(fontSize: 12)),
                    if (c.phone != null) Text(c.phone!, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                )),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.address ?? '', style: const TextStyle(fontSize: 12)),
                    Text('${c.city ?? ''}${c.governorate != null ? ", ${c.governorate}" : ""}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                )),
                DataCell(
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person, size: 14, color: Colors.white),
                    label: const Text('View Profile', style: TextStyle(fontSize: 12)),
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
          );
        },
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w500)));
}
