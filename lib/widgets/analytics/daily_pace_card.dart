import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';
import '../../screens/daily_pace_detail_screen.dart';
import '../../screens/premium_screen.dart';
import 'analytics_card_header.dart';

/// 1日あたりの支出カード（常時表示版）
/// Premium: 実データ + 矢印（詳細画面へ）
/// Free: ダミーデータ + ループアニメ + ロックアイコン（Premium画面へ）
class DailyPaceCard extends StatefulWidget {
  final AppState appState;
  final bool isPremium;

  const DailyPaceCard({
    super.key,
    required this.appState,
    required this.isPremium,
  });

  @override
  State<DailyPaceCard> createState() => _DailyPaceCardState();
}

class _DailyPaceCardState extends State<DailyPaceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (!widget.isPremium) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DailyPaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium != oldWidget.isPremium) {
      if (widget.isPremium) {
        _animationController.stop();
        _animationController.reset();
      } else {
        _animationController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: analyticsCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsCardHeader(
              icon: Icons.speed,
              iconColor: AppColors.accentGreen,
              title: '1日あたりの支出',
              subtitle: widget.isPremium
                  ? _getSummaryText()
                  : '今の使い方を数字で見られます',
              isPremium: widget.isPremium,
            ),
            const AnalyticsCardDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: widget.isPremium
                  ? _buildPremiumContent()
                  : _buildFreeContent(),
            ),
          ],
        ),
      ),
    );
  }

  String _getSummaryText() {
    final totalThisMonth = widget.appState.thisMonthTotal;
    if (totalThisMonth == 0) return '-';

    final elapsedDays = _getElapsedDays();
    if (elapsedDays <= 0) return '-';

    final dailyPace = totalThisMonth / elapsedDays;
    final weeklyPace = dailyPace * 7;

    return '1日 約¥${formatNumber(_roundToHundred(dailyPace))} / 週 約¥${formatNumber(_roundToHundred(weeklyPace))}';
  }

  int _getElapsedDays() {
    final cycleStart = widget.appState.cycleStartDate;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final cycleStartDate = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
    return todayDate.difference(cycleStartDate).inDays + 1;
  }

  int _roundToHundred(double value) {
    return (value / 100).round() * 100;
  }

  Widget _buildPremiumContent() {
    final totalThisMonth = widget.appState.thisMonthTotal;

    if (totalThisMonth == 0) {
      return _buildEmptyState();
    }

    final elapsedDays = _getElapsedDays();
    final dailyPace = elapsedDays > 0 ? totalThisMonth / elapsedDays : 0.0;
    final weeklyPace = dailyPace * 7;

    return Row(
      children: [
        // 1日あたり
        Expanded(
          child: _buildPaceBox(
            label: '1日あたり',
            value: _roundToHundred(dailyPace),
            color: AppColors.accentGreen,
          ),
        ),
        const SizedBox(width: 12),
        // 1週間あたり
        Expanded(
          child: _buildPaceBox(
            label: '1週間あたり',
            value: _roundToHundred(weeklyPace),
            color: AppColors.accentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildPaceBox({
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '約',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '¥${formatNumber(value)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreeContent() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = 0.2 + (_animation.value * 0.6);

        return Row(
          children: [
            // 1日あたり（ダミー）
            Expanded(
              child: _buildDummyPaceBox(
                label: '1日あたり',
                color: AppColors.accentGreen,
                opacity: opacity,
              ),
            ),
            const SizedBox(width: 12),
            // 1週間あたり（ダミー）
            Expanded(
              child: _buildDummyPaceBox(
                label: '1週間あたり',
                color: AppColors.accentBlue,
                opacity: opacity,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDummyPaceBox({
    required String label,
    required Color color,
    required double opacity,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '約',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '¥---',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: opacity),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '記録するとここに表示されます',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyPaceDetailScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }
}
