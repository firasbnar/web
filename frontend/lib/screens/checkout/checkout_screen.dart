import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

class CheckoutScreen extends StatefulWidget {
  final String boutiqueId;
  const CheckoutScreen({super.key, required this.boutiqueId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiClient();
  int _currentStep = 0;

  // Step 1: Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _govCtrl = TextEditingController();

  // Step 2: Delivery
  String _deliveryMethod = 'standard';

  // Step 3: Payment
  String _paymentMethod = 'cod';

  // Step 4: Coupon & Notes
  final _couponCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  double _discount = 0;
  bool _couponLoading = false;
  String? _couponMsg;

  // Step 5: Place
  bool _placing = false;
  bool _success = false;
  String? _orderNumber;

  double get _shippingFee => _deliveryMethod == 'express' ? 5.0 : 0.0;
  double get _subtotal => context.read<CartProvider>().subtotal;
  double get _total => _subtotal + _shippingFee - _discount;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _govCtrl.dispose();
    _couponCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _couponLoading = true; _couponMsg = null; _discount = 0; });
    try {
      final res = await _api.post('/coupons/validate', data: {
        'boutiqueId': widget.boutiqueId,
        'code': code,
        'orderAmount': _subtotal + _shippingFee,
      });
      final data = res['data'];
      if (data['valid'] == true) {
        _discount = (data['discountAmount'] as num).toDouble();
        _couponMsg = 'Code promo appliqué: -${_discount.toStringAsFixed(3)} TND';
      } else {
        _couponMsg = data['message'] ?? 'Code promo invalide';
      }
    } catch (e) {
      _couponMsg = 'Erreur lors de la validation du code';
    }
    setState(() => _couponLoading = false);
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    setState(() => _placing = true);
    try {
      final items = cart.items.map((i) => {
        'productId': i.productId,
        'productName': i.productName,
        'unitPrice': i.unitPrice,
        'quantity': i.quantity,
      }).toList();

      final fullAddress = [
        _addressCtrl.text.trim(),
        _cityCtrl.text.trim(),
        _govCtrl.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      final res = await _api.post('/orders', data: {
        'boutiqueId': widget.boutiqueId,
        'items': items,
        'shippingAddress': fullAddress.isNotEmpty ? fullAddress : null,
        'paymentMethod': _paymentMethod == 'cod' ? 'CASH_ON_DELIVERY' : _paymentMethod.toUpperCase(),
        'shippingFee': _shippingFee,
        'discount': _discount,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'couponCode': _couponCtrl.text.trim().isNotEmpty ? _couponCtrl.text.trim() : null,
      });
      _orderNumber = res['data']['orderNumber'];
      await cart.clearCart(widget.boutiqueId);
      setState(() { _success = true; _placing = false; });
    } catch (e) {
      setState(() => _placing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Adresse'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adresse de livraison', style: AppTypography.body2),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Ville', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _govCtrl, decoration: const InputDecoration(labelText: 'Gouvernorat', border: OutlineInputBorder())),
          ],
        ),
      ),
      Step(
        title: const Text('Livraison'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _deliveryOption('standard', 'Standard', 'Livraison sous 3-5 jours', 0),
            const SizedBox(height: 8),
            _deliveryOption('express', 'Express', 'Livraison sous 24h', 5.0),
            const SizedBox(height: 8),
            _deliveryOption('pickup', 'Point relais', 'Retrait en magasin', 0),
          ],
        ),
      ),
      Step(
        title: const Text('Paiement'),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _paymentOption('cod', 'Paiement à la livraison', Icons.money),
            const SizedBox(height: 8),
            _paymentOption('stripe', 'Carte bancaire (Stripe)', Icons.credit_card),
            const SizedBox(height: 8),
            _paymentOption('paypal', 'PayPal', Icons.payment),
          ],
        ),
      ),
      Step(
        title: const Text('Récapitulatif'),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Sous-total', _subtotal),
            _summaryRow('Livraison', _shippingFee),
            if (_discount > 0) _summaryRow('Remise', -_discount),
            const Divider(),
            _summaryRow('Total', _total, bold: true),
            const SizedBox(height: 16),
            const Divider(),
            Text('Code promo', style: AppTypography.body2),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    decoration: const InputDecoration(hintText: 'Entrez un code', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(label: 'Appliquer', onPressed: _couponLoading ? null : _applyCoupon, fullWidth: false),
              ],
            ),
            if (_couponLoading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            if (_couponMsg != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_couponMsg!, style: AppTypography.caption.copyWith(color: _discount > 0 ? AppColors.success : AppColors.danger)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optionnel)', border: OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 3,
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Confirmation'),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: _success
            ? Column(
                children: [
                  const Icon(Icons.check_circle, size: 80, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('Commande confirmée !', style: AppTypography.heading2),
                  const SizedBox(height: 8),
                  Text('Numéro de commande: $_orderNumber', style: AppTypography.body2),
                  const SizedBox(height: 24),
                  AppButton(label: 'Retour à l\'accueil', onPressed: () => Navigator.pop(context)),
                ],
              )
            : Column(
                children: [
                  Text('Vérifiez votre commande avant de confirmer', style: AppTypography.body2),
                  const SizedBox(height: 16),
                  _summaryRow('Sous-total', _subtotal),
                  _summaryRow('Livraison', _shippingFee),
                  if (_discount > 0) _summaryRow('Remise', -_discount),
                  const Divider(),
                  _summaryRow('Total', _total, bold: true),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _placing ? 'Traitement...' : 'Confirmer la commande',
                    onPressed: _placing ? null : _placeOrder,
                    loading: _placing,
                  ),
                ],
              ),
      ),
    ];
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 16),
            Text('Commande confirmée !', style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text('Numéro de commande: $_orderNumber', style: AppTypography.body2),
            const SizedBox(height: 24),
            AppButton(label: 'Retour à l\'accueil', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Widget _deliveryOption(String value, String title, String subtitle, double price) {
    final selected = _deliveryMethod == value;
    return InkWell(
      onTap: () => setState(() => _deliveryMethod = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primarySurface : null,
        ),
        child: Row(
          children: [
            Radio<String>(value: value, groupValue: _deliveryMethod, onChanged: (v) => setState(() => _deliveryMethod = v!)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Text(price > 0 ? '$price TND' : 'Gratuit', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(String value, String title, IconData icon) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primarySurface : null,
        ),
        child: Row(
          children: [
            Radio<String>(value: value, groupValue: _paymentMethod, onChanged: (v) => setState(() => _paymentMethod = v!)),
            const SizedBox(width: 8),
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: AppTypography.body2),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? AppTypography.body2.copyWith(fontWeight: FontWeight.w600) : AppTypography.body2),
          Text('${amount.toStringAsFixed(3)} TND', style: bold ? AppTypography.body2.copyWith(fontWeight: FontWeight.w600) : AppTypography.body2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande')),
      body: Consumer<CartProvider>(
        builder: (_, cart, __) {
          if (_success) {
            return _buildSuccessView();
          }
          if (cart.items.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }
          // Clamp to prevent Stepper assertion crash
          final steps = _buildSteps();
          final safeStep = _currentStep.clamp(0, steps.length - 1);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Stepper(
                  currentStep: safeStep,
              onStepContinue: () {
                if (_currentStep < 4) setState(() => _currentStep++);
                if (_currentStep == 4) _placeOrder();
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep--);
              },
              controlsBuilder: (ctx, details) {
                if (_success) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      if (_currentStep < 4)
                        AppButton(label: 'Continuer', onPressed: details.onStepContinue, fullWidth: false)
                      else
                        AppButton(label: 'Confirmer', onPressed: details.onStepContinue, loading: _placing, fullWidth: false),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(onPressed: details.onStepCancel, child: const Text('Retour')),
                      ],
                    ],
                  ),
                );
              },
              steps: _buildSteps(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
