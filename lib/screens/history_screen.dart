import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import '../widgets/split_modal.dart';
import '../widgets/edit_amount_modal.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final expense in expenses) {
      final expenseDate = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );

      String dateLabel;
      if (expenseDate == today) {
        dateLabel = '今日';
      } else if (expenseDate == yesterday) {
        dateLabel = '昨日';
      } else {
        dateLabel = '${expenseDate.month}月${expenseDate.day}日';
      }

      grouped.putIfAbsent(dateLabel, () => []);
      grouped[dateLabel]!.add(expense);
    }

    return grouped;
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_searchController.text.isEmpty) {
      return expenses;
    }
    final query = _searchController.text.toLowerCase();
    return expenses.where((expense) {
      return expense.category.toLowerCase().contains(query) ||
          (expense.memo?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isSearching) _buildSearchBar(),
                Expanded(
                  child: appState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildExpenseList(appState.expenses),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '履歴',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isSearching ? AppColors.accentBlueLight.withOpacity(0.7) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: _isSearching
                    ? AppColors.accentBlue
                    : AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'カテゴリ・メモで検索',
          hintStyle: GoogleFonts.inter(
            color: AppColors.textMuted.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.textMuted.withOpacity(0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textMuted.withOpacity(0.6), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.borderSubtle.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.borderSubtle.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.accentBlue.withOpacity(0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseList(List<Expense> expenses) {
    final filteredExpenses = _filterExpenses(expenses);

    if (filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textMuted.withOpacity(0.4),
            ),
            const SizedBox(height: 14),
            Text(
              _searchController.text.isNotEmpty
                  ? '検索結果がありません'
                  : '支出データがありません',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // 検索中はグループ化しない
    if (_searchController.text.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: filteredExpenses.length,
        itemBuilder: (context, index) {
          return _buildExpenseCard(filteredExpenses[index]);
        },
      );
    }

    // 日付でグループ化
    final grouped = _groupExpensesByDate(filteredExpenses);
    final dateLabels = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: dateLabels.length,
      itemBuilder: (context, index) {
        final dateLabel = dateLabels[index];
        final expenses = grouped[dateLabel]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Text(
                dateLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ),
            ...expenses.map((expense) => _buildExpenseCard(expense)),
          ],
        );
      },
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final time =
        '${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
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
          // メインコンテンツ
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // カテゴリが「その他」の場合は非表示
                      if (expense.category != 'その他')
                        Text(
                          expense.category,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      if (expense.category != 'その他')
                        const SizedBox(height: 4),
                      Text(
                        expense.category == 'その他'
                            ? (expense.memo != null && expense.memo!.isNotEmpty ? '${expense.memo} • $time' : time)
                            : '${expense.memo ?? ''} • $time',
                        style: GoogleFonts.inter(
                          fontSize: expense.category == 'その他' && (expense.memo == null || expense.memo!.isEmpty) ? 13 : 12,
                          fontWeight: FontWeight.w400,
                          color: expense.category == 'その他' && (expense.memo == null || expense.memo!.isEmpty)
                              ? AppColors.textSecondary.withOpacity(0.8)
                              : AppColors.textMuted.withOpacity(0.75),
                          height: 1.4,
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
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTypeBadge(expense.grade),
                  ],
                ),
              ],
            ),
          ),
          // アクションボタン
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.5)),
              ),
            ),
            child: Row(
              children: [
                _buildActionButton(
                  icon: '✂️',
                  label: '切り出す',
                  color: AppColors.accentBlue,
                  onTap: () => _showSplitModal(expense),
                ),
                _buildActionButton(
                  icon: '✏️',
                  label: '金額修正',
                  color: AppColors.accentOrange,
                  onTap: () => _showEditAmountModal(expense),
                ),
                _buildActionButton(
                  icon: '🗑️',
                  label: '削除',
                  color: AppColors.accentRed,
                  onTap: () => _showDeleteConfirmation(expense),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    right: BorderSide(color: AppColors.borderSubtle.withOpacity(0.5)),
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.9),
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showSplitModal(Expense expense) {
    showSplitModal(context, expense, () {
      context.read<AppState>().loadData();
    });
  }

  void _showEditAmountModal(Expense expense) {
    showEditAmountModal(context, expense, () {
      context.read<AppState>().loadData();
    });
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '支出を削除',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '「${expense.category}」¥${_formatNumber(expense.amount)} を削除しますか？\nこの操作は取り消せません。',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppState>().deleteExpense(expense.id!);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '削除しました',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: AppColors.accentRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              '削除',
              style: GoogleFonts.inter(
                color: AppColors.accentRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
