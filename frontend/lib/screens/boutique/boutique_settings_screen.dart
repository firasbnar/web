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
import '../../models/product.dart';

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
    _emailCtrl.text = b.seoTitle ?? '';
    _addressCtrl.text = b.description ?? '';
    _topBarTextCtrl.text = b.announcementText ?? '';
    _phoneCtrl.text = b.whatsappNumber ?? '';
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
    _fbPageTokenCtrl.text = '';
    _fbPageIdCtrl.text = b.facebookPixelId ?? '';

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
    setState(() => _loading = false);
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFededed);
    }
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
        _nameHelperText = 'Nom original';
        _nameHelperColor = AppColors.success;
      });
      return;
    }
    setState(() {
      _nameAvailable = false;
      _nameHelperText = 'Vérification...';
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
          ? 'Disponible - Vous pouvez sauvegarder'
          : 'Nom non disponible - Veuillez choisir un autre';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BoutiqueProvider>();
    final b = bp.currentBoutique;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : b == null
              ? const Center(child: Text('Aucune boutique sélectionnée'))
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
            title: 'Configuration de la boutique',
            icon: Icons.store_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormRow(children: [
                  _FormField(
                      label: 'Email',
                      controller: _emailCtrl,
                      type: TextInputType.emailAddress),
                  _FormField(label: 'Adresse', controller: _addressCtrl),
                ]),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Nom de la boutique (minuscules)',
                  controller: _nameCtrl,
                  hint: 'ma-boutique',
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
                      label: 'Texte promotionnel barre',
                      controller: _topBarTextCtrl,
                      hint: 'Livraison 48h'),
                  _FormField(
                      label: 'Téléphone',
                      controller: _phoneCtrl,
                      type: TextInputType.phone),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _FormField(
                      label: 'TVA (%)',
                      controller: _tvaCtrl,
                      type: TextInputType.number),
                  _FormField(
                      label: 'Frais de livraison (TND)',
                      controller: _deliveryFeesCtrl,
                      type: TextInputType.number),
                ]),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'Enregistrer la configuration',
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

          // ========== 2. PAIEMENT À LA LIVRAISON ==========
          _SettingsCard(
            title: 'Paiement à la livraison',
            icon: Icons.money_outlined,
            child: _ToggleRow(
              label: 'Activer le paiement à la livraison',
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
            title: 'Konnect Payment',
            icon: Icons.payment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormRow(children: [
                  _FormField(
                      label: 'ID Marchand Konnect',
                      controller: _konnectMerchantCtrl),
                  _FormField(
                      label: 'Clé API Konnect', controller: _konnectApiCtrl),
                ]),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'Activer Konnect',
                  value: _konnectEnabled,
                  onChanged: (v) => setState(() => _konnectEnabled = v),
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'Sauvegarder Konnect',
                  onPressed: () => _saveConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 4. D17 PAYMENT ==========
          _SettingsCard(
            title: 'Paiement D17',
            icon: Icons.qr_code_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'Numéro marchand D17',
                  controller: _d17MerchantCtrl,
                  hint: 'Ex: 40123456',
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
                            ? 'Upload QR Code'
                            : 'Changer QR Code'),
                        onPressed: () async {
                          final path = await _pickImage();
                          if (path != null) {
                            try {
                              final url = await ApiClient.uploadImage(path);
                              if (url.isNotEmpty) {
                                setState(() => _d17QrCodeUrl = url);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('QR Code uploadé'),
                                          backgroundColor: AppColors.success));
                                }
                              }
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Erreur upload QR Code'),
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
                  label: 'Activer D17',
                  value: _d17Enabled,
                  onChanged: (v) => setState(() => _d17Enabled = v),
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'Sauvegarder D17',
                  onPressed: () => _saveConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 5. FORMULAIRE SIMPLIFIÉ ==========
          _SettingsCard(
            title: 'Formulaire de commande simplifié',
            icon: Icons.receipt_long_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Activer pour ne demander que le nom, téléphone et adresse',
                    style: AppTypography.caption),
                const SizedBox(height: 8),
                _ToggleRow(
                  label: 'Commande simplifiée',
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
            title: 'Facebook Meta Business',
            icon: Icons.facebook_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'Facebook Page Access Token',
                  controller: _fbPageTokenCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Facebook Page ID',
                  controller: _fbPageIdCtrl,
                ),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'Sauvegarder Facebook',
                  loading: _savingFb,
                  onPressed: () => _saveFacebookConfig(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 7. THEME CUSTOMIZATION ==========
          _SettingsCard(
            title: 'Personnalisation du thème',
            icon: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThemePreview(),
                const SizedBox(height: 16),
                _FormRow(children: [
                  _ColorPickerField(
                      label: "En-tête",
                      color: _headerColor,
                      onChanged: (c) => setState(() => _headerColor = c)),
                  _ColorPickerField(
                      label: 'Pied de page',
                      color: _footerColor,
                      onChanged: (c) => setState(() => _footerColor = c)),
                  _ColorPickerField(
                      label: 'Fond',
                      color: _bodyColor,
                      onChanged: (c) => setState(() => _bodyColor = c)),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _ColorPickerField(
                      label: 'Cartes produit',
                      color: _cardProductColor,
                      onChanged: (c) => setState(() => _cardProductColor = c)),
                  _ColorPickerField(
                      label: 'Boutons',
                      color: _buttonColor,
                      onChanged: (c) => setState(() => _buttonColor = c)),
                  _ColorPickerField(
                      label: 'Barre promo',
                      color: _topBarColor,
                      onChanged: (c) => setState(() => _topBarColor = c)),
                ]),
                const SizedBox(height: 12),
                _FormRow(children: [
                  _ColorPickerField(
                      label: 'Texte',
                      color: _textColor,
                      onChanged: (c) => setState(() => _textColor = c)),
                ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IntrinsicWidth(
                      child: _SaveButton(
                        label: 'Sauvegarder le thème',
                        loading: _savingTheme,
                        onPressed: () => _saveTheme(bp),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IntrinsicWidth(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: const Text('Palette aléatoire'),
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

          // ========== 8. PAYS ACCEPTÉS ==========
          _SettingsCard(
            title: 'Pays acceptés',
            icon: Icons.public_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bp.countries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        Text('Aucun pays ajouté', style: AppTypography.body2),
                  )
                else
                  ...bp.countries.map((country) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.success),
                            const SizedBox(width: 8),
                            Text(country, style: AppTypography.body2),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: AppColors.danger, size: 20),
                              onPressed: () => bp.deleteCountry(country),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _countryCtrl,
                        decoration: const InputDecoration(
                          hintText: 'ex: Tunisie, France',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IntrinsicWidth(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_countryCtrl.text.isNotEmpty) {
                            bp.addCountry(_countryCtrl.text);
                            _countryCtrl.clear();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Ajouter'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 9. CATEGORIES ==========
          _SettingsCard(
            title: 'Catégories',
            icon: Icons.category_outlined,
            child: Consumer<ProductsProvider>(
              builder: (_, pp, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pp.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Aucune catégorie ajoutée',
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
                    label: 'Ajouter une catégorie',
                    loading: _savingCategory,
                    onPressed: () => _showCategoryDialog(bp),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ========== 10. LOGO BOUTIQUE ==========
          _SettingsCard(
            title: 'Logo de la boutique',
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
                Text(_logoUrl != null ? 'Logo actuel' : 'Aucun logo',
                    style: AppTypography.body2),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'Uploader un logo',
                  loading: _uploadingLogo,
                  onPressed: () => _uploadLogo(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 10. DEVISE ==========
          _SettingsCard(
            title: 'Devise',
            icon: Icons.attach_money_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReadOnlyField(
                    label: 'Devise actuelle', value: b.currency ?? 'TND'),
                const SizedBox(height: 12),
                _DropdownField(
                  label: 'Nouvelle devise',
                  value: _currency,
                  items: _currencies,
                  onChanged: (v) => setState(() => _currency = v ?? 'TND'),
                ),
                const SizedBox(height: 12),
                _SaveButton(
                  label: 'Mettre à jour la devise',
                  loading: _savingCurrency,
                  onPressed: () => _saveCurrency(bp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ========== 11. CODE PERSONNALISÉ ==========
          _SettingsCard(
            title: 'Code personnalisé',
            icon: Icons.code_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajoutez du JavaScript et CSS personnalisés',
                    style: AppTypography.caption),
                const SizedBox(height: 12),
                _CodeEditorField(
                    label: 'JavaScript', controller: _customJsCtrl),
                const SizedBox(height: 16),
                _CodeEditorField(label: 'CSS', controller: _customCssCtrl),
                const SizedBox(height: 16),
                _SaveButton(
                  label: 'Sauvegarder le code',
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('Promo - Livraison offerte',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
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
                  child: Text('Ajouter',
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
            child: Text('© 2026 Ma Boutique',
                style: TextStyle(color: _textColor, fontSize: 9)),
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configuration sauvegardée'),
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
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Thème mis à jour' : 'Erreur'),
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
          content: Text(success ? 'Facebook sauvegardé' : 'Erreur'),
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
          content: Text(success ? 'Code mis à jour' : 'Erreur'),
          backgroundColor: success ? AppColors.success : AppColors.danger));
    }
    setState(() => _savingCode = false);
  }

  Future<void> _saveCurrency(BoutiqueProvider bp) async {
    setState(() => _savingCurrency = true);
    final success = await bp.saveCurrency(_currency);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Devise mise à jour' : 'Erreur'),
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
              ? 'Ajouter une catégorie'
              : 'Modifier la catégorie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormField(
                  label: 'Nom',
                  controller: _categoryNameCtrl,
                  hint: 'Ex: T-shirts',
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Ordre',
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
                      ? 'Ajouter une image'
                      : 'Changer l\'image'),
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
                                const SnackBar(
                                  content:
                                      Text('Erreur upload image catégorie'),
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
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: uploadingImage
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = _categoryNameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Le nom de catégorie est requis'),
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
            ? 'Catégorie enregistrée'
            : pp.error ?? 'Erreur catégorie'),
        backgroundColor: result != null ? AppColors.success : AppColors.danger,
      ));
    }
    setState(() => _savingCategory = false);
  }

  Future<void> _deleteCategory(ProductsProvider pp, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie ?'),
        content: Text('La catégorie "${category.name}" sera supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await pp.deleteCategory(category.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Catégorie supprimée' : pp.error ?? 'Erreur'),
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
          content: Text(success ? 'Logo mis à jour' : 'Erreur upload'),
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
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Supprimer',
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
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(
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
                    child: const Text('OK'),
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
  final TextEditingController? controller;
  const _CodeEditorField({required this.label, this.controller});

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
            hintText:
                label == 'JavaScript' ? '// JS ici...' : '/* CSS ici... */',
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
