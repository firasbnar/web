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
          final customer = cp.selectedCustomer;
          if (customer == null) return const Center(child: Text('Client non trouvé'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(customer.fullName, style: AppTypography.heading3),
                      if (customer.email != null) Text(customer.email!, style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
                      if (customer.phone != null) Text(customer.phone!, style: AppTypography.body2),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (customer.address != null || customer.city != null) ...[
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
                        if (customer.address != null) Text(customer.address!, style: AppTypography.body2),
                        if (customer.city != null) Text('${customer.city}${customer.governorate != null ? ", ${customer.governorate}" : ""}', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
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
                        Text(customer.notes!, style: AppTypography.body2),
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
}
