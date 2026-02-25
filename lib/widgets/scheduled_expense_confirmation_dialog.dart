import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../models/scheduled_expense.dart';
import '../services/app_state.dart';
import '../screens/add_scheduled_expense_screen.dart';
import '../utils/formatters.dart';

/// 予定支出確認ダイアログ
/// アプリ起動時に過去日の未確認予定支出がある場合に表示
class ScheduledExpenseConfirmationDialog extends StatefulWidget {
  final List<ScheduledExpense> overdueExpenses;

  const ScheduledExpenseConfirmationDialog({
    super.key,
    required this.overdueExpenses,
  });

  /// ダイアログを表示し、すべての予定支出を処理するまで待機
  static Future<void> showIfNeeded(BuildContext context) async {
    final appState = context.read<AppState>();

    // プレミアムユーザーのみ
    if (!appState.isPremium) return;

    final overdueExpenses = await appState.getOverdueScheduledExpenses();
    if (overdueExpenses.isEmpty) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // スキップ不可
      builder: (context) => ScheduledExpenseConfirmationDialog(
        overdueExpenses: overdueExpenses,
      ),
    );
  }

  @override
  State<ScheduledExpenseConfirmationDialog> createState() =>
      _ScheduledExpenseConfirmationDialogState();
}

class _ScheduledExpenseConfirmationDialogState
    extends State<ScheduledExpenseConfirmationDialog> {
  late List<ScheduledExpense> _remainingExpenses;
  int _currentIndex = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingExpenses = List.from(widget.overdueExpenses);
  }

  ScheduledExpense get _currentExpense => _remainingExpenses[_currentIndex];

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _getGradeLabel(String grade) {
    switch (grade) {
      case 'saving':
        return '節約';
      case 'standard':
        return '標準';
      case 'reward':
        return 'ご褒美';
      default:
        return grade;
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'saving':
        return AppColors.expenseSaving;
      case 'standard':
        return AppColors.expenseStandard;
      case 'reward':
        return AppColors.expenseReward;
      default:
        return context.appTheme.textSecondary;
    }
  }

  Future<void> _confirmAsIs() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final appState = context.read<AppState>();
    final success = await appState.confirmScheduledExpense(_currentExpense);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      _moveToNextOrClose();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('確認に失敗しました'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _modifyAndConfirm() async {
    if (_isProcessing) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddScheduledExpenseScreen(
          editingExpense: _currentExpense,
          isConfirmationMode: true,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      _moveToNextOrClose();
    }
  }

  void _moveToNextOrClose() {
    _remainingExpenses.removeAt(_currentIndex);

    if (_remainingExpenses.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        if (_currentIndex >= _remainingExpenses.length) {
          _currentIndex = _remainingExpenses.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = context.read<AppState>().currencyFormat;
    final expense = _currentExpense;
    final remainingCount = _remainingExpenses.length;

    return Dialog(
      backgroundColor: context.appTheme.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: AppColors.accentOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '予定支出の確認',
                        style: AppTextStyles.sectionTitle(context).copyWith(fontSize: 18),
                      ),
                      if (remainingCount > 1)
                        Text(
                          '残り$remainingCount件',
                          style: AppTextStyles.sub(context),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 予定日
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: context.appTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '予定日: ${_formatDate(expense.scheduledDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: context.appTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 金額
            Center(
              child: Text(
                formatCurrency(expense.amount, currencyFormat),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // カテゴリとグレード
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.appTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      expense.category,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getGradeColor(expense.grade).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getGradeLabel(expense.grade),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getGradeColor(expense.grade),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // メモ
            if (expense.memo != null && expense.memo!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  expense.memo!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.appTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // アクションボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _modifyAndConfirm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.appTheme.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '修正',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmAsIs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '確認',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
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
}
