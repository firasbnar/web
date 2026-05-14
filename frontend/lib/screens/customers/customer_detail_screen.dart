import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/loading_skeleton.dart';
import '../../providers/customers_provider.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});
  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomersProvider>().loadCustomer(widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Client')),
      body: Consumer<CustomersProvider>(
        builder: (_, cp, __) {
          if (cp.loading && cp.selectedCustomer == null) return const LoadingSkeleton();
          final c = cp.selectedCustomer;
          if (c == null) return const Center(child: Text('Client non trouvé'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(c.fullName, style: AppTypography.heading3),
                      if (c.email != null) Text(c.email!, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
                      if (c.phone != null) Text(c.phone!, style: AppTypography.body2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Stats cards
                Row(
                  children: [
                    Expanded(child: _statCard('Commandes', '${c.totalOrders}', Icons.receipt_long, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Total dépensé', '${c.totalSpent.toStringAsFixed(3)} TND', Icons.payments, AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Dernière commande', c.lastOrderDate != null ? _formatDate(c.lastOrderDate!) : '-', Icons.calendar_today, AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 16),
                // Address
                if (c.address != null || c.city != null || c.postalCode != null || c.country != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adresse', style: AppTypography.heading4),
                        const SizedBox(height: 8),
                        if (c.address != null) Text(c.address!, style: AppTypography.body2),
                        if (c.city != null || c.governorate != null)
                          Text('${c.city ?? ""}${c.governorate != null ? ", ${c.governorate}" : ""}', style: AppTypography.caption),
                        if (c.postalCode != null || c.country != null)
                          Text('${c.postalCode ?? ""}${c.country != null ? " ${c.country}" : ""}', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Contact
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact', style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      if (c.email != null) _contactRow(Icons.email_outlined, c.email!),
                      if (c.phone != null) _contactRow(Icons.phone_outlined, c.phone!),
                      if (c.email == null && c.phone == null)
                        Text('Aucune information de contact', style: AppTypography.caption),
                    ],
                  ),
                ),
                // Notes
                if (c.notes != null && c.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes', style: AppTypography.heading4),
                        const SizedBox(height: 8),
                        Text(c.notes!, style: AppTypography.body2),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption.copyWith(fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.body2)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
