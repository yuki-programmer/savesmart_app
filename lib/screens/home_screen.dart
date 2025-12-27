import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isFlipped = false;
  int _selectedPeriod = 2; // 0: 今日, 1: 今週, 2: 今月
  late AnimationController _flipController;
  late AnimationController _fadeController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}曜日';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: appState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildFlipCard(appState),
                        const SizedBox(height: 32),
                        _buildCategoryPerformance(appState),
                        const SizedBox(height: 32),
                        _buildRecentExpenses(appState),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getFormattedDate(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildFlipCard(AppState appState) {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggleFlip,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final isFront = angle < math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: isFront
                    ? _buildSavingsCard(appState)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _buildExpenseCard(appState),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDotIndicator(!_isFlipped),
            const SizedBox(width: 8),
            _buildDotIndicator(_isFlipped),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'タップして切り替え',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDotIndicator(bool isActive) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.accentGreen : AppColors.textMuted.withOpacity(0.3),
      ),
    );
  }

  int _getSavingsForPeriod(AppState appState) {
    switch (_selectedPeriod) {
      case 0:
        return appState.todaySavings;
      case 1:
        return appState.thisWeekSavings;
      case 2:
      default:
        return appState.thisMonthSavings;
    }
  }

  int _getTotalForPeriod(AppState appState) {
    switch (_selectedPeriod) {
      case 0:
        return appState.todayTotal;
      case 1:
        return appState.thisWeekTotal;
      case 2:
      default:
        return appState.thisMonthTotal;
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 0:
        return '今日';
      case 1:
        return '今週';
      case 2:
      default:
        return '今月';
    }
  }

  Widget _buildSavingsCard(AppState appState) {
    final savings = _getSavingsForPeriod(appState);
    final total = _getTotalForPeriod(appState);
    final percentage = total > 0 ? (savings / total * 100).round() : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentGreen,
            AppColors.accentGreenDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getPeriodLabel()}、得した額',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              _buildLiveIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${_formatNumber(savings)}',
            style: GoogleFonts.outfit(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            savings >= 0
                ? 'いつもの買い方より +$percentage% お得に'
                : 'いつもの買い方より $percentage% 多く使用',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),
          _buildPeriodSelector(isLight: true),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(AppState appState) {
    final total = _getTotalForPeriod(appState);
    final budget = appState.currentBudget?.amount ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentBlue,
            Color(0xFF2563EB),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getPeriodLabel()}の支出',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              _buildLiveIndicator(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${_formatNumber(total)}',
            style: GoogleFonts.outfit(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            budget > 0
                ? '予算残り ¥${_formatNumber(budget - appState.thisMonthTotal)}'
                : '予算未設定',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),
          _buildPeriodSelector(isLight: true),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector({required bool isLight}) {
    final periods = ['今日', '今週', '今月'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                periods[index],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.accentGreen
                      : Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryPerformance(AppState appState) {
    final stats = appState.categoryStats;
    final categories = stats.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'カテゴリ別パフォーマンス',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'カテゴリデータがありません',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ...categories.take(4).map((category) {
            final stat = stats[category]!;
            return _buildCategoryCard(stat);
          }),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryStats stat) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.category,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '平均 ¥${_formatNumber(stat.standardAverage)} / 標準',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${_formatNumber(stat.totalAmount)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _buildDifferenceBadge(stat.savingsAmount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifferenceBadge(int difference) {
    if (difference == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '±¥0',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    final isPositive = difference > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.accentGreenLight
            : AppColors.accentRedLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPositive ? '+¥${_formatNumber(difference)} 得' : '-¥${_formatNumber(difference.abs())}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPositive ? AppColors.accentGreen : AppColors.accentRed,
        ),
      ),
    );
  }

  Widget _buildRecentExpenses(AppState appState) {
    final recentExpenses = appState.thisMonthExpenses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最近の支出',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
              child: Text(
                '履歴',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '支出データがありません',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          )
        else
          ...recentExpenses.map((expense) => _buildExpenseItem(expense)),
      ],
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    final time = '${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.category,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${expense.memo ?? ''} • $time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${_formatNumber(expense.amount)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _buildTypeBadge(expense.grade),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color bgColor;
    Color textColor;
    String label = AppConstants.typeLabels[type] ?? type;

    switch (type) {
      case 'saving':
        bgColor = AppColors.accentGreenLight;
        textColor = AppColors.accentGreen;
        break;
      case 'standard':
        bgColor = AppColors.accentBlueLight;
        textColor = AppColors.accentBlue;
        break;
      case 'reward':
        bgColor = AppColors.accentPurpleLight;
        textColor = AppColors.accentPurple;
        break;
      default:
        bgColor = AppColors.textMuted.withOpacity(0.1);
        textColor = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
