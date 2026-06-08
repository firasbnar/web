import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state from persistent storage.
    // After init() completes, the router's redirect will navigate to the correct page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      developer.log('[SPLASH] Initializing auth...');
      context.read<AuthProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.store, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('app_name'.tr(), style: AppTypography.heading1.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('splash.subtitle'.tr(), style: AppTypography.body1.copyWith(color: Colors.white70)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
