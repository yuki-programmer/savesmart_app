import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import 'history_screen.dart';
import 'category_manage_screen.dart';
import 'settings_screen.dart';
import 'fixed_cost_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}曜日';
  }

  // 状態に応じた評価文を返す
  Map<String, dynamic> _getEvaluation(AppState appState) {
    final savings = appState.thisMonthSavings;
    final expenseCount = appState.thisMonthExpenses.length;

    // データがない場合
    if (expenseCount == 0) {
      return {
        'emoji': '👋',
        'title': '記録をはじめよう',
        'subtitle': '最初の支出を記録してみましょう',
        'color': AppColors.accentBlue,
      };
    }

    // 節約できている場合
    if (savings > 0) {
      if (savings >= 5000) {
        return {
          'emoji': '🎉',
          'title': 'すごい！かなりお得です',
          'subtitle': '今月はいい買い方ができています',
          'color': AppColors.accentGreen,
        };
      } else if (savings >= 1000) {
        return {
          'emoji': '✨',
          'title': 'いい調子です',
          'subtitle': '賢い選択が続いています',
          'color': AppColors.accentGreen,
        };
      } else {
        return {
          'emoji': '👍',
          'title': 'いい感じ',
          'subtitle': 'このペースを維持しましょう',
          'color': AppColors.accentGreen,
        };
      }
    }

    // 使いすぎの場合
    if (savings < 0) {
      if (savings <= -5000) {
        return {
          'emoji': '💭',
          'title': '少し振り返ってみましょう',
          'subtitle': 'どこで差が出たか確認できます',
          'color': AppColors.accentOrange,
        };
      } else {
        return {
          'emoji': '📝',
          'title': '様子を見てみましょう',
          'subtitle': '次の買い物で調整できます',
          'color': AppColors.accentBlue,
        };
      }
    }

    // ちょうど0の場合
    return {
      'emoji': '📊',
      'title': '今月は様子見でOK',
      'subtitle': 'いつも通りの買い方です',
      'color': AppColors.accentBlue,
    };
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
                        const SizedBox(height: 28),
                        _buildEvaluationCard(appState),
                        _buildAvailableAmountLink(appState),
                        const SizedBox(height: 28),
                        _buildCategorySection(appState),
                        const SizedBox(height: 28),
                        _buildRecentExpenses(appState),
                        const SizedBox(height: 28),
                        _buildFixedCostsSection(appState),
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
        Text(
          _getFormattedDate(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary.withOpacity(0.7),
            height: 1.3,
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted.withOpacity(0.6)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEvaluationCard(AppState appState) {
    final evaluation = _getEvaluation(appState);
    final accentColor = evaluation['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(
            color: accentColor.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evaluation['emoji'] as String,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 14),
          Text(
            evaluation['title'] as String,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            evaluation['subtitle'] as String,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 今月の使える金額リンク（評価カード直下）
  Widget _buildAvailableAmountLink(AppState appState) {
    final availableAmount = appState.thisMonthAvailableAmount;

    return GestureDetector(
      onTap: () {
        // 分析タブへ切り替え + incomeSheet自動起動
        appState.requestOpenIncomeSheet();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '今月の使える金額：',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withOpacity(0.6),
              ),
            ),
            Text(
              availableAmount != null
                  ? '¥${_formatNumber(availableAmount)}'
                  : '未設定',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: availableAmount != null
                    ? AppColors.textSecondary.withOpacity(0.7)
                    : AppColors.textMuted.withOpacity(0.5),
              ),
            ),
            Text(
              availableAmount != null ? '（変更）' : '（追加）',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlue.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(AppState appState) {
    final stats = appState.categoryStats;
    final categories = stats.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'どこで差が出た？',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryManageScreen()),
                );
              },
              child: Text(
                '編集',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '記録するとここに表示されます',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          ...categories.take(3).map((category) {
            final stat = stats[category]!;
            return _buildCategoryCard(stat);
          }),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryStats stat) {
    final isPositive = stat.savingsAmount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stat.category,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ),
          if (stat.savingsAmount != 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive
                    ? AppColors.accentGreenLight.withOpacity(0.7)
                    : AppColors.accentRedLight.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPositive
                    ? '+¥${_formatNumber(stat.savingsAmount)}'
                    : '-¥${_formatNumber(stat.savingsAmount.abs())}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPositive ? AppColors.accentGreen : AppColors.accentRed,
                ),
              ),
            )
          else
            Text(
              '±0',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withOpacity(0.8),
              ),
            ),
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

  Widget _buildRecentExpenses(AppState appState) {
    final recentExpenses = appState.thisMonthExpenses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '日々の出費',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
              child: Text(
                'すべて見る',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (recentExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '記録がありません',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          ...recentExpenses.map((expense) => _buildExpenseItem(expense)),
      ],
    );
  }

  Widget _buildFixedCostsSection(AppState appState) {
    final fixedCosts = appState.fixedCosts;
    final totalFixedCosts = fixedCosts.fold(0, (sum, fc) => sum + fc.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '今月の固定費',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FixedCostHistoryScreen()),
                );
              },
              child: Text(
                '編集',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              // 合計金額
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '合計',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    '¥${_formatNumber(totalFixedCosts)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              if (fixedCosts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // 固定費リスト
                ...fixedCosts.map((fc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fc.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary.withOpacity(0.9),
                            ),
                          ),
                          Text(
                            '¥${_formatNumber(fc.amount)}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
              if (fixedCosts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '固定費が登録されていません',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    // カテゴリが「その他」の場合は非表示
    final showCategory = expense.category != 'その他';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCategory)
                  Text(
                    expense.category,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                if (expense.memo != null && expense.memo!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: showCategory ? 4 : 0),
                    child: Text(
                      expense.memo!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                // カテゴリもメモもない場合は空のスペースを維持
                if (!showCategory && (expense.memo == null || expense.memo!.isEmpty))
                  const SizedBox(height: 14),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${_formatNumber(expense.amount)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 3),
              _buildTypeBadge(expense.grade),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color bgColor;
    Color textColor;
    String label = AppConstants.typeLabels[type] ?? type;

    switch (type) {
      case 'saving':
        bgColor = AppColors.accentGreenLight.withOpacity(0.7);
        textColor = AppColors.accentGreen;
        break;
      case 'standard':
        bgColor = AppColors.accentBlueLight.withOpacity(0.7);
        textColor = AppColors.accentBlue;
        break;
      case 'reward':
        bgColor = AppColors.accentPurpleLight.withOpacity(0.7);
        textColor = AppColors.accentPurple;
        break;
      default:
        bgColor = AppColors.textMuted.withOpacity(0.08);
        textColor = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
