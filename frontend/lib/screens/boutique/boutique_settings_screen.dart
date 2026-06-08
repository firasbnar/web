import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/products_provider.dart';
import '../../models/boutique.dart';
import '../../models/delivery_zone.dart';
import '../../models/product.dart';
import '../../widgets/app_back_arrow.dart';
import 'package:easy_localization/easy_localization.dart';

class BoutiqueSettingsScreen extends StatefulWidget {
  const BoutiqueSettingsScreen({super.key});
  @override
  State<BoutiqueSettingsScreen> createState() => _BoutiqueSettingsScreenState();
}

class _BoutiqueSettingsScreenState extends State<BoutiqueSettingsScreen> {
  // --- Boutique Config Controllers ---
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _topBarTextCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController();
  final _deliveryFeesCtrl = TextEditingController();

  // --- Payment Controllers ---
  final _konnectMerchantCtrl = TextEditingController();
  final _konnectApiCtrl = TextEditingController();
  final _d17MerchantCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _categoryNameCtrl = TextEditingController();
  final _categorySortCtrl = TextEditingController();
  final _customJsCtrl = TextEditingController();
  final _customCssCtrl = TextEditingController();
  final _fbPageTokenCtrl = TextEditingController();
  final _fbPageIdCtrl = TextEditingController();

  // --- SEO Controllers ---
  final _seoTitleCtrl = TextEditingController();
  final _seoDescCtrl = TextEditingController();
  final _seoKeywordsCtrl = TextEditingController();

  // --- Notification Preferences ---
  bool _enableEmailNotif = true;
  bool _enableSmsNotif = false;
  bool _enablePushNotif = true;
  bool _enableMarketingEmails = false;
  bool _enableOrderAlerts = true;
  bool _savingNotif = false;
  bool _savingNotifEmail = false;
  bool _savingNotifSms = false;
  bool _savingNotifPush = false;
  bool _savingNotifAlerts = false;
  bool _savingNotifMarketing = false;
  bool _savingKonnect = false;
  bool _savingD17 = false;

  // --- Payment Provider Keys ---
  final _stripePublishableCtrl = TextEditingController();
  final _stripeSecretCtrl = TextEditingController();
  bool _savingPayments = false;

  // ========== DELIVERY ZONES ==========
  final _api = ApiClient();
  List<DeliveryZone> _deliveryZones = [];
  bool _loadingZones = false;
  bool _savingZone = false;

  // --- Branding extras ---
  String _fontFamily = 'Inter';
  bool _darkMode = false;

  // --- State ---
  String _currency = 'TND';
  bool _cashDelivery = true;
  bool _konnectEnabled = false;
  bool _d17Enabled = false;
  bool _simpleCheckout = false;
  bool _loading = true;
  bool _savingConfig = false;
  bool _savingTheme = false;
  bool _savingFb = false;
  bool _savingCode = false;
  bool _savingCurrency = false;
  bool _savingCategory = false;

  // --- Color State ---
  Color _headerColor = const Color(0xFFededed);
  Color _footerColor = const Color(0xFFdbdbdb);
  Color _bodyColor = const Color(0xFFffffff);
  Color _cardProductColor = const Color(0xFFfafafa);
  Color _buttonColor = const Color(0xFFb551c2);
  Color _topBarColor = const Color(0xFF3b0086);
  Color _textColor = const Color(0xFF751515);

  // --- Name availability ---
  String? _nameHelperText;
  Color _nameHelperColor = AppColors.textHint;
  bool _nameAvailable = true;
  String? _originalName;
  Timer? _debounce;

  // --- D17 QR Code ---
  String? _d17QrCodeUrl;

  // --- Logo ---
  String? _logoUrl;
  bool _uploadingLogo = false;

  static const List<String> _currencies = [
    'TND',
    'EUR',
    'USD',
    'GBP',
    'JPY',
    'CAD',
    'AUD',
    'CHF',
    'CNY',
    'MAD',
    'DZD',
    'LYD',
    'EGP',
    'SAR',
    'AED',
    'QAR',
    'OMR',
    'BHD',
    'KWD'
  ];

