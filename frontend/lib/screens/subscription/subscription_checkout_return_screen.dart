import 'dart:developer' as developer;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class SubscriptionCheckoutReturnScreen extends StatefulWidget {
  const SubscriptionCheckoutReturnScreen({
    super.key,
    required this.status,
    this.sessionId,
  });

  final String status;
  final String? sessionId;

  @override
  State<SubscriptionCheckoutReturnScreen> createState() =>
      _SubscriptionCheckoutReturnScreenState();
}

class _SubscriptionCheckoutReturnScreenState
    extends State<SubscriptionCheckoutReturnScreen> {
  final ApiClient _api = ApiClient();

  bool _loading = true;
  bool _success = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleReturn();
    });
  }

  Future<void> _handleReturn() async {
    final auth = context.read<AuthProvider>();

    developer.log('[StripeReturn] deep link received');
    developer.log('[StripeReturn] sessionId=${widget.sessionId}');

    final tokenLoaded = await auth.reloadSessionFromStorage(notify: false);
    developer.log('[StripeReturn] token loaded=$tokenLoaded');

    final tokenRefreshed = await _api.ensureFreshToken(logPrefix: '[StripeReturn]');
    developer.log('[StripeReturn] token refreshed=$tokenRefreshed');

    await auth.reloadSessionFromStorage(notify: false);

    if (!auth.isAuthenticated) {
      developer.log('[StripeReturn] User not authenticated after payment');
      setState(() {
        _loading = false;
        _success = false;
        _message = 'subscription.login_required_after_payment'.tr();
      });
      return;
    }

    if (widget.status == 'cancelled') {
      developer.log('[StripeReturn] Payment was cancelled');
      await AppStorage.clearPendingStripeSessionId();
      auth.setSubscriptionActive(false);
      setState(() {
        _loading = false;
        _success = false;
        _message = 'subscription.checkout_cancelled'.tr();
      });
      return;
    }

    final sessionId = widget.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      developer.log('[StripeReturn] Missing sessionId in return');
      await AppStorage.clearPendingStripeSessionId();
      setState(() {
        _loading = false;
        _success = false;
        _message = 'subscription.return_missing_session'.tr();
      });
      return;
    }

    developer.log('[StripeReturn] polling checkout-status sessionId=$sessionId');
    for (var attempt = 0; attempt < 10; attempt++) {
      String? checkoutStatus;
      String? subscriptionStatus;
      String? backendMessage;

      try {
        final response = await _api.get(
          '/subscriptions/checkout-status',
          queryParameters: {'sessionId': sessionId},
        );
        final data = response['data'] as Map<String, dynamic>? ?? {};
        checkoutStatus =
            data['subscriptionStatus']?.toString() ?? 'PENDING_PAYMENT';
        backendMessage = data['message']?.toString();
        developer.log('[StripeReturn] checkout status=$checkoutStatus');

        if (checkoutStatus == 'PAYMENT_FAILED') {
          developer.log('[StripeReturn] Payment failed: $backendMessage');
          await AppStorage.clearPendingStripeSessionId();
          auth.setSubscriptionActive(false);
          setState(() {
            _loading = false;
            _success = false;
            _message = backendMessage ?? 'subscription.checkout_failed'.tr();
          });
          return;
        }
      } catch (e) {
        developer.log('[StripeReturn] checkout-status poll error: $e');
      }

      try {
        final subscription = await _loadSubscriptionWithRetry();
        subscriptionStatus = subscription?['status']?.toString() ?? 'UNKNOWN';
      } catch (e) {
        developer.log('[StripeReturn] subscription poll error: $e');
      }

      developer.log('[StripeReturn] subscription status=${subscriptionStatus ?? 'UNKNOWN'}');

      if (checkoutStatus == 'ACTIVE' || subscriptionStatus == 'ACTIVE') {
        developer.log('[StripeReturn] subscription ACTIVE');
        await AppStorage.clearPendingStripeSessionId();
        await _refreshAuthenticatedState(auth);
        await _unlockDashboard();
        return;
      }

      if (mounted) {
        setState(() {
          _message = backendMessage ?? 'subscription.waiting_for_webhook'.tr();
        });
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }

    developer.log('[StripeReturn] Polling exhausted, webhook still pending');
    if (!mounted) return;

    setState(() {
      _loading = false;
      _success = false;
      _message = 'subscription.webhook_still_pending'.tr();
    });
  }

  Future<Map<String, dynamic>?> _loadSubscriptionWithRetry() async {
    try {
      final response = await _api.get('/subscriptions/mine');
      return response['data'] as Map<String, dynamic>?;
    } catch (e) {
      developer.log('[StripeReturn] retrying /subscriptions/mine after refresh: $e');
      await _api.refreshAccessToken(logPrefix: '[StripeReturn]');
      final retryResponse = await _api.get('/subscriptions/mine');
      return retryResponse['data'] as Map<String, dynamic>?;
    }
  }

  Future<void> _refreshAuthenticatedState(AuthProvider auth) async {
    await auth.reloadSessionFromStorage(notify: false);
    auth.setSubscriptionActive(true);
    final stillActive = await auth.hasActiveSubscription();
    if (!stillActive) {
      auth.setSubscriptionActive(true);
    }
  }

  Future<void> _unlockDashboard() async {
    final boutiques = context.read<BoutiqueProvider>();
    await boutiques.loadBoutiques();

    if (!mounted) return;

    setState(() {
      _loading = false;
      _success = true;
      _message = 'subscription.checkout_success'.tr();
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    String destination;
    if (boutiques.boutiques.isEmpty) {
      destination = '/create-store';
    } else if (boutiques.boutiques.length == 1) {
      destination = '/home';
    } else {
      destination = '/store-selector';
    }
    developer.log('[StripeReturn] boutiques loaded=${boutiques.boutiques.length}');
    developer.log('[StripeReturn] navigation target=$destination');
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('subscription.title'.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                Icon(
                  _success ? Icons.check_circle : Icons.error_outline,
                  color: _success ? AppColors.success : AppColors.warning,
                  size: 64,
                ),
              const SizedBox(height: 16),
              Text(
                _loading
                    ? 'subscription.processing_payment'.tr()
                    : (_success
                        ? 'subscription.checkout_success'.tr()
                        : 'subscription.checkout_status_title'.tr()),
                style: AppTypography.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _message ?? '',
                style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!_loading)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go(_success ? '/home' : '/plans');
                    },
                    child: Text(
                      _success
                          ? 'dashboard.open_dashboard'.tr()
                          : 'plans.title'.tr(),
                    ),
                  ),
                ),
              if (!_loading && !_success)
                TextButton(
                  onPressed: _handleReturn,
                  child: Text('common.refresh'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
