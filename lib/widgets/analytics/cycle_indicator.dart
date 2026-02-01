import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/app_state.dart';

/// 詳細画面用のサイクルインジケーター（共通ウィジェット）
/// 横スクロールでサイクルを切り替えるタブUI
class CycleIndicator extends StatelessWidget {
  final AppState appState;
  final int currentPage;
  final int cycleCount;
  final Color accentColor;
  final PageController pageController;

  const CycleIndicator({
    super.key,
    required this.appState,
    required this.currentPage,
    required this.cycleCount,
    required this.accentColor,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cycleCount, (index) {
            final isSelected = index == currentPage;
            final cycleInfo = _getCycleInfo(index);

            return GestureDetector(
              onTap: () {
                pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : AppColors.textMuted.withValues(alpha: 0.3),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  cycleInfo,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _getCycleInfo(int offset) {
    if (offset == 0) {
      return '今サイクル';
    }
    final dates = appState.getCycleDatesForOffset(offset);
    return '${dates.start.month}/${dates.start.day}〜';
  }
}
