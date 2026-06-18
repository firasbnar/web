import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle heading1 = GoogleFonts.notoSans(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle heading2 = GoogleFonts.notoSans(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle heading3 = GoogleFonts.notoSans(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle heading4 = GoogleFonts.notoSans(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle body1 = GoogleFonts.notoSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle body2 = GoogleFonts.notoSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle caption = GoogleFonts.notoSans(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle button = GoogleFonts.notoSans(
    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle badge = GoogleFonts.notoSans(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
    letterSpacing: 1.2);
}
