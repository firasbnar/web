import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackButton extends StatelessWidget {
  final String? fallbackRoute;

  const AppBackButton({super.key, this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Retour',
      child: TextButton.icon(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(fallbackRoute ?? '/dashboard');
          }
        },
        icon: const Icon(Icons.arrow_back),
        label: const Text('Retour'),
      ),
    );
  }
}
