import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../providers/public_cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PublicCheckoutScreen extends StatefulWidget {
  final String slug;
  const PublicCheckoutScreen({super.key, required this.slug});
  @override
  State<PublicCheckoutScreen> createState() => _PublicCheckoutScreenState();
}

class _PublicCheckoutScreenState extends State<PublicCheckoutScreen> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'cod';
  String? _deliveryProvider;
  bool _placing = false;
  bool _loadingStore = true;
  Map<String, dynamic>? _store;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    try {
      final res = await _api.get('/public/stores/${widget.slug}');
      if (mounted) {
        setState(() {
          _store = res;
          _loadingStore = false;
          final providers = _enabledProviders(res);
          if (providers.isNotEmpty) _deliveryProvider = providers.first['value'] as String;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStore = false);
    }
  }

  List<Map<String, dynamic>> _enabledProviders(Map<String, dynamic> store) {
    final list = <Map<String, dynamic>>[];
    if (store['enableJax'] == true) list.add({'value': 'JAX', 'label': 'JAX Delivery', 'icon': Icons.local_shipping});
    if (store['enableIntigo'] == true) list.add({'value': 'Intigo', 'label': 'Intigo', 'icon': Icons.local_shipping});
    if (store['enableAdeex'] == true) list.add({'value': 'Adeex', 'label': 'Adeex', 'icon': Icons.flight});
    return list;
  }

  Future<void> _placeOrder() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _placing = true);
    try {
      final cart = context.read<PublicCartProvider>();
      final items = cart.items(widget.slug);
      final body = <String, dynamic>{
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'billingAddress': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'paymentMethod': _paymentMethod,
        'notes': _notesCtrl.text.trim(),
        'deliveryCompany': _deliveryProvider,
        'items': items.map((i) => {
          'productId': i.productId,
          'quantity': i.quantity,
          'unitPrice': i.effectivePrice,
          'color': i.selectedColor ?? '',
          'size': i.selectedSize ?? '',
        }).toList(),
      };
      print('[Checkout] Placing order: deliveryCompany=$_deliveryProvider paymentMethod=$_paymentMethod');

      final res = await _api.post('/public/store/${widget.slug}/orders', data: body);
      print('[Checkout] Order response: success=${res['success']} orderId=${res['orderId']}');

      if (res['success'] == true) {
        final orderId = res['orderId'] as String;
        final orderNumber = res['orderNumber'] as String;

        if (_paymentMethod == 'stripe') {
          try {
            final payRes = await _api.post('/public/stores/${widget.slug}/payments/stripe/session', data: {'orderNumber': orderNumber});
            final sessionUrl = payRes['sessionUrl'] as String?;
            if (sessionUrl != null && mounted) {
              await launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication);
            }
          } catch (_) {}
        }

        await cart.clearCart(widget.slug);
        if (mounted) {
          context.go('/store/${widget.slug}/order-success/$orderId');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Erreur lors de la commande'), backgroundColor: AppColors.danger));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PublicCartProvider>();
    final items = cart.items(widget.slug);
    final subtotal = cart.subtotal(widget.slug);
    final shipping = _store?['deliveryFees'] ?? 7.0;
    final total = subtotal + shipping;
    final providers = _store != null ? _enabledProviders(_store!) : <Map<String, dynamic>>[];

    if (_loadingStore) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commande'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Commande'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
      body: _placing
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Traitement de la commande...')]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vos informations', style: AppTypography.heading3),
                  const SizedBox(height: 16),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone *', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email (optionnel)', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse de livraison *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Ville *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optionnel)', border: OutlineInputBorder()), maxLines: 3),
                  if (providers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Transporteur', style: AppTypography.heading3),
                    const SizedBox(height: 12),
                    ...providers.map((p) => _deliveryOption(p['value'] as String, p['label'] as String, p['icon'] as IconData)),
                  ],
                  const SizedBox(height: 24),
                  Text('Mode de paiement', style: AppTypography.heading3),
                  const SizedBox(height: 12),
                  _paymentOption('cod', 'Paiement à la livraison', Icons.money),
                  _paymentOption('stripe', 'Carte bancaire (Stripe)', Icons.credit_card),
                  const SizedBox(height: 24),
                  Text('Récapitulatif', style: AppTypography.heading3),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        ...items.map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text('${i.name} x${i.quantity}', style: AppTypography.body2)),
                              Text('DT ${i.subtotal.toStringAsFixed(2)}', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sous-total', style: AppTypography.body2),
                            Text('DT ${subtotal.toStringAsFixed(2)}', style: AppTypography.body2),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Livraison', style: AppTypography.body2),
                            Text('DT ${shipping.toStringAsFixed(2)}', style: AppTypography.body2),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: AppTypography.heading3),
                            Text('DT ${total.toStringAsFixed(2)}', style: AppTypography.heading3.copyWith(color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: _placing ? null : _placeOrder,
                      child: Text(_placing ? 'Traitement...' : 'Confirmer la commande', style: AppTypography.button),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _deliveryOption(String value, String label, IconData icon) {
    final selected = _deliveryProvider == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _deliveryProvider = value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 12),
              Text(label, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w500)),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentOption(String value, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _paymentMethod == value ? AppColors.primarySurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _paymentMethod == value ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: _paymentMethod == value ? AppColors.primary : AppColors.textHint),
              const SizedBox(width: 12),
              Text(label, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w500)),
              const Spacer(),
              if (_paymentMethod == value)
                const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
