import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackArrow extends StatelessWidget {
  const AppBackArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
    );
  }
}
