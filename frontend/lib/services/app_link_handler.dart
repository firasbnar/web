import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/env_config.dart';

class AppLinkHandler {
  AppLinkHandler._();

  static final AppLinkHandler instance = AppLinkHandler._();

  StreamSubscription<Uri>? _subscription;
  bool _attached = false;

  Future<void> attach(GoRouter router) async {
    if (kIsWeb || _attached) {
      return;
    }

    _attached = true;
    final appLinks = AppLinks();

    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(router, initialUri);
    }

    _subscription = appLinks.uriLinkStream.listen(
      (uri) => _handleUri(router, uri),
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  void _handleUri(GoRouter router, Uri uri) {
    if (uri.scheme != EnvConfig.paymentReturnScheme ||
        uri.host != EnvConfig.paymentReturnHost) {
      return;
    }

    if (uri.path != '/subscription') {
      return;
    }

    final sessionId = uri.queryParameters['session_id'] ?? '';
    final status = uri.queryParameters['status'] ?? 'pending';
    developer.log('[StripeReturn] deep link received');
    developer.log('[StripeReturn] sessionId=$sessionId');
    developer.log('[StripeReturn] status=$status');

    final routeUri = Uri(
      path: '/subscription/checkout-return',
      queryParameters: {
        'status': status,
        if (sessionId.isNotEmpty) 'sessionId': sessionId,
      },
    );

    developer.log('[StripeReturn] navigating to ${routeUri.toString()}');
    router.go(routeUri.toString());
  }
}
