import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import '../models/quick_entry.dart';
import '../utils/formatters.dart';
import '../widgets/quick_entry/quick_entry_edit_modal.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'fixed_cost_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _fixedCostsExpanded = false;

  // 日付ベースのランダムステータス文言
  String _getDailyStatusText() {
    final statusMessages = [
      '今月は標準ペースです',
      '今月は落ち着いた使い方',
      '最近は安定しています',
    ];

    // YYYY-MM-DD形式で日付をハッシュ化して同じ日は同じ文言を表示
    final now = DateTime.now();
    final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hash = dateString.hashCode.abs();
    final index = hash % statusMessages.length;

    return statusMessages[index];
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
                        const SizedBox(height: 28),
                        _buildEvaluationCard(appState),
                        _buildAvailableAmountLink(appState),
                        const SizedBox(height: 28),
                        // クイック登録セクション
                        _buildQuickEntrySection(appState),
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
    // 残額を計算
    final usableAmount = appState.thisMonthAvailableAmount;
    final fixedCostsTotal = appState.fixedCostsTotal;
    final monthlyExpenseTotal = appState.thisMonthTotal + fixedCostsTotal;
    final remaining = (usableAmount ?? 0) - monthlyExpenseTotal;
    final isNegative = remaining < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(
            color: AppColors.textMuted.withOpacity(0.12),
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
            '今月あと',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNegative
                ? '-¥${formatNumber(remaining.abs())}'
                : '¥${formatNumber(remaining)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: isNegative ? AppColors.accentRed : AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // 出費/収入の1行表示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '出費: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '¥${formatNumber(monthlyExpenseTotal)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '収入: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      usableAmount != null
                          ? '¥${formatNumber(usableAmount)}'
                          : '未設定',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ミニステータス文言
          Center(
            child: Text(
              _getDailyStatusText(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// クイック登録セクション
  Widget _buildQuickEntrySection(AppState appState) {
    final quickEntries = appState.quickEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'クイック登録',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () => showQuickEntryEditModal(context),
              child: Text(
                '+ 追加',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (quickEntries.isEmpty)
          _buildEmptyQuickEntryHint()
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickEntries
                  .map((entry) => _buildQuickEntryTile(entry, appState))
                  .toList(),
            ),
          ),
      ],
    );
  }

  /// クイック登録が空の時のヒント表示
  Widget _buildEmptyQuickEntryHint() {
    return GestureDetector(
      onTap: () => showQuickEntryEditModal(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accentBlue.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: AppColors.accentBlue.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'よく使う支出を登録して、1タップで記録',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// クイック登録タイル
  Widget _buildQuickEntryTile(QuickEntry entry, AppState appState) {
    // グレードに対応する色を取得
    Color gradeColor;
    Color gradeLightColor;
    String gradeLabel;

    switch (entry.grade) {
      case 'saving':
        gradeColor = AppColors.accentGreen;
        gradeLightColor = AppColors.accentGreenLight;
        gradeLabel = '節約';
        break;
      case 'reward':
        gradeColor = AppColors.accentOrange;
        gradeLightColor = AppColors.accentOrangeLight;
        gradeLabel = 'ご褒美';
        break;
      default:
        gradeColor = AppColors.accentBlue;
        gradeLightColor = AppColors.accentBlueLight;
        gradeLabel = '標準';
    }

    return GestureDetector(
      onTap: () => _executeQuickEntry(entry, appState),
      onLongPress: () => showQuickEntryEditModal(context, entry: entry),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: gradeColor.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Text(
              entry.title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 6),
            // 金額と支出タイプ
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¥${formatNumber(entry.amount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeLightColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gradeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// クイック登録を実行
  Future<void> _executeQuickEntry(QuickEntry entry, AppState appState) async {
    final success = await appState.executeQuickEntry(entry);

    if (!mounted) return;

    if (success) {
      // グレードに対応する色を取得
      Color gradeColor;
      switch (entry.grade) {
        case 'saving':
          gradeColor = AppColors.accentGreen;
          break;
        case 'reward':
          gradeColor = AppColors.accentOrange;
          break;
        default:
          gradeColor = AppColors.accentBlue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.title} を記録しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: gradeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '記録に失敗しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
                  ? '¥${formatNumber(availableAmount)}'
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
    final totalFixedCosts = appState.fixedCostsTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 14),
        Container(
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
              // ヘッダー（タップで開閉）
              GestureDetector(
                onTap: () {
                  setState(() {
                    _fixedCostsExpanded = !_fixedCostsExpanded;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
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
                              '¥${formatNumber(totalFixedCosts)}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _fixedCostsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: AppColors.textMuted.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 展開時の内訳
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (fixedCosts.isNotEmpty)
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
                                        '¥${formatNumber(fc.amount)}',
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary.withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          if (fixedCosts.isEmpty)
                            Text(
                              '固定費が登録されていません',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted.withOpacity(0.7),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // 編集リンク
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FixedCostHistoryScreen()),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '編集',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentBlue.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.accentBlue.withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState: _fixedCostsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
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
    final dateLabel = _getDateLabel(expense.createdAt);

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
                // メモまたは日付を表示
                Padding(
                  padding: EdgeInsets.only(top: showCategory ? 4 : 0),
                  child: Text(
                    expense.memo != null && expense.memo!.isNotEmpty
                        ? '${expense.memo} • $dateLabel'
                        : dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${formatNumber(expense.amount)}',
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

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return '今日';
    } else if (expenseDate == yesterday) {
      return '昨日';
    } else {
      return '${date.month}/${date.day}';
    }
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