  static const Map<String, String> _acceptedCountryOptions = {
    'TN': 'Tunisie',
    'FR': 'France',
    'IT': 'Italie',
    'DE': 'Allemagne',
    'ES': 'Espagne',
    'GB': 'Royaume-Uni',
    'US': 'Etats-Unis',
    'CA': 'Canada',
    'MA': 'Maroc',
    'DZ': 'Algerie',
    'LY': 'Libye',
    'EG': 'Egypte',
    'SA': 'Arabie saoudite',
    'AE': 'Emirats arabes unis',
    'QA': 'Qatar',
    'OM': 'Oman',
    'BH': 'Bahrein',
    'KW': 'Koweit',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoutique());
  }

  void _loadBoutique() {
    final bp = context.read<BoutiqueProvider>();
    final b = bp.currentBoutique;
    if (b == null) {
      setState(() => _loading = false);
      return;
    }

    _originalName = b.name;
    _nameCtrl.text = b.name;
    _emailCtrl.text = b.email ?? '';
    _addressCtrl.text = b.address ?? '';
    _topBarTextCtrl.text = b.announcementText ?? '';
    _phoneCtrl.text = b.phone ?? '';
    _tvaCtrl.text = b.tva?.toStringAsFixed(2) ?? '0.00';
    _deliveryFeesCtrl.text = b.deliveryFees?.toStringAsFixed(2) ?? '7.00';
    _cashDelivery = b.cashOnDelivery;
    _konnectMerchantCtrl.text = b.konnectMerchantId ?? '';
    _konnectApiCtrl.text = b.konnectApiKey ?? '';
    _konnectEnabled = b.konnectStatus == 'active';
    _d17MerchantCtrl.text = b.d17MerchantNumber ?? '';
    _d17Enabled = b.d17Status == 'active';
    _d17QrCodeUrl = b.d17QrCodeUrl;
    _simpleCheckout = b.simpleCheckout;
    _currency = b.currency ?? 'TND';
    _logoUrl = b.logoUrl;
    _customJsCtrl.text = b.customJs ?? '';
    _customCssCtrl.text = b.customCss ?? '';
    _fbPageTokenCtrl.text = b.storeConfig ?? '';
    _fbPageIdCtrl.text = b.facebookPixelId ?? '';

    _seoTitleCtrl.text = b.seoTitle ?? '';
    _seoDescCtrl.text = b.seoDescription ?? '';
    _seoKeywordsCtrl.text = b.seoKeywords ?? '';

    _enableEmailNotif = b.enableEmailNotifications;
    _enableSmsNotif = b.enableSmsNotifications;
    _enablePushNotif = b.enablePushNotifications;
    _enableMarketingEmails = b.enableMarketingEmails;
    _enableOrderAlerts = b.enableOrderAlerts;

    _stripePublishableCtrl.text = b.stripePublishableKey ?? '';
    _stripeSecretCtrl.text = ''; // never pre-fill secret keys

    _fontFamily = b.fontFamily ?? 'Inter';
    _darkMode = b.darkMode;

    if (b.headerColor != null) _headerColor = _parseColor(b.headerColor!);
    if (b.footerColor != null) _footerColor = _parseColor(b.footerColor!);
    if (b.bodyColor != null) _bodyColor = _parseColor(b.bodyColor!);
    if (b.cardProductColor != null) {
      _cardProductColor = _parseColor(b.cardProductColor!);
    }
    if (b.buttonColor != null) _buttonColor = _parseColor(b.buttonColor!);
    if (b.topBarColor != null) _topBarColor = _parseColor(b.topBarColor!);
    if (b.textColor != null) _textColor = _parseColor(b.textColor!);

    bp.loadCountries();
    context.read<ProductsProvider>().loadCategories(b.id);
    _loadDeliveryZones();
    setState(() => _loading = false);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFededed);
    }
  }

  // ========== DELIVERY ZONES ==========

  Future<void> _loadDeliveryZones() async {
    setState(() => _loadingZones = true);
    try {
      final bid = context.read<BoutiqueProvider>().currentBoutique!.id.toString();
      final res = await _api.get('/boutiques/$bid/delivery-zones');
      _deliveryZones = (res['data'] as List?)?.map((e) => DeliveryZone.fromJson(e)).toList() ?? [];
    } catch (_) {}
    setState(() => _loadingZones = false);
  }

  Future<void> _saveDeliveryZone(DeliveryZone? existing, Map<String, dynamic> data) async {
    setState(() => _savingZone = true);
    try {
      final bid = context.read<BoutiqueProvider>().currentBoutique!.id.toString();
      if (existing != null) {
        await _api.put('/boutiques/$bid/delivery-zones/${existing.id}', data: data);
      } else {
        await _api.post('/boutiques/$bid/delivery-zones', data: data);
      }
      await _loadDeliveryZones();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('boutique.updated'.tr()), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
    }
    setState(() => _savingZone = false);
  }

  Future<void> _deleteDeliveryZone(DeliveryZone dz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text('common.delete_confirm'.tr(args: [dz.name])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.delete'.tr())),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final bid = context.read<BoutiqueProvider>().currentBoutique!.id.toString();
      await _api.delete('/boutiques/$bid/delivery-zones/${dz.id}');
      await _loadDeliveryZones();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('boutique.updated'.tr()), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
    }
  }

  void _showDeliveryZoneDialog({DeliveryZone? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final feeCtrl = TextEditingController(text: existing != null ? existing.fee.toStringAsFixed(2) : '');
    final minCtrl = TextEditingController(text: existing?.minOrderAmount?.toStringAsFixed(2) ?? '');
    final daysCtrl = TextEditingController(text: existing?.estimatedDays?.toString() ?? '');
    final countriesCtrl = TextEditingController(text: existing?.countries ?? '');
    bool active = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'boutique.edit_zone'.tr() : 'boutique.new_zone'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'boutique.name'.tr(), hintText: 'boutique.zone_name_hint'.tr())),
                const SizedBox(height: 8),
                TextField(controller: feeCtrl, decoration: InputDecoration(labelText: 'boutique.delivery_fees'.tr()), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: minCtrl, decoration: InputDecoration(labelText: 'boutique.min_amount'.tr()), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: daysCtrl, decoration: InputDecoration(labelText: 'boutique.estimated_days'.tr()), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: countriesCtrl, decoration: InputDecoration(labelText: 'boutique.countries'.tr())),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('common.active'.tr()),
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            ElevatedButton(
              onPressed: _savingZone ? null : () async {
                final data = {
                  'name': nameCtrl.text,
                  'fee': double.tryParse(feeCtrl.text) ?? 0,
                  if (minCtrl.text.isNotEmpty) 'minOrderAmount': double.tryParse(minCtrl.text),
                  if (daysCtrl.text.isNotEmpty) 'estimatedDays': int.tryParse(daysCtrl.text),
                  if (countriesCtrl.text.isNotEmpty) 'countries': countriesCtrl.text,
                  'isActive': active,
                };
                Navigator.pop(ctx);
                await _saveDeliveryZone(existing, data);
              },
              child: _savingZone
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing != null ? 'common.edit'.tr() : 'common.add'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  Color _darken(Color c, double amount) {
    final r = ((c.r * 255).round() * (1 - amount)).round().clamp(0, 255);
    final g = ((c.g * 255).round() * (1 - amount)).round().clamp(0, 255);
    final b = ((c.b * 255).round() * (1 - amount)).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  Color _lighten(Color c, double amount) {
    final r = ((c.r * 255).round() + (255 - (c.r * 255).round()) * amount)
        .round()
        .clamp(0, 255);
    final g = ((c.g * 255).round() + (255 - (c.g * 255).round()) * amount)
        .round()
        .clamp(0, 255);
    final b = ((c.b * 255).round() + (255 - (c.b * 255).round()) * amount)
        .round()
        .clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  void _generateRandomPalette() {
    final base = Color((Random().nextDouble() * 0xFFFFFF).toInt())
        .withValues(alpha: 1.0);
    setState(() {
      _headerColor = base;
      _footerColor = _darken(base, 0.1);
      _bodyColor = _lighten(base, 0.6);
      _cardProductColor = _lighten(base, 0.2);
      _buttonColor = _darken(base, 0.2);
      _topBarColor = _darken(base, 0.3);
      _textColor = Colors.white;
    });
  }

  void _onNameChanged(String value) {
    _nameCtrl.value = _nameCtrl.value.copyWith(
      text: value.toLowerCase(),
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (value == _originalName) {
      setState(() {
        _nameAvailable = true;
        _nameHelperText = 'boutique.original_name'.tr();
        _nameHelperColor = AppColors.success;
      });
      return;
    }
    setState(() {
      _nameAvailable = false;
      _nameHelperText = 'common.loading'.tr();
      _nameHelperColor = AppColors.primary;
    });
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), () => _checkName(value));
  }

  Future<void> _checkName(String name) async {
    final bp = context.read<BoutiqueProvider>();
    final res = await bp.checkName(name, currentId: bp.currentBoutique?.id);
    final data = res['data'] as Map?;
    final available = data?['available'] == true;
    setState(() {
      _nameAvailable = available;
      _nameHelperText = available
          ? 'boutique.name_available'.tr()
          : 'boutique.name_unavailable'.tr();
      _nameHelperColor = available ? AppColors.success : AppColors.danger;
    });
  }

  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    return await picker.pickImage(source: ImageSource.gallery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _topBarTextCtrl.dispose();
    _phoneCtrl.dispose();
    _tvaCtrl.dispose();
    _deliveryFeesCtrl.dispose();
    _konnectMerchantCtrl.dispose();
    _konnectApiCtrl.dispose();
    _d17MerchantCtrl.dispose();
    _countryCtrl.dispose();
    _categoryNameCtrl.dispose();
    _categorySortCtrl.dispose();
    _customJsCtrl.dispose();
    _customCssCtrl.dispose();
    _fbPageTokenCtrl.dispose();
    _fbPageIdCtrl.dispose();
    _seoTitleCtrl.dispose();
    _seoDescCtrl.dispose();
    _seoKeywordsCtrl.dispose();
    _stripePublishableCtrl.dispose();
    _stripeSecretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BoutiqueProvider>();
    final b = bp.currentBoutique;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('boutique.title'.tr()),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : b == null
              ? Center(child: Text('store_catalog.title'.tr()))
              : _buildContent(bp, b),
    );
  }

  Widget _buildContent(BoutiqueProvider bp, Boutique b) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== 1. BOUTIQUE CONFIG ==========
          _SettingsCard(
            title: 'boutique.general'.tr(),
            icon: Icons.store_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormRow(children: [
                  _FormField(
                      label: 'boutique.email'.tr(),
                      controller: _emailCtrl,
                      type: TextInputType.emailAddress),
                  _FormField(label: 'boutique.address'.tr(), controller: _addressCtrl),
                ]),
                const SizedBox(height: 12),
                _FormField(
                  label: 'boutique.name'.tr(),
                  controller: _nameCtrl,
                  hint: 'boutique.slug_help'.tr(),
                  onChanged: _onNameChanged,
                  suffix: _nameHelperText != null
                      ? Text(_nameHelperText!,
                          style: AppTypography.caption
                              .copyWith(color: _nameHelperColor))
                      : null,
                ),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _FormField(
                      label: 'boutique.announcement'.tr(),
                      controller: _topBarTextCtrl,
                      hint: 'boutique.announcement_hint'.tr()),
                  _FormField(
                      label: 'boutique.phone'.tr(),
                      controller: _phoneCtrl,
                      type: TextInputType.phone),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _FormField(
                      label: 'boutique.vat'.tr(),
                      controller: _tvaCtrl,
                      type: TextInputType.number),
                  _FormField(
                      label: 'boutique.delivery_fees'.tr(),
                      controller: _deliveryFeesCtrl,
                      type: TextInputType.number),
                ]),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingConfig,
                  disabled: !_nameAvailable,
                  onPressed: _nameAvailable ? () => _saveConfig(bp) : null,
                ),
                if (_nameHelperText != null) ...[
                  const SizedBox(height: 4),
                  Text(_nameHelperText!,
                      style: AppTypography.caption
                          .copyWith(color: _nameHelperColor)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 2. SEO ==========
          _SettingsCard(
            title: 'boutique.seo'.tr(),
            icon: Icons.search_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(label: 'boutique.meta_title'.tr(), controller: _seoTitleCtrl, hint: 'boutique.meta_title_hint'.tr()),
                const SizedBox(height: 12),
                _FormField(label: 'boutique.meta_description'.tr(), controller: _seoDescCtrl, maxLines: 3, hint: 'boutique.meta_desc_hint'.tr()),
                const SizedBox(height: 12),
                _FormField(label: 'boutique.meta_keywords'.tr(), controller: _seoKeywordsCtrl, hint: 'boutique.meta_keywords_hint'.tr()),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.save'.tr(),
                  onPressed: () async {
                    final ok = await bp.updateSeo({
                      'seoTitle': _seoTitleCtrl.text,
                      'seoDescription': _seoDescCtrl.text,
                      'seoKeywords': _seoKeywordsCtrl.text,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'boutique.updated'.tr() : 'common.error'.tr()),
                        backgroundColor: ok ? AppColors.success : AppColors.danger));
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 3. PAIEMENT À LA LIVRAISON ==========
          _SettingsCard(
            title: 'boutique.cash_on_delivery'.tr(),
            icon: Icons.money_outlined,
            child: _ToggleRow(
              label: 'boutique.cash_on_delivery'.tr(),
              value: _cashDelivery,
              onChanged: (v) async {
                setState(() => _cashDelivery = v);
                await bp.saveConfig({'cashDelivery': v ? 'yes' : 'no'});
              },
            ),
          ),
          const SizedBox(height: 16),

          // ========== 3. KONNECT PAYMENT ==========
          _SettingsCard(
            title: 'boutique.konnect'.tr(),
            icon: Icons.payment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormRow(children: [
                  _FormField(
                      label: 'boutique.konnect_merchant'.tr(),
                      controller: _konnectMerchantCtrl),
                  _FormField(
                      label: 'boutique.konnect_api'.tr(), controller: _konnectApiCtrl),
                ]),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'boutique.konnect'.tr(),
                  value: _konnectEnabled,
                  loading: _savingKonnect,
                  onChanged: (v) async {
                    setState(() => _savingKonnect = true);
                    setState(() => _konnectEnabled = v);
                    await bp.saveConfig({'konnectStatus': v ? 'active' : 'inactive'});
                    setState(() => _savingKonnect = false);
                  },
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'common.save'.tr(),
                  onPressed: () => _saveConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 4. D17 PAYMENT ==========
          _SettingsCard(
            title: 'boutique.d17'.tr(),
            icon: Icons.qr_code_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'boutique.d17_merchant'.tr(),
                  controller: _d17MerchantCtrl,
                  hint: 'boutique.d17_hint'.tr(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_d17QrCodeUrl != null && _d17QrCodeUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Image.network(_d17QrCodeUrl!,
                            width: 80,
                            height: 80,
                            errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image))),
                      ),
                    IntrinsicWidth(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: Text(_d17QrCodeUrl == null
                            ? 'boutique.upload_qr'.tr()
                            : 'boutique.change_qr'.tr()),
                        onPressed: () async {
                          final path = await _pickImage();
                          if (path != null) {
                            try {
                              final url = await ApiClient.uploadImage(path);
                              if (url.isNotEmpty) {
                                setState(() => _d17QrCodeUrl = url);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('common.success'.tr()),
                                          backgroundColor: AppColors.success));
                                }
                              }
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('common.error'.tr()),
                                        backgroundColor: AppColors.danger));
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                          foregroundColor: AppColors.textPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'boutique.d17'.tr(),
                  value: _d17Enabled,
                  loading: _savingD17,
                  onChanged: (v) async {
                    setState(() => _savingD17 = true);
                    setState(() => _d17Enabled = v);
                    await bp.saveConfig({'d17Status': v ? 'active' : 'inactive'});
                    setState(() => _savingD17 = false);
                  },
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'common.save'.tr(),
                  onPressed: () => _saveConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 5. STRIPE ==========
          _SettingsCard(
            title: 'boutique.stripe'.tr(),
            icon: Icons.payment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('boutique.stripe_config'.tr(),
                    style: AppTypography.caption),
                const SizedBox(height: 16),
                _FormField(label: 'boutique.stripe_publishable'.tr(), controller: _stripePublishableCtrl, hint: 'boutique.stripe_pk_hint'.tr()),
                const SizedBox(height: 12),
                _FormField(label: 'boutique.stripe_secret'.tr(), controller: _stripeSecretCtrl, hint: 'boutique.stripe_sk_hint'.tr(), maxLines: 2),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingPayments,
                  onPressed: () async {
                    setState(() => _savingPayments = true);
                    final ok = await bp.updatePayments({
                      'stripePublishableKey': _stripePublishableCtrl.text,
                      'stripeSecretKey': _stripeSecretCtrl.text,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'boutique.updated'.tr() : 'common.error'.tr()),
                        backgroundColor: ok ? AppColors.success : AppColors.danger));
                    }
                    setState(() => _savingPayments = false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 6. FORMULAIRE SIMPLIFIÉ ==========
          _SettingsCard(
            title: 'boutique.simplified_checkout'.tr(),
            icon: Icons.receipt_long_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'boutique.simplified_checkout_desc'.tr(),
                    style: AppTypography.caption),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'boutique.simplified_checkout'.tr(),
                  value: _simpleCheckout,
                  onChanged: (v) async {
                    setState(() => _simpleCheckout = v);
                    await bp.saveConfig({'simpleCheckout': v ? 'yes' : 'no'});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 6. FACEBOOK META BUSINESS ==========
          _SettingsCard(
            title: 'boutique.facebook'.tr(),
            icon: Icons.facebook_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'boutique.facebook_token'.tr(),
                  controller: _fbPageTokenCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'boutique.facebook_page_id'.tr(),
                  controller: _fbPageIdCtrl,
                ),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingFb,
                  onPressed: () => _saveFacebookConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 7. THEME CUSTOMIZATION ==========
          _SettingsCard(
            title: 'boutique.theme'.tr(),
            icon: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThemePreview(),
                const SizedBox(height: 16),
                _FormRow(children: [
                  _ColorPickerField(
                      label: "boutique.header_color".tr(),
                      color: _headerColor,
                      onChanged: (c) => setState(() => _headerColor = c)),
                  _ColorPickerField(
                      label: 'boutique.footer_color'.tr(),
                      color: _footerColor,
                      onChanged: (c) => setState(() => _footerColor = c)),
                  _ColorPickerField(
                      label: 'boutique.body_color'.tr(),
                      color: _bodyColor,
                      onChanged: (c) => setState(() => _bodyColor = c)),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _ColorPickerField(
                      label: 'boutique.card_color'.tr(),
                      color: _cardProductColor,
                      onChanged: (c) => setState(() => _cardProductColor = c)),
                  _ColorPickerField(
                      label: 'boutique.button_color'.tr(),
                      color: _buttonColor,
                      onChanged: (c) => setState(() => _buttonColor = c)),
                  _ColorPickerField(
                      label: 'boutique.top_bar_color'.tr(),
                      color: _topBarColor,
                      onChanged: (c) => setState(() => _topBarColor = c)),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _ColorPickerField(
                      label: 'boutique.text_color'.tr(),
                      color: _textColor,
                      onChanged: (c) => setState(() => _textColor = c)),
                ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('boutique.fonts'.tr(), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _fontFamily,
                            items: ['Inter', 'Poppins', 'Roboto', 'Playfair Display', 'Montserrat']
                                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) => setState(() => _fontFamily = v ?? 'Inter'),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('boutique.dark_mode'.tr(), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          SwitchListTile(
                            value: _darkMode,
                            onChanged: (v) async {
                              setState(() => _darkMode = v);
                              await bp.saveStoreTheme({'darkMode': v ? 'yes' : 'no'});
                            },
                            title: Text(_darkMode ? 'common.enabled'.tr() : 'common.disabled'.tr(), style: const TextStyle(fontSize: 13)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IntrinsicWidth(
                      child: _SaveButton(
                        label: 'common.save'.tr(),
                        loading: _savingTheme,
                        onPressed: () => _saveTheme(bp),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IntrinsicWidth(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: Text('boutique.random_palette'.tr()),
                        onPressed: _generateRandomPalette,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 8. NOTIFICATIONS ==========
          _SettingsCard(
            title: 'boutique.notifications'.tr(),
            icon: Icons.notifications_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ToggleRow(label: 'boutique.email_notifications'.tr(), value: _enableEmailNotif, loading: _savingNotifEmail, onChanged: (v) async {
                  setState(() => _savingNotifEmail = true);
                  setState(() => _enableEmailNotif = v);
                  await bp.saveNotificationSettings({'enableEmailNotifications': v ? 'yes' : 'no'});
                  setState(() => _savingNotifEmail = false);
                }),
                _ToggleRow(label: 'boutique.sms_notifications'.tr(), value: _enableSmsNotif, loading: _savingNotifSms, onChanged: (v) async {
                  setState(() => _savingNotifSms = true);
                  setState(() => _enableSmsNotif = v);
                  await bp.saveNotificationSettings({'enableSmsNotifications': v ? 'yes' : 'no'});
                  setState(() => _savingNotifSms = false);
                }),
                _ToggleRow(label: 'boutique.push_notifications'.tr(), value: _enablePushNotif, loading: _savingNotifPush, onChanged: (v) async {
                  setState(() => _savingNotifPush = true);
                  setState(() => _enablePushNotif = v);
                  await bp.saveNotificationSettings({'enablePushNotifications': v ? 'yes' : 'no'});
                  setState(() => _savingNotifPush = false);
                }),
                _ToggleRow(label: 'boutique.order_alerts'.tr(), value: _enableOrderAlerts, loading: _savingNotifAlerts, onChanged: (v) async {
                  setState(() => _savingNotifAlerts = true);
                  setState(() => _enableOrderAlerts = v);
                  await bp.saveNotificationSettings({'enableOrderAlerts': v ? 'yes' : 'no'});
                  setState(() => _savingNotifAlerts = false);
                }),
                _ToggleRow(label: 'boutique.marketing_emails'.tr(), value: _enableMarketingEmails, loading: _savingNotifMarketing, onChanged: (v) async {
                  setState(() => _savingNotifMarketing = true);
                  setState(() => _enableMarketingEmails = v);
                  await bp.saveNotificationSettings({'enableMarketingEmails': v ? 'yes' : 'no'});
                  setState(() => _savingNotifMarketing = false);
                }),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingNotif,
                  onPressed: () async {
                    setState(() => _savingNotif = true);
                    final ok = await bp.saveNotificationSettings({
                      'enableEmailNotifications': _enableEmailNotif ? 'yes' : 'no',
                      'enableSmsNotifications': _enableSmsNotif ? 'yes' : 'no',
                      'enablePushNotifications': _enablePushNotif ? 'yes' : 'no',
                      'enableOrderAlerts': _enableOrderAlerts ? 'yes' : 'no',
                      'enableMarketingEmails': _enableMarketingEmails ? 'yes' : 'no',
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'boutique.updated'.tr() : 'common.error'.tr()),
                        backgroundColor: ok ? AppColors.success : AppColors.danger));
                    }
                    setState(() => _savingNotif = false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 9. ZONES DE LIVRAISON ==========
          _SettingsCard(
            title: 'boutique.delivery_zones'.tr(),
            icon: Icons.local_shipping_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showDeliveryZoneDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('common.add'.tr()),
                    ),
                  ],
                ),
                if (_loadingZones)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (_deliveryZones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('boutique.no_zones'.tr(), style: const TextStyle(color: AppColors.textHint)),
                  )
                else
                  ..._deliveryZones.map((dz) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(dz.name, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                                        if (!dz.isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.textHint.withAlpha(30),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text('common.inactive'.tr(), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${dz.fee.toStringAsFixed(2)} DT${dz.estimatedDays != null ? ' · ${dz.estimatedDays} jours' : ''}${dz.minOrderAmount != null ? ' · min ${dz.minOrderAmount!.toStringAsFixed(2)} DT' : ''}', style: AppTypography.caption),
                                    if (dz.countries != null && dz.countries!.isNotEmpty)
                                      Text(dz.countries!, style: AppTypography.caption),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showDeliveryZoneDialog(existing: dz),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                onPressed: () => _deleteDeliveryZone(dz),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 10. PAYS ACCEPTES ==========
          _SettingsCard(
            title: 'boutique.countries'.tr(),
            icon: Icons.public_outlined,
            child: _buildAcceptedCountries(bp),
          ),
          const SizedBox(height: 16),
          // ========== 11. CATEGORIES ==========
          _SettingsCard(
            title: 'boutique.categories'.tr(),
            icon: Icons.category_outlined,
            child: Consumer<ProductsProvider>(
              builder: (_, pp, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pp.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('boutique.no_categories'.tr(),
                          style: AppTypography.body2),
                    )
                  else
                    ...pp.categories.map((category) => _CategoryRow(
                          category: category,
                          onEdit: () =>
                              _showCategoryDialog(bp, existing: category),
                          onDelete: () => _deleteCategory(pp, category),
                        )),
                  const SizedBox(height: 12),
                  _SaveButton(
                    label: 'common.add'.tr(),
                    loading: _savingCategory,
                    onPressed: () => _showCategoryDialog(bp),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ========== 12. LOGO BOUTIQUE ==========
          _SettingsCard(
            title: 'boutique.logo'.tr(),
            icon: Icons.image_outlined,
            child: Column(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: _logoUrl != null && _logoUrl!.isNotEmpty
                        ? NetworkImage(_logoUrl!)
                        : null,
                    child: _logoUrl == null || _logoUrl!.isEmpty
                        ? const Icon(Icons.store,
                            size: 48, color: AppColors.textHint)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_logoUrl != null ? 'boutique.current_logo'.tr() : 'boutique.no_logo'.tr(),
                    style: AppTypography.body2),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.upload'.tr(),
                  loading: _uploadingLogo,
                  onPressed: () => _uploadLogo(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 13. DEVISE ==========
          _SettingsCard(
            title: 'boutique.currency'.tr(),
            icon: Icons.attach_money_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyField(
                    label: 'boutique.current_currency'.tr(), value: b.currency ?? 'TND'),
                const SizedBox(height: 12),
                _DropdownField(
                  label: 'boutique.new_currency'.tr(),
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v ?? 'TND'),
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingCurrency,
                  onPressed: () => _saveCurrency(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 14. CODE PERSONNALISÉ ==========
          _SettingsCard(
            title: 'boutique.custom_code'.tr(),
            icon: Icons.code_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('boutique.custom_code_desc'.tr(),
                    style: AppTypography.caption),
                const SizedBox(height: 12),
                _CodeEditorField(
                    label: 'boutique.custom_js'.tr(), hintText: 'boutique.js_hint'.tr(), controller: _customJsCtrl),
                const SizedBox(height: 16),
                _CodeEditorField(label: 'boutique.custom_css'.tr(), hintText: 'boutique.css_hint'.tr(), controller: _customCssCtrl),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'common.save'.tr(),
                  loading: _savingCode,
                  onPressed: () => _saveCustomCode(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ========== THEME PREVIEW ==========
  Widget _buildThemePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bodyColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: _topBarColor, borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_offer, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text('boutique.announcement'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _headerColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                        color: _buttonColor,
                        borderRadius: BorderRadius.circular(4))),
                const Spacer(),
                Icon(Icons.shopping_cart_outlined, size: 18, color: _textColor),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardProductColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                    height: 50,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 8, width: 80, color: Colors.grey[400]),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _buttonColor,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('common.add'.tr(),
                      style: TextStyle(color: _textColor, fontSize: 10)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _footerColor, borderRadius: BorderRadius.circular(6)),
            child: Text('boutique.copyright'.tr(),
                style: TextStyle(color: _textColor, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedCountries(BoutiqueProvider bp) {
    final selected = bp.countries.toSet();

    if (bp.countriesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selected.isEmpty
              ? 'boutique.no_countries'.tr()
              : 'boutique.countries_selected'.tr(args: [selected.length.toString()]),
          style: AppTypography.body2,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _acceptedCountryOptions.entries.map((entry) {
            final checked = selected.contains(entry.key);
            return FilterChip(
              label: Text('${entry.value} (${entry.key})'),
              selected: checked,
              onSelected: bp.savingCountries
                  ? null
                  : (value) async {
                      final next = Set<String>.from(selected);
                      value ? next.add(entry.key) : next.remove(entry.key);
                      final ok = await bp.saveCountries(next.toList());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'boutique.updated'.tr()
                          : bp.error ?? 'common.error'.tr()),
                        backgroundColor:
                            ok ? AppColors.success : AppColors.danger,
                      ));
                    },
            );
          }).toList(),
        ),
        if (bp.savingCountries) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }

  // ========== SAVE METHODS ==========

  Future<void> _saveConfig(BoutiqueProvider bp) async {
    setState(() => _savingConfig = true);
    await bp.saveConfig({
      'email': _emailCtrl.text,
      'address': _addressCtrl.text,
      'companyName': _nameCtrl.text,
      'topBarText': _topBarTextCtrl.text,
      'phone': _phoneCtrl.text,
      'tva': _tvaCtrl.text,
      'deliveryFees': _deliveryFeesCtrl.text,
      'cashDelivery': _cashDelivery ? 'yes' : 'no',
      'konnectMerchantId': _konnectMerchantCtrl.text,
      'konnectApiKey': _konnectApiCtrl.text,
      'konnectStatus': _konnectEnabled ? 'active' : 'inactive',
      'd17MerchantNumber': _d17MerchantCtrl.text,
      'd17QrCodeUrl': _d17QrCodeUrl ?? '',
      'd17Status': _d17Enabled ? 'active' : 'inactive',
      'simpleCheckout': _simpleCheckout ? 'yes' : 'no',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('boutique.updated'.tr()),
          backgroundColor: AppColors.success));
    }
    setState(() => _savingConfig = false);
  }

  Future<void> _saveTheme(BoutiqueProvider bp) async {
    setState(() => _savingTheme = true);
    final success = await bp.saveStoreTheme({
      'headerColor': _colorToHex(_headerColor),
      'footerColor': _colorToHex(_footerColor),
      'bodyColor': _colorToHex(_bodyColor),
      'cardProductColor': _colorToHex(_cardProductColor),
      'buttonColor': _colorToHex(_buttonColor),
      'topBarColor': _colorToHex(_topBarColor),
      'textColor': _colorToHex(_textColor),
      'fontFamily': _fontFamily,
      'darkMode': _darkMode,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'boutique.updated'.tr() : 'common.error'.tr()),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _savingTheme = false);
  }

  Future<void> _saveFacebookConfig(BoutiqueProvider bp) async {
    setState(() => _savingFb = true);
    final success = await bp.saveFacebookConfig({
      'pageAccessToken': _fbPageTokenCtrl.text,
      'pageId': _fbPageIdCtrl.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'boutique.updated'.tr() : 'common.error'.tr()),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _savingFb = false);
  }

  Future<void> _saveCustomCode(BoutiqueProvider bp) async {
    setState(() => _savingCode = true);
    final success = await bp.saveCustomCode({
      'customJs': _customJsCtrl.text,
      'customCss': _customCssCtrl.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'boutique.updated'.tr() : 'common.error'.tr()),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _savingCode = false);
  }

  Future<void> _saveCurrency(BoutiqueProvider bp) async {
    setState(() => _savingCurrency = true);
    final success = await bp.saveCurrency(_currency);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'boutique.updated'.tr() : 'common.error'.tr()),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _savingCurrency = false);
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s-]"), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  Future<void> _showCategoryDialog(BoutiqueProvider bp,
      {Category? existing}) async {
    final pp = context.read<ProductsProvider>();
    final boutiqueId = bp.currentBoutique?.id;
    if (boutiqueId == null) return;

    _categoryNameCtrl.text = existing?.name ?? '';
    _categorySortCtrl.text = existing?.sortOrder.toString() ?? '0';
    var imageUrl = existing?.imageUrl;
    var uploadingImage = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'boutique.add_category'.tr()
              : 'boutique.edit_category'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'boutique.name'.tr(),
                  controller: _categoryNameCtrl,
                  hint: 'boutique.category_name_hint'.tr(),
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'boutique.sort_order'.tr(),
                  controller: _categorySortCtrl,
                  type: TextInputType.number,
                  hint: '0',
                ),
                const SizedBox(height: 12),
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl!,
                        height: 90,
                        width: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 90,
                          width: 140,
                          color: AppColors.surfaceAlt,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: uploadingImage
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined, size: 18),
                  label: Text(imageUrl == null || imageUrl!.isEmpty
                      ? 'common.add_image'.tr()
                      : 'common.change_image'.tr()),
                  onPressed: uploadingImage
                      ? null
                      : () async {
                          final file = await _pickImage();
                          if (file == null) return;
                          setDialogState(() => uploadingImage = true);
                          try {
                            final url = await ApiClient.uploadImage(file);
                            setDialogState(() => imageUrl = url);
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('common.error'.tr()),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => uploadingImage = false);
                          }
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: uploadingImage
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = _categoryNameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('boutique.category_name_required'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    setState(() => _savingCategory = true);
    final data = {
      'boutiqueId': boutiqueId,
      'name': name,
      'slug': _slugify(name),
      'imageUrl': imageUrl,
      'sortOrder': int.tryParse(_categorySortCtrl.text.trim()) ?? 0,
    };
    final result = existing == null
        ? await pp.createCategory(data)
        : await pp.updateCategory(existing.id, data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result != null
            ? 'boutique.updated'.tr()
            : pp.error ?? 'common.error'.tr()),
        backgroundColor: result != null ? AppColors.success : AppColors.danger,
      ));
    }
    setState(() => _savingCategory = false);
  }

  Future<void> _deleteCategory(ProductsProvider pp, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text('common.delete_confirm'.tr(args: [category.name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await pp.deleteCategory(category.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'boutique.updated'.tr() : pp.error ?? 'common.error'.tr()),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ));
    }
  }

  Future<void> _uploadLogo(BoutiqueProvider bp) async {
    final xfile = await _pickImage();
    if (xfile == null) return;
    setState(() => _uploadingLogo = true);
    final success = await bp.uploadLogo(xfile);
    if (success) {
      _logoUrl = bp.currentBoutique?.logoUrl;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'boutique.updated'.tr() : 'common.error'.tr()),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _uploadingLogo = false);
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: category.imageUrl == null || category.imageUrl!.isEmpty
                ? Container(
                    width: 44,
                    height: 44,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.category_outlined,
                        color: AppColors.textHint),
                  )
                : Image.network(
                    category.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: AppColors.surfaceAlt,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.textHint),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: AppTypography.body2),
                Text(category.slug, style: AppTypography.caption),
              ],
            ),
          ),
          Text('#${category.sortOrder}', style: AppTypography.caption),
          IconButton(
            tooltip: 'common.edit'.tr(),
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'common.delete'.tr(),
            icon: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ============ SETTINGS CARD ============
class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SettingsCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: AppTypography.heading4),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ============ TOGGLE ROW ============
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool loading;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        loading
            ? const SizedBox(width: 40, height: 24, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
            : Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.primary,
              ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.body2),
      ],
    );
  }
}

// ============ FORM ROW ============
class _FormRow extends StatelessWidget {
  final List<Widget> children;
  const _FormRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChildWidth = constraints.maxWidth;
        final childWidth = maxChildWidth < 400
            ? maxChildWidth
            : (maxChildWidth - (children.length - 1) * 12) / children.length;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(
                  width: childWidth.clamp(200, 400), child: child))
              .toList(),
        );
      },
    );
  }
}

