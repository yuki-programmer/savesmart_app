import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../models/scheduled_expense.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import 'add_scheduled_expense_screen.dart';

/// 予定支出一覧画面
class ScheduledExpensesListScreen extends StatelessWidget {
  final List<ScheduledExpense> expenses;
  final String currencyFormat;

  const ScheduledExpensesListScreen({
    super.key,
    required this.expenses,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '予定している支出',
          style: AppTextStyles.screenTitle(context),
        ),
        centerTitle: true,
      ),
      body: Selector<AppState, (List<ScheduledExpense>, String)>(
        selector: (_, appState) => (
          appState.unconfirmedScheduledExpenses,
          appState.currencyFormat,
        ),
        builder: (context, data, child) {
          final (currentExpenses, format) = data;

          if (currentExpenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 48,
                    color: context.appTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '予定支出はありません',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: context.appTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: currentExpenses.length,
            itemBuilder: (context, index) {
              final scheduled = currentExpenses[index];
              return _ScheduledExpenseCard(
                scheduled: scheduled,
                currencyFormat: format,
                onTap: () => _showActionSheet(context, scheduled),
              );
            },
          );
        },
      ),
    );
  }

  void _showActionSheet(BuildContext context, ScheduledExpense scheduled) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 編集
              ListTile(
                leading: Icon(Icons.edit_outlined, color: context.appTheme.textSecondary),
                title: Text(
                  '編集',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddScheduledExpenseScreen(
                        editingExpense: scheduled,
                      ),
                    ),
                  );
                },
              ),

              // 削除
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.accentRed),
                title: Text(
                  '削除',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentRed,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('削除確認'),
                      content: const Text('この予定支出を削除しますか？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            '削除',
                            style: TextStyle(color: AppColors.accentRed),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    final appState = context.read<AppState>();
                    await appState.deleteScheduledExpense(scheduled.id!);
                  }
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduledExpenseCard extends StatelessWidget {
  final ScheduledExpense scheduled;
  final String currencyFormat;
  final VoidCallback onTap;

  const _ScheduledExpenseCard({
    required this.scheduled,
    required this.currencyFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final date = scheduled.scheduledDate;
    final weekday = weekdays[date.weekday - 1];
    final dateStr = '${date.month}/${date.day}（$weekday）';

    // グレードの色、ラベル、アイコン
    Color gradeColor;
    String gradeLabel;
    IconData gradeIcon;
    switch (scheduled.grade) {
      case 'saving':
        gradeColor = AppColors.expenseSaving;
        gradeLabel = '節約';
        gradeIcon = Icons.savings_outlined;
        break;
      case 'reward':
        gradeColor = AppColors.expenseReward;
        gradeLabel = 'ご褒美';
        gradeIcon = Icons.star_outline;
        break;
      default:
        gradeColor = AppColors.expenseStandard;
        gradeLabel = '標準';
        gradeIcon = Icons.balance_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.borderSubtle),
        ),
        child: Row(
          children: [
            // アイコン
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                gradeIcon,
                size: 22,
                color: gradeColor,
              ),
            ),
            const SizedBox(width: 14),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          scheduled.memo?.isNotEmpty == true
                              ? scheduled.memo!
                              : scheduled.category,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.appTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // グレードバッジ
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gradeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: gradeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: context.appTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.appTheme.textSecondary,
                        ),
                      ),
                      if (scheduled.category.isNotEmpty &&
                          scheduled.memo?.isNotEmpty == true) ...[
                        const SizedBox(width: 10),
                        Text(
                          scheduled.category,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.appTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 金額
            Text(
              formatCurrency(scheduled.amount, currencyFormat),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
