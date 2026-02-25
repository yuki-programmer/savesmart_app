import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradeLabel extends StatelessWidget {
  final String label;
  final Color color;
  final Color lightColor;
  final double backgroundAlpha;

  const GradeLabel({
    super.key,
    required this.label,
    required this.color,
    required this.lightColor,
    this.backgroundAlpha = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: lightColor.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
