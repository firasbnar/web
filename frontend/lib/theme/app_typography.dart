import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle heading3 = GoogleFonts.poppins(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle heading4 = GoogleFonts.poppins(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle body1 = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle body2 = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle button = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle badge = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
    letterSpacing: 1.2);
}
