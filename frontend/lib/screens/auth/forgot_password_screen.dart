import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validate(String v) {
    if (v.trim().isEmpty) return 'auth.email_required'.tr();
    if (!v.trim().contains('@')) return 'auth.email_invalid'.tr();
    return null;
  }

  Future<void> _submit() async {
    final error = _validate(_emailCtrl.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final email = _emailCtrl.text.trim();
    developer.log('[ForgotPassword] submitting email=$email '
        'baseUrl=${ApiClient.baseUrl} '
        'fullUrl=${ApiClient.baseUrl}/auth/forgot-password');

    setState(() { _loading = true; _error = null; });

    try {
      final result = await _api.forgotPassword(email);
      developer.log('[ForgotPassword] response=$result');
      setState(() { _sent = true; _loading = false; });
    } on TimeoutException {
      developer.log('[ForgotPassword] TimeoutException');
      setState(() {
        _error = 'errors.timeout'.tr();
        _loading = false;
      });
    } on DioException catch (e) {
      final fullUrl = '${ApiClient.baseUrl}/auth/forgot-password';
      developer.log('[ForgotPassword] DioException type=${e.type} '
          'status=${e.response?.statusCode} body=${e.response?.data} '
          'message=${e.message} url=$fullUrl '
          'connectTimeout=${e.requestOptions.connectTimeout} '
          'receiveTimeout=${e.requestOptions.receiveTimeout}');
      String msg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = 'errors.timeout'.tr();
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'errors.server_unreachable'.tr();
      } else if (e.response?.statusCode == 400) {
        msg = 'errors.bad_request'.tr();
      } else if (e.response?.statusCode != null &&
          e.response!.statusCode! >= 500) {
        msg = 'errors.server_error'.tr();
      } else {
        msg = ApiClient.extractErrorMessage(e);
      }
      setState(() { _error = msg; _loading = false; });
    } catch (e, stack) {
      developer.log('[ForgotPassword] Unexpected error: $e\n$stack');
      setState(() { _error = 'errors.unknown'.tr(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('auth.forgot_password_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            children: [
              Icon(Icons.lock_reset, size: 56, color: AppColors.primary.withAlpha(180)),
              const SizedBox(height: 20),
              Text('auth.reset_password'.tr(), style: AppTypography.heading1),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'auth.forgot_password_hint'.tr(),
                  style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              if (!_sent) ...[
                AppTextField(
                  controller: _emailCtrl,
                  label: 'auth.email'.tr(),
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withAlpha(60)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'common.submit'.tr(),
                  loading: _loading,
                  onPressed: _submit,
                  icon: Icons.send,
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withAlpha(60)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                      const SizedBox(height: 12),
                      Text(
                        'auth.forgot_password_sent'.tr(),
                        style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(160, 44),
                  ),
                  child: Text('common.back'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
