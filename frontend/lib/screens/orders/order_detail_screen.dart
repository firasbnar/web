import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/app_back_button.dart';
import '../../providers/orders_provider.dart';
import '../../utils/format_utils.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _trackingCtrl = TextEditingController();
  String _selectedStatus = '';
  String? _selectedDeliveryCompany;
  String? _trackingError;
  bool _savingDelivery = false;
  static const List<String> _statusOptions = ['PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED'];
  static const List<String> _deliveryOptions = ['Adeex', 'Jax', 'Intigo'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<OrdersProvider>().loadOrder(widget.orderId);
      if (!mounted) return;
      final order = context.read<OrdersProvider>().selectedOrder;
      if (order != null) {
        setState(() {
          _selectedStatus = order.status;
          _selectedDeliveryCompany = _deliveryOptions.contains(order.deliveryCompany) ? order.deliveryCompany : null;
          _trackingCtrl.text = order.trackingNumber ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Consumer<OrdersProvider>(
          builder: (_, op, __) => Text(op.selectedOrder?.orderNumber ?? 'orders.order_details'.tr()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share('${'orders.order_details'.tr()} ${context.read<OrdersProvider>().selectedOrder?.orderNumber ?? ""}'),
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (_, op, __) {
          if (op.loading && op.selectedOrder == null) return const LoadingSkeleton();
          final order = op.selectedOrder;
          if (order == null) return Center(child: Text('orders.no_orders'.tr()));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Text('orders.customer'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Text(order.customerName ?? 'orders.customer'.tr(), style: AppTypography.body1),
                      Text(order.paymentMethod ?? "", style: AppTypography.caption),
                    ],
                  ),
                ),
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
                      Text('orders.order_items'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.productName, style: AppTypography.body2)),
                            Text('${item.quantity} × ${FormatUtils.money(context, item.unitPrice, currencyCode: 'TND')}', style: AppTypography.caption),
                            const SizedBox(width: 8),
                            Text(FormatUtils.money(context, item.subtotal, currencyCode: 'TND'), style: AppTypography.body2),
                          ],
                        ),
                      )),
                      const Divider(),
                      _summaryRow('orders.subtotal'.tr(), FormatUtils.money(context, order.subtotal, currencyCode: 'TND')),
                      _summaryRow('orders.shipping'.tr(), FormatUtils.money(context, order.shippingFee, currencyCode: 'TND')),
                      if (order.discount > 0) _summaryRow('orders.discount'.tr(), '-${FormatUtils.money(context, order.discount, currencyCode: 'TND')}'),
                      _summaryRow('orders.total'.tr(), FormatUtils.money(context, order.total, currencyCode: 'TND'), bold: true),
                    ],
                  ),
                ),
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
                      Text('orders.order_status'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StatusChip(status: _selectedStatus.isNotEmpty ? _selectedStatus : order.status),
                          const Spacer(),
                          SizedBox(
                            width: 140,
                            child: DropdownButtonFormField<String>(
                              initialValue: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                              items: _statusOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedStatus = v);
                              },
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedStatus.isNotEmpty && _selectedStatus != order.status) ...[
                        const SizedBox(height: 8),
                        AppButton(label: 'common.save'.tr(), onPressed: () {
                          op.updateStatus(widget.orderId, _selectedStatus);
                        }),
                      ],
                    ],
                  ),
                ),
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
                      Text('orders.payment'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${order.paymentMethod ?? ""} — ', style: AppTypography.body2),
                          StatusChip(status: order.paymentStatus ?? 'UNPAID'),
                        ],
                      ),
                      if (order.paymentRef != null) Text('orders.payment_ref'.tr() + ': ${order.paymentRef}', style: AppTypography.caption),
                    ],
                  ),
                ),
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
                      Text('orders.delivery_assignment'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 6),
                      Text(
                        'orders.delivery_assignment_helper'.tr(),
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('delivery-${_selectedDeliveryCompany ?? 'none'}'),
                        initialValue: _selectedDeliveryCompany,
                        decoration: InputDecoration(labelText: 'delivery.delivery_company'.tr()),
                        items: _deliveryOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedDeliveryCompany = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _trackingCtrl,
                        decoration: InputDecoration(
                          labelText: 'orders.tracking_number'.tr(),
                          errorText: _trackingError,
                        ),
                        onChanged: (_) {
                          if (_trackingError != null) setState(() => _trackingError = null);
                        },
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'common.save'.tr(),
                        loading: _savingDelivery,
                        onPressed: _savingDelivery
                            ? null
                            : () async {
                                final tracking = _trackingCtrl.text.trim();
                                if (_selectedDeliveryCompany == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('orders.delivery_company_required'.tr())),
                                  );
                                  return;
                                }
                                if (tracking.isEmpty) {
                                  setState(() => _trackingError = 'orders.tracking_number_required'.tr());
                                  return;
                                }

                                setState(() => _savingDelivery = true);
                                final ok = await op.updateDelivery(
                                  widget.orderId,
                                  company: _selectedDeliveryCompany!,
                                  tracking: tracking,
                                );
                                if (ok) {
                                  await op.loadOrder(widget.orderId);
                                  final updated = op.selectedOrder;
                                  if (mounted) {
                                    setState(() {
                                      _savingDelivery = false;
                                      _selectedDeliveryCompany = updated?.deliveryCompany ?? _selectedDeliveryCompany;
                                      _trackingCtrl.text = updated?.trackingNumber ?? tracking;
                                    });
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('orders.delivery_assignment_saved'.tr())),
                                    );
                                  }
                                } else {
                                  if (mounted) setState(() => _savingDelivery = false);
                                  if (context.mounted) {
                                    final msg = op.error ?? 'orders.delivery_assignment_save_failed'.tr();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
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
                      Text('orders.invoice'.tr(), style: AppTypography.heading4),
                      const SizedBox(height: 8),
                      if (order.invoiceNumber != null) ...[
                        Text('${'orders.invoice'.tr()} N° ${order.invoiceNumber}', style: AppTypography.body2),
                        if (order.invoiceCreatedAt != null)
                          Text('${'orders.invoice'.tr()} ${order.invoiceCreatedAt}', style: AppTypography.caption),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          if (order.invoiceNumber == null)
                            Expanded(
                              child: AppButton(
                                label: 'orders.generate_invoice'.tr(),
                                onPressed: () async {
                                  await op.generateInvoice(widget.orderId);
                                  await op.loadOrder(widget.orderId);
                                },
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: order.invoiceNumber != null ? 'orders.print_invoice'.tr() : 'orders.download_invoice'.tr(),
                              outlined: order.invoiceNumber != null,
                              onPressed: order.invoiceNumber != null && order.boutiqueId != null
                                  ? () => launchUrl(Uri.parse(op.invoicePrintUrl(order.boutiqueId!, widget.orderId)), mode: LaunchMode.externalApplication)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
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
                        Text('orders.notes'.tr(), style: AppTypography.heading4),
                        const SizedBox(height: 8),
                        Text(order.notes!, style: AppTypography.body2),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? AppTypography.body2.copyWith(fontWeight: FontWeight.w600) : AppTypography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: bold ? AppTypography.heading4.copyWith(color: AppColors.primary) : AppTypography.body2),
        ],
      ),
    );
  }
}
