import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'google_sign_in_web_stub.dart'
    if (dart.library.html) 'google_sign_in_web.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onSuccess;
  final ValueChanged<String>? onError;

  const GoogleSignInButton({super.key, this.onSuccess, this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  bool _webInitialized = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWeb();
      _authSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn && mounted) {
          final auth = event.user.authentication;
          if (auth.idToken != null) {
            _completeWebLogin(auth.idToken!);
          }
        }
      });
    }
  }

  Future<void> _initWeb() async {
    if (_webInitialized) return;
    _webInitialized = true;
    await GoogleSignIn.instance.initialize(
      clientId:
          '31472972692-e4b34vte5c446ss2tkott3hnmqphrokk.apps.googleusercontent.com',
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebButton();
    }
    return _buildAndroidButton();
  }

  Widget _buildWebButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: buildGoogleSignInWebButton(),
    );
  }

  Widget _buildAndroidButton() {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.login),
          label: Text(auth.loading
              ? 'auth.login_loading'.tr()
              : 'auth.continue_with_google'.tr()),
          onPressed: auth.loading
              ? null
              : () => _startAndroidLogin(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }

  Future<void> _startAndroidLogin(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithGoogle();
    if (!mounted) return;
    if (ok) {
      widget.onSuccess?.call();
    } else if (auth.error != null) {
      widget.onError?.call(auth.error!);
    }
  }

  Future<void> _completeWebLogin(String idToken) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithGoogleWeb(idToken: idToken);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess?.call();
    } else if (auth.error != null) {
      widget.onError?.call(auth.error!);
    }
  }
}
