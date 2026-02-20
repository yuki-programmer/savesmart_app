import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// App-wide typography scale and styles.
/// Use these to keep text sizes/weights consistent across screens.
class AppTextStyles {
  static TextStyle pageTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: context.appTheme.textPrimary.withValues(alpha: 0.9),
        height: 1.3,
      );

  static TextStyle screenTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: context.appTheme.textPrimary,
        height: 1.3,
      );

  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.appTheme.textPrimary.withValues(alpha: 0.9),
        height: 1.4,
      );

  static TextStyle sectionTitleSm(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.appTheme.textPrimary.withValues(alpha: 0.85),
        height: 1.4,
      );

  static TextStyle body(BuildContext context,
          {FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: weight,
        color: context.appTheme.textPrimary.withValues(alpha: 0.85),
        height: 1.4,
      );

  static TextStyle label(BuildContext context,
          {FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: weight,
        color: context.appTheme.textSecondary.withValues(alpha: 0.9),
        height: 1.4,
      );

  static TextStyle sub(BuildContext context,
          {FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: weight,
        color: context.appTheme.textSecondary,
        height: 1.4,
      );

  static TextStyle caption(BuildContext context,
          {FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: weight,
        color: context.appTheme.textMuted,
        height: 1.3,
      );

  static TextStyle link(
    BuildContext context, {
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: context.appTheme.textSecondary.withValues(alpha: 0.9),
        height: 1.4,
      );
}