// ============ FORM FIELD ============
class _FormField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? type;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const _FormField({
    required this.label,
    this.hint,
    this.controller,
    this.type,
    this.maxLines,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines ?? 1,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary)),
            suffixIcon: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8), child: suffix)
                : null,
          ),
        ),
      ],
    );
  }
}

// ============ READ-ONLY FIELD ============
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(value, style: AppTypography.body2),
        ),
      ],
    );
  }
}

// ============ DROPDOWN FIELD ============
class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          ),
        ),
      ],
    );
  }
}

// ============ COLOR PICKER FIELD ============
class _ColorPickerField extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorPickerField(
      {required this.label, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label,
              style:
                  AppTypography.caption.copyWith(fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: () {
            Color picked = color;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(label),
                content: SingleChildScrollView(
                  child: ColorPicker(
                    pickerColor: color,
                    onColorChanged: (c) => picked = c,
                    enableAlpha: false,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      onChanged(picked);
                      Navigator.pop(ctx);
                    },
                      child: Text('common.confirm'.tr()),
                  ),
                ],
              ),
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
}

// ============ CODE EDITOR FIELD ============
class _CodeEditorField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  const _CodeEditorField({required this.label, this.hintText, this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label,
              style:
                  AppTypography.caption.copyWith(fontWeight: FontWeight.w500)),
        ),
        TextField(
          controller: controller,
          maxLines: 6,
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, color: Color(0xFF1E1E1E)),
          decoration: InputDecoration(
            hintText: hintText ?? '// code here...'.tr(),
            filled: true,
            fillColor: const Color(0xFF282A36),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            hintStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFF6272A4)),
          ),
        ),
      ],
    );
  }
}

// ============ SAVE BUTTON ============
class _SaveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool disabled;
  final bool loading;
  const _SaveButton({
    required this.label,
    this.onPressed,
    this.disabled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: (disabled || loading) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? Colors.grey[300] : AppColors.primary,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.grey[500],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
