import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/api_client.dart';
import '../../core/storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/boutique_provider.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  final ApiClient _api = ApiClient();
  List<dynamic> _plans = [];
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _isOpeningCheckout = false;
  int? _processingPlanId;
  bool _handlingPendingStripeReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingStripeReturnIfNeeded(trigger: 'init');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handlePendingStripeReturnIfNeeded(trigger: 'resume');
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final plansRes = await _api.get('/plans');
      Map<String, dynamic>? subRes;
      try {
        subRes = (await _api.get('/subscriptions/mine'))['data'];
      } catch (_) {}
      setState(() {
        _plans = plansRes['data'] ?? [];
        _subscription = subRes;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startStripeCheckout(int planId) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isOpeningCheckout) {
      developer.log('[PLANS] Already opening checkout, skipping duplicate');
      return;
    }
    developer.log('[PLANS] Manual checkout tap for planId=$planId');
    developer.log('[PLANS] Starting Stripe checkout for planId=$planId');
    setState(() {
      _isOpeningCheckout = true;
      _processingPlanId = planId;
    });
    try {
      final response = await _api.post(
        '/subscriptions/checkout-session',
        data: {'planId': planId, 'paymentMethod': 'STRIPE'},
      );
      final sessionUrl = response['data']?['sessionUrl']?.toString();
      final sessionId = response['data']?['sessionId']?.toString();
      if (sessionUrl == null || sessionUrl.isEmpty) {
        throw Exception('subscription.checkout_url_missing'.tr());
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        await AppStorage.savePendingStripeSessionId(sessionId);
      }

      developer.log('[PLANS] Opening Stripe session URL for planId=$planId');
      final launched = await launchUrl(
        Uri.parse(sessionUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await AppStorage.clearPendingStripeSessionId();
        throw Exception('subscription.unable_to_open_checkout'.tr());
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('subscription.redirecting_to_checkout'.tr())),
        );
      }
    } catch (e) {
      await AppStorage.clearPendingStripeSessionId();
      if (mounted) {
        final message = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : '${'common.error'.tr()}: $e';
        messenger.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningCheckout = false;
          _processingPlanId = null;
        });
      }
    }
  }

  Future<void> _handlePendingStripeReturnIfNeeded({required String trigger}) async {
    if (_handlingPendingStripeReturn || !mounted) {
      return;
    }

    final router = GoRouter.of(context);
    final auth = context.read<AuthProvider>();
    final boutiques = context.read<BoutiqueProvider>();
    final sessionId = await AppStorage.getPendingStripeSessionId();
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }

    _handlingPendingStripeReturn = true;
    try {
      developer.log('[StripeReturn] fallback trigger=$trigger');
      developer.log('[StripeReturn] sessionId=$sessionId');

      final tokenLoaded = await auth.reloadSessionFromStorage(notify: false);
      developer.log('[StripeReturn] token loaded=$tokenLoaded');

      final tokenRefreshed =
          await _api.ensureFreshToken(logPrefix: '[StripeReturn]');
      developer.log('[StripeReturn] token refreshed=$tokenRefreshed');

      String checkoutStatus = 'UNKNOWN';
      try {
        final checkoutRes = await _api.get(
          '/subscriptions/checkout-status',
          queryParameters: {'sessionId': sessionId},
        );
        final data = checkoutRes['data'] as Map<String, dynamic>? ?? {};
        checkoutStatus =
            data['subscriptionStatus']?.toString() ?? checkoutStatus;
      } catch (e) {
        developer.log('[StripeReturn] checkout-status fallback error: $e');
      }
      developer.log('[StripeReturn] checkout status=$checkoutStatus');

      String subscriptionStatus = 'UNKNOWN';
      try {
        final mineRes = await _api.get('/subscriptions/mine');
        subscriptionStatus =
            mineRes['data']?['status']?.toString() ?? subscriptionStatus;
      } catch (e) {
        developer.log('[StripeReturn] /subscriptions/mine fallback error: $e');
      }
      developer.log('[StripeReturn] subscription status=$subscriptionStatus');

      if (checkoutStatus == 'ACTIVE' || subscriptionStatus == 'ACTIVE') {
        auth.setSubscriptionActive(true);
        await auth.hasActiveSubscription();
        await boutiques.loadBoutiques();

        if (!mounted) return;

        String destination;
        if (boutiques.boutiques.isEmpty) {
          destination = '/create-store';
        } else if (boutiques.boutiques.length == 1) {
          destination = '/home';
        } else {
          destination = '/store-selector';
        }

        developer.log('[StripeReturn] navigation target=$destination');
        await AppStorage.clearPendingStripeSessionId();
        router.go(destination);
        return;
      }

      if (checkoutStatus == 'PAYMENT_FAILED') {
        await AppStorage.clearPendingStripeSessionId();
      }
    } finally {
      _handlingPendingStripeReturn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('plans.title'.tr(), style: AppTypography.heading2.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      _subscription != null ? '${'plans.current'.tr()}: ${_subscription!['planName'] ?? 'plans.free'.tr()}' : 'plans.select'.tr(),
                      style: AppTypography.body1.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_subscription != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('plans.current_plan'.tr(), style: AppTypography.heading4),
                          const SizedBox(height: 8),
                          Text('${'plans.current'.tr()}: ${_subscription!['planName'] ?? 'plans.free'.tr()}', style: AppTypography.body2),
                          if (_subscription!['expiresAt'] != null) Text('${'subscription.expires'.tr()}: ${_subscription!['expiresAt']}', style: AppTypography.caption),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: const LinearProgressIndicator(value: 0.5, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ..._plans.map((plan) => _planCard(plan)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(dynamic plan) {
    final isCurrentPlan = _subscription != null && _subscription!['planId'] == plan['id'];
    final isProcessing = _processingPlanId == plan['id'];
    final name = plan['name'] ?? '';
    final price = (plan['priceDt'] ?? 0).toDouble();
    final days = plan['durationDays'] ?? 0;
    final maxProducts = plan['maxProducts'] ?? 0;
    final features = plan['features'] is String ? plan['features'] : '';
    final isHighlighted = name == '3 Mois';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: AppTypography.heading3),
              if (isHighlighted)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('subscription.save_with_yearly'.tr(), style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${price.toStringAsFixed(2)} TND${days > 0 ? " / $days ${'plans.monthly'.tr().toLowerCase()}" : ""}', style: AppTypography.heading2.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('plans.products_limit'.tr(args: [maxProducts.toString()]), style: AppTypography.caption),
          const SizedBox(height: 16),
          if (features.isNotEmpty) ...[
            ...features.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(f.trim(), style: AppTypography.body2),
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isCurrentPlan || _isOpeningCheckout || _processingPlanId != null)
                  ? null
                  : () => _startStripeCheckout(plan['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan ? AppColors.surfaceAlt : AppColors.primary,
                foregroundColor: isCurrentPlan ? AppColors.textHint : Colors.white,
                side: isCurrentPlan ? const BorderSide(color: AppColors.border) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(isCurrentPlan ? 'plans.current_plan'.tr() : 'plans.select'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
