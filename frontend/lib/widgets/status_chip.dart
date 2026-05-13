import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'PENDING': return AppColors.warning;
      case 'CONFIRMED': return AppColors.primary;
      case 'SHIPPED': return Colors.blue;
      case 'DELIVERED': return AppColors.success;
      case 'CANCELLED': return AppColors.danger;
      case 'PAID': return AppColors.success;
      case 'UNPAID': return AppColors.warning;
      case 'ACTIVE': return AppColors.success;
      default: return AppColors.textHint;
    }
  }

  String get _label {
    switch (status.toUpperCase()) {
      case 'PENDING': return 'En attente';
      case 'CONFIRMED': return 'Confirmé';
      case 'SHIPPED': return 'Expédié';
      case 'DELIVERED': return 'Livré';
      case 'CANCELLED': return 'Annulé';
      case 'PAID': return 'Payé';
      case 'UNPAID': return 'Non payé';
      case 'ACTIVE': return 'Actif';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
