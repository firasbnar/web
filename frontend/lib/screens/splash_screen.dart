import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/storage.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    final storage = AppStorage();
    final loggedIn = await storage.isLoggedIn();
    if (!loggedIn) {
      if (mounted) context.go('/login');
      return;
    }
    final role = await storage.getUserRole();
    if (role == 'ADMIN') {
      if (mounted) context.go('/admin');
    } else {
      if (mounted) context.go('/home');
    }
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
              Text('MakeWebsite', style: AppTypography.heading1.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('Votre boutique en ligne', style: AppTypography.body1.copyWith(color: Colors.white70)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
