import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_arrow.dart';

class CheckoutScreen extends StatefulWidget {
  final String boutiqueId;
  const CheckoutScreen({super.key, required this.boutiqueId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiClient();
  int _currentStep = 0;

  // Step 0: Customer info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 1: Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _govCtrl = TextEditingController();

  // Step 2: Delivery
  String? _deliveryProvider;
  bool _loadingStore = false;
  Map<String, dynamic>? _store;

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

  double get _shippingFee => 0.0;
  double get _subtotal => context.read<CartProvider>().subtotal;
  double get _total => _subtotal + _shippingFee - _discount;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() => _loadingStore = true);
    try {
      final res = await _api.get('/boutiques/${widget.boutiqueId}');
      if (mounted) {
        final data = res['data'] as Map<String, dynamic>?;
        setState(() {
          _store = data;
          _loadingStore = false;
          final providers = _enabledProviders(data ?? {});
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _govCtrl.dispose();
    _couponCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isValidUuid(String value) {
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(value);
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) return;
    if (!_isValidUuid(widget.boutiqueId)) {
      setState(() { _couponMsg = 'common.error'.tr(); _couponLoading = false; });
      return;
    }
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
        _couponMsg = '${'cart.coupon_applied'.tr()}: -${_discount.toStringAsFixed(3)} TND';
      } else {
        _couponMsg = data['message'] ?? 'cart.coupon_invalid'.tr();
      }
    } catch (e) {
      _couponMsg = ApiClient.extractErrorMessage(e);
    }
    if (mounted) setState(() => _couponLoading = false);
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;
    if (!_isValidUuid(widget.boutiqueId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }
    if (cart.items.any((i) => i.productId == null || i.productName == null || i.productName!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('cart.empty'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }
    setState(() => _placing = true);
    try {
      final items = cart.items.map((i) => {
        'productId': i.productId,
        'productName': i.productName,
        'unitPrice': i.unitPrice,
        'quantity': i.quantity,
      }).toList();

      final street = _addressCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final gov = _govCtrl.text.trim();
      final fullAddress = [street, city, gov].where((s) => s.isNotEmpty).join(', ');

      final res = await _api.post('/orders', data: {
        'boutiqueId': widget.boutiqueId,
        'customerName': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        'customerEmail': _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        'customerPhone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'items': items,
        'shippingAddress': fullAddress.isNotEmpty ? fullAddress : null,
        'city': city.isNotEmpty ? city : null,
        'governorate': gov.isNotEmpty ? gov : null,
        'paymentMethod': _paymentMethod == 'cod' ? 'CASH_ON_DELIVERY' : _paymentMethod.toUpperCase(),
        'shippingFee': _shippingFee,
        'discount': _discount,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'couponCode': _couponCtrl.text.trim().isNotEmpty ? _couponCtrl.text.trim() : null,
        'deliveryCompany': _deliveryProvider,
      });
      print('[Checkout] Order placed: deliveryCompany=$_deliveryProvider boutiqueId=${widget.boutiqueId}');
      _orderNumber = (res['data'] is Map ? res['data']['orderNumber']?.toString() : null);

      if (_paymentMethod == 'stripe' && _orderNumber != null) {
        final stripeRes = await _api.post('/payments/stripe/create-checkout-session', data: {
          'amount': _total,
          'currency': 'TND',
          'boutiqueId': widget.boutiqueId,
          'orderNumber': _orderNumber,
        });
        final sessionUrl = stripeRes['data']?['sessionUrl']?.toString();
        if (sessionUrl != null && sessionUrl.isNotEmpty) {
          await cart.clearCart(widget.boutiqueId);
          await launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication);
          return;
        }
        throw Exception('Échec de création de la session de paiement');
      }

      await cart.clearCart(widget.boutiqueId);
      setState(() { _success = true; _placing = false; });
    } catch (e) {
      if (mounted) {
        final msg = ApiClient.extractErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: Text('checkout.shipping_info'.tr()),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('checkout.shipping_info'.tr(), style: AppTypography.body2),
            const SizedBox(height: 12),
            TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: '${'checkout.full_name'.tr()} *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'checkout.email'.tr(), border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'checkout.phone'.tr(), border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          ],
        ),
      ),
      Step(
        title: Text('common.address'.tr()),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('checkout.shipping_info'.tr(), style: AppTypography.body2),
            const SizedBox(height: 12),
            TextField(controller: _addressCtrl, decoration: InputDecoration(labelText: 'checkout.address'.tr(), border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: _cityCtrl, decoration: InputDecoration(labelText: 'checkout.city'.tr(), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _govCtrl, decoration: InputDecoration(labelText: 'checkout.governorate'.tr(), border: OutlineInputBorder())),
          ],
        ),
      ),
      Step(
        title: Text('delivery.title'.tr()),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: _loadingStore
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : Column(
                children: [
                  ..._enabledProviders(_store ?? {}).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _deliveryOption(p['value'] as String, p['label'] as String, p['icon'] as IconData),
                  )),
                  if (_enabledProviders(_store ?? {}).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('common.no_data'.tr(), style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                    ),
                ],
              ),
      ),
      Step(
        title: Text('checkout.payment_method'.tr()),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _paymentOption('cod', 'checkout.cash_on_delivery'.tr(), Icons.money),
            const SizedBox(height: 8),
            _paymentOption('stripe', 'checkout.card_payment'.tr(), Icons.credit_card),
          ],
        ),
      ),
      Step(
        title: Text('checkout.order_summary'.tr()),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('cart.subtotal'.tr(), _subtotal),
            _summaryRow('cart.shipping'.tr(), _shippingFee),
            if (_discount > 0) _summaryRow('cart.discount'.tr(), -_discount),
            const Divider(),
            _summaryRow('cart.grand_total'.tr(), _total, bold: true),
            const SizedBox(height: 16),
            const Divider(),
            Text('cart.coupon_code'.tr(), style: AppTypography.body2),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    decoration: InputDecoration(hintText: 'cart.coupon_code'.tr(), border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(label: 'cart.apply_coupon'.tr(), onPressed: _couponLoading ? null : _applyCoupon, fullWidth: false),
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
              decoration: InputDecoration(labelText: 'checkout.notes'.tr(), border: OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 3,
            ),
          ],
        ),
      ),
      Step(
        title: Text('checkout.confirm_order'.tr()),
        isActive: _currentStep >= 5,
        state: _currentStep > 5 ? StepState.complete : StepState.indexed,
        content: _success
            ? Column(
                children: [
                  const Icon(Icons.check_circle, size: 80, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('checkout.order_placed'.tr(), style: AppTypography.heading2),
                  const SizedBox(height: 8),
                  Text('${'checkout.order_number'.tr()}: $_orderNumber', style: AppTypography.body2),
                  const SizedBox(height: 24),
                  AppButton(label: 'checkout.continue_shopping'.tr(), onPressed: () {
                    if (mounted) context.go('/catalog/${widget.boutiqueId}');
                  }),
                ],
              )
            : Column(
                children: [
                  Text('common.confirm_action'.tr(), style: AppTypography.body2),
                  const SizedBox(height: 16),
                  _summaryRow('cart.subtotal'.tr(), _subtotal),
                  _summaryRow('cart.shipping'.tr(), _shippingFee),
                  if (_discount > 0) _summaryRow('cart.discount'.tr(), -_discount),
                  const Divider(),
                  _summaryRow('cart.grand_total'.tr(), _total, bold: true),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _placing ? 'checkout.processing_payment'.tr() : 'checkout.confirm_order'.tr(),
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
            Text('checkout.order_placed'.tr(), style: AppTypography.heading2),
            const SizedBox(height: 8),
            Text('${'checkout.order_number'.tr()}: $_orderNumber', style: AppTypography.body2),
            const SizedBox(height: 24),
            AppButton(label: 'checkout.continue_shopping'.tr(), onPressed: () {
              if (mounted) context.go('/catalog/${widget.boutiqueId}');
            }),
          ],
        ),
      ),
    );
  }

  Widget _deliveryOption(String value, String label, IconData icon) {
    final selected = _deliveryProvider == value;
    return InkWell(
      onTap: () => setState(() => _deliveryProvider = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primarySurface : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.body2),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
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
      appBar: AppBar(leading: const AppBackArrow(), title: Text('checkout.title'.tr())),
      body: Consumer<CartProvider>(
        builder: (_, cart, __) {
          if (_success) {
            return _buildSuccessView();
          }
          if (cart.items.isEmpty) {
            return Center(child: Text('cart.empty'.tr()));
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
                if (_currentStep < 5) setState(() => _currentStep++);
                if (_currentStep == 5) _placeOrder();
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
                      if (_currentStep < 5)
                        AppButton(label: 'common.next'.tr(), onPressed: details.onStepContinue, fullWidth: false)
                      else
                        AppButton(label: 'checkout.confirm_order'.tr(), onPressed: details.onStepContinue, loading: _placing, fullWidth: false),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(onPressed: details.onStepCancel, child: Text('common.back'.tr())),
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
