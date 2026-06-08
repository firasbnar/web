import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/env_config.dart';
import '../../utils/image_utils.dart';
import '../../providers/public_cart_provider.dart';
import '../../providers/public_wishlist_provider.dart';
import '../../services/social_meta.dart';
import '../../services/web_utils.dart';
import '../../providers/public_messages_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PublicStorefrontScreen extends StatefulWidget {
  final String slug;
  const PublicStorefrontScreen({super.key, required this.slug});
  @override
  State<PublicStorefrontScreen> createState() => _PublicStorefrontScreenState();
}

class _PublicStorefrontScreenState extends State<PublicStorefrontScreen> with WidgetsBindingObserver {
  final _api = ApiClient();
  Map<String, dynamic>? _store;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryId;
  Timer? _refreshTimer;
  bool _visitTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ignore: avoid_print
    print('OPENING PUBLIC STORE SLUG: ${widget.slug}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicCartProvider>().loadCart(widget.slug);
      context.read<PublicWishlistProvider>().loadWishlist(widget.slug);
      context.read<PublicMessagesProvider>().loadFromStorage(widget.slug);
    });
    _loadStore();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStore();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _silentRefresh());
  }

  Future<void> _trackVisit(double? lat, double? lng) async {
    try {
      final boutiqueId = _store?['id'];
      if (boutiqueId == null) return;
      final payload = <String, dynamic>{
        'page': '/store/${widget.slug}',
        'referrer': WebUtils.currentUrl,
        'userAgent': WebUtils.userAgent,
        'latitude': lat,
        'longitude': lng,
      };
      print('[Geo] Sending visit payload: $payload');
      await _api.post('/public/stores/${widget.slug}/visit', data: payload);
      print('[Geo] Visit tracked successfully: lat=$lat lng=$lng');
    } catch (e) {
      print('[Geo] Visit tracking error: $e');
    }
  }

  void _requestGeolocation() {
    if (_visitTracked) return;
    _visitTracked = true;
    WebUtils.requestGeolocation(
      onSuccess: (lat, lng) {
        print('[Geo] Geolocation granted: lat=$lat lng=$lng');
        _trackVisit(lat, lng);
      },
      onError: () {
        print('[Geo] Geolocation denied or unavailable');
        _trackVisit(null, null);
      },
    );
  }

  Future<void> _loadStore() async {
    setState(() { _loading = true; _error = null; });
    await _fetchStore();
  }

  Future<void> _silentRefresh() async {
    await _fetchStore();
  }

  Future<void> _fetchStore() async {
    try {
      final res = await _api.get('/public/stores/${widget.slug}');
      if (mounted) {
        setState(() { _store = res; _loading = false; });
        _setSocialMeta(res);
        _requestGeolocation();
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'public_store.shop_not_found'.tr(); _loading = false; });
    }
  }

  void _setSocialMeta(Map<String, dynamic> s) {
    SocialMeta.setStoreMeta(
      title: s['name'] ?? 'public_store.online_shop'.tr(),
      description: s['description'] ?? 'public_store.discover_products'.tr(),
      image: s['logoUrl'] as String?,
      url: '${EnvConfig.frontendPublicUrl}/store/${widget.slug}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator())));
    if (_error != null || _store == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(_error ?? 'public_store.shop_not_found'.tr(), style: AppTypography.heading3),
                const SizedBox(height: 8),
                Text('public_store.check_link'.tr(), style: AppTypography.caption),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _loadStore, child: Text('public_store.retry'.tr())),
              ],
            ),
          ),
        ),
      );
    }

    final s = _store!;
    final status = s['publicationStatus'] ?? 'PUBLISHED';
    final isFrozen = status == 'FROZEN';
    final isDraft = status == 'DRAFT';

    if (isFrozen || status == 'SUSPENDED') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange.shade300),
                const SizedBox(height: 16),
                Text(s['name'] ?? '', style: AppTypography.heading2),
                const SizedBox(height: 8),
                Text('public_store.shop_unavailable'.tr(),
                  style: AppTypography.body1, textAlign: TextAlign.center),
                if (status == 'FROZEN' && s['freezeReason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${'public_store.reason'.tr()} ${s['freezeReason']}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (isDraft) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(s['name'] ?? '', style: AppTypography.heading2),
                const SizedBox(height: 8),
                Text('public_store.shop_coming_soon'.tr(),
                  style: AppTypography.body1, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final name = s['name'] ?? '';
    final logo = s['logoUrl'] as String?;
    final banner = s['bannerUrl'] as String?;
    final description = s['description'] as String?;
    final primaryColor = s['primaryColor'] as String? ?? '#2710BF';
    final products = (s['products'] as List? ?? []).cast<Map<String, dynamic>>();
    final categories = (s['categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final phone = s['whatsappNumber'] as String?;
    final cart = context.watch<PublicCartProvider>();
    final cartCount = cart.itemCount(widget.slug);
    final wishlist = context.watch<PublicWishlistProvider>();

    final filteredProducts = products.where((p) {
      if (_selectedCategoryId != null && p['categoryId']?.toString() != _selectedCategoryId) return false;
      if (_searchQuery.isNotEmpty && !(p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(fontSize: 16)),
        actions: [
          if (phone != null && phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone),
              tooltip: 'public_store.contact_us'.tr(),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
          IconButton(
            icon: Icon(
              context.watch<PublicMessagesProvider>().hasActiveConversation
                  ? Icons.chat_bubble
                  : Icons.chat_bubble_outline,
            ),
            tooltip: 'public_store.contact_us'.tr(),
            onPressed: _openContactModal,
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/store/${widget.slug}/cart'),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStore,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (banner != null && banner.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(resolveImageUrl(banner) ?? '', width: double.infinity, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            if (logo != null && logo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(resolveImageUrl(logo) ?? '', height: 80, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(description, style: AppTypography.body1),
            ],
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'public_store.search_products'.tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(100)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                filled: true,
                fillColor: AppColors.surfaceAlt,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            if (categories.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final isAll = i == 0;
                    final c = isAll ? null : categories[i - 1];
                    final selected = isAll ? _selectedCategoryId == null : _selectedCategoryId == c!['id'].toString();
                    return ChoiceChip(
                      label: Text(isAll ? 'public_store.all_categories'.tr() : '${c!['name']} (${c['productCount'] ?? 0})', style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
                      selected: selected,
                      selectedColor: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
                      onSelected: (_) => setState(() => _selectedCategoryId = isAll ? null : c!['id'].toString()),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('public_store.products'.tr(), style: AppTypography.heading3),
                Text('${filteredProducts.length} ${'public_store.items'.tr()}', style: AppTypography.caption),
              ],
            ),
            const SizedBox(height: 8),
            if (filteredProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('public_store.no_products'.tr(), style: AppTypography.body2),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (_, i) {
                  final p = filteredProducts[i];
                  final pid = (p['id']?.toString() ?? '').trim();
                  final firstImg = resolveImageUrl(firstImageUrl(p['images']));
                  final stockStatus = p['stockStatus'] ?? 'IN_STOCK';
                  final outOfStock = stockStatus == 'OUT_OF_STOCK' || (p['stock'] ?? 0) <= 0;
                  final inWishlist = pid.isNotEmpty ? wishlist.isInWishlist(widget.slug, pid) : false;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: pid.isEmpty ? null : () => context.push('/store/${widget.slug}/product/$pid'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                if (firstImg != null)
                                  Image.network(firstImg, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 40, color: AppColors.textHint)))
                                else
                                  Container(color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 40, color: AppColors.textHint)),
                                if (outOfStock)
                                  Positioned.fill(
                                    child: Container(color: Colors.black45, child: Center(child: Text('public_store.out_of_stock'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                                  ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      wishlist.toggle(widget.slug, PublicWishlistItem(
                                        productId: pid,
                                        name: p['name'] ?? '',
                                        price: (p['price'] ?? 0).toDouble(),
                                        promotionalPrice: p['promotionalPrice']?.toDouble(),
                                        image: firstImg,
                                        stock: p['stock'] ?? 0,
                                      ));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                      child: Icon(
                                        inWishlist ? Icons.favorite : Icons.favorite_border,
                                        size: 18, color: inWishlist ? AppColors.danger : AppColors.textHint,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        _fmtPrice(p['promotionalPrice'] != null && (p['promotionalPrice'] as num) > 0 ? p['promotionalPrice'] : p['price']),
                                        style: AppTypography.caption.copyWith(color: Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))), fontWeight: FontWeight.w700),
                                      ),
                                      if (p['promotionalPrice'] != null && (p['promotionalPrice'] as num) > 0) ...[
                                        const SizedBox(width: 4),
                                        Text(_fmtPrice(p['price']), style: AppTypography.caption.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textHint)),
                                      ],
                                    ],
                                  ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 28,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: outOfStock ? Colors.grey.shade300 : Color(int.parse(primaryColor.replaceFirst('#', '0xFF'))),
                                      foregroundColor: outOfStock ? Colors.grey.shade600 : Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: outOfStock ? null : () {
                                      cart.addItem(widget.slug, PublicCartItem(
                                        productId: pid,
                                        name: p['name'] ?? '',
                                        price: (p['price'] ?? 0).toDouble(),
                                        promotionalPrice: p['promotionalPrice']?.toDouble(),
                                        image: firstImg,
                                        stock: p['stock'] ?? 0,
                                      ));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${p['name']} ${'public_store.added_to_cart'.tr()}'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
                                      );
                                    },
                                    child: Text(outOfStock ? 'public_store.out_of_stock'.tr() : 'public_store.add_to_cart'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
        ),
      ),
    );
  }



  void _openContactModal() {
    final mp = context.read<PublicMessagesProvider>();
    if (mp.hasActiveConversation) {
      _showGuestChat();
    } else {
      _showContactForm();
    }
  }

  void _showContactForm() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('public_store.contact_us'.tr(), style: AppTypography.heading4),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'public_store.your_name'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'common.required'.tr() : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'public_store.email'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'public_store.phone'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: msgCtrl,
                  decoration: InputDecoration(
                    labelText: 'public_store.your_message'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.message_outlined, size: 20),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'common.required'.tr() : null,
                ),
                const SizedBox(height: 20),
                Consumer<PublicMessagesProvider>(
                  builder: (_, mp, __) {
                    if (mp.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2710BF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final ok = await mp.sendGuestMessage(
                            slug: widget.slug,
                            customerName: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            message: msgCtrl.text.trim(),
                          );
                          if (ok && ctx.mounted) {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('public_store.message_sent'.tr()),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(mp.error ?? 'public_store.message_error'.tr()),
                                backgroundColor: AppColors.danger,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text('public_store.send_message'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
  }

  void _showGuestChat() {
    final mp = context.read<PublicMessagesProvider>();
    mp.loadConversation();

    final msgCtrl = TextEditingController();
    final scrollCtrl = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('public_store.your_conversation'.tr(), style: AppTypography.heading4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<PublicMessagesProvider>(
                builder: (_, prov, __) {
                  if (prov.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (prov.messages.isEmpty) {
                    return Center(
                      child: Text('public_store.no_messages'.tr(), style: const TextStyle(color: AppColors.textHint)),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (scrollCtrl.hasClients) {
                      scrollCtrl.animateTo(
                        scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: prov.messages.length,
                    itemBuilder: (_, i) {
                      final msg = prov.messages[i];
                      final isMine = msg.senderType == 'CUSTOMER';
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(ctx).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFF2710BF) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                            ),
                            border: !isMine ? Border.all(color: const Color(0xFFE5E7EB)) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.content,
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black87,
                                ),
                                softWrap: true,
                              ),
                              if (msg.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatMsgTime(msg.createdAt!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMine ? Colors.white70 : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: msgCtrl,
                        decoration: InputDecoration(
                          hintText: 'public_store.your_message'.tr(),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendGuestReply(ctx, msgCtrl, mp, scrollCtrl),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF2710BF)),
                      onPressed: () => _sendGuestReply(ctx, msgCtrl, mp, scrollCtrl),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendGuestReply(BuildContext ctx, TextEditingController ctrl, PublicMessagesProvider mp, ScrollController sc) {
    final content = ctrl.text.trim();
    if (content.isEmpty) return;
    ctrl.clear();
    mp.sendReply(content).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sc.hasClients) {
          sc.animateTo(
            sc.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  String _formatMsgTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _fmtPrice(dynamic price) {
    if (price == null) return 'DT 0.00';
    final n = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
    return 'DT ${n.toStringAsFixed(2)}';
  }
}
