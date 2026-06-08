import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_arrow.dart';

class DeliveryCompanyScreen extends StatefulWidget {
  const DeliveryCompanyScreen({super.key});
  @override
  State<DeliveryCompanyScreen> createState() => _DeliveryCompanyScreenState();
}

class _DeliveryCompanyScreenState extends State<DeliveryCompanyScreen> {
  final _api = ApiClient();
  bool _jaxEnabled = false;
  bool _intigoEnabled = false;
  bool _adeexEnabled = false;
  bool _saving = false;
  final _jaxApiCtrl = TextEditingController();
  final _jaxZoneACtrl = TextEditingController();
  final _jaxZoneBCtrl = TextEditingController();
  final _jaxZoneCCtrl = TextEditingController();
  final _intigoMerchantCtrl = TextEditingController();
  final _intigoSecretCtrl = TextEditingController();
  final _adeexUrlCtrl = TextEditingController();
  final _adeexTokenCtrl = TextEditingController();
  String? _bid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _jaxApiCtrl.dispose();
    _jaxZoneACtrl.dispose();
    _jaxZoneBCtrl.dispose();
    _jaxZoneCCtrl.dispose();
    _intigoMerchantCtrl.dispose();
    _intigoSecretCtrl.dispose();
    _adeexUrlCtrl.dispose();
    _adeexTokenCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final bp = context.read<BoutiqueProvider>();
    final b = bp.currentBoutique;
    if (b != null) {
      _bid = b.id;
      setState(() {
        _jaxEnabled = b.enableJax;
        _intigoEnabled = b.enableIntigo;
        _adeexEnabled = b.enableAdeex;
      });
      _loadConfig();
    }
  }

  Future<void> _loadConfig() async {
    if (_bid == null) return;
    try {
      final res = await _api.get('/boutiques/$_bid/config');
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      for (var item in list) {
        final key = item['key'] as String;
        final value = item['value'] as String? ?? '';
        switch (key) {
          case 'jax_api_key': _jaxApiCtrl.text = value; break;
          case 'jax_zone_a': _jaxZoneACtrl.text = value; break;
          case 'jax_zone_b': _jaxZoneBCtrl.text = value; break;
          case 'jax_zone_c': _jaxZoneCCtrl.text = value; break;
          case 'intigo_merchant_id': _intigoMerchantCtrl.text = value; break;
          case 'intigo_secret': _intigoSecretCtrl.text = value; break;
          case 'adeex_api_url': _adeexUrlCtrl.text = value; break;
          case 'adeex_token': _adeexTokenCtrl.text = value; break;
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_bid == null) return;
    setState(() => _saving = true);
    try {
      await Future.wait([
        context.read<BoutiqueProvider>().updatePayments({
          'enableJax': _jaxEnabled,
          'enableIntigo': _intigoEnabled,
          'enableAdeex': _adeexEnabled,
        }),
        _api.put('/boutiques/$_bid/config', data: {
          'jax_api_key': _jaxApiCtrl.text.trim(),
          'jax_zone_a': _jaxZoneACtrl.text.trim(),
          'jax_zone_b': _jaxZoneBCtrl.text.trim(),
          'jax_zone_c': _jaxZoneCCtrl.text.trim(),
          'intigo_merchant_id': _intigoMerchantCtrl.text.trim(),
          'intigo_secret': _intigoSecretCtrl.text.trim(),
          'adeex_api_url': _adeexUrlCtrl.text.trim(),
          'adeex_token': _adeexTokenCtrl.text.trim(),
        }),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.operation_success'.tr()), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e'), backgroundColor: AppColors.danger));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackArrow(), title: Text('delivery.title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _deliveryMethod('JAX Delivery', 'Service de livraison rapide en Tunisie', _jaxEnabled, (v) async {
              setState(() => _jaxEnabled = v ?? false);
              await context.read<BoutiqueProvider>().updatePayments({'enableJax': _jaxEnabled});
            }, [
              _configField('Clé API', _jaxApiCtrl),
              _configField('Zone A (DT)', _jaxZoneACtrl),
              _configField('Zone B (DT)', _jaxZoneBCtrl),
              _configField('Zone C (DT)', _jaxZoneCCtrl),
            ]),
            const SizedBox(height: 12),
            _deliveryMethod('Intigo', 'Solutions de livraison nationale', _intigoEnabled, (v) async {
              setState(() => _intigoEnabled = v ?? false);
              await context.read<BoutiqueProvider>().updatePayments({'enableIntigo': _intigoEnabled});
            }, [
              _configField('ID Marchand', _intigoMerchantCtrl),
              _configField('Clé secrète', _intigoSecretCtrl, secret: true),
            ]),
            const SizedBox(height: 12),
            _deliveryMethod('Adeex', 'Livraison internationale', _adeexEnabled, (v) async {
              setState(() => _adeexEnabled = v ?? false);
              await context.read<BoutiqueProvider>().updatePayments({'enableAdeex': _adeexEnabled});
            }, [
              _configField('URL API', _adeexUrlCtrl),
              _configField('Token', _adeexTokenCtrl, secret: true),
            ]),
            const SizedBox(height: 24),
            AppButton(label: 'common.save'.tr(), onPressed: _saving ? null : _save, loading: _saving),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _deliveryMethod(String name, String description, bool enabled, ValueChanged<bool?> onToggle, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(description, style: AppTypography.caption),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle, activeThumbColor: AppColors.primary),
            ],
          ),
          if (enabled) ...children,
        ],
      ),
    );
  }

  Widget _configField(String label, TextEditingController ctrl, {bool secret = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: ctrl,
        obscureText: secret,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
