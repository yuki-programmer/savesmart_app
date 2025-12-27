import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import 'wheel_picker.dart';

class SplitModal extends StatefulWidget {
  final Expense expense;
  final VoidCallback onSplit;

  const SplitModal({
    super.key,
    required this.expense,
    required this.onSplit,
  });

  @override
  State<SplitModal> createState() => _SplitModalState();
}

class _SplitModalState extends State<SplitModal> {
  int _splitAmount = 0;
  int _splitUnit = 100;
  String? _targetCategory;
  late List<String> _availableCategories;

  @override
  void initState() {
    super.initState();
    _availableCategories = AppConstants.defaultCategories
        .where((c) => c != widget.expense.category)
        .toList();
    if (_availableCategories.isNotEmpty) {
      _targetCategory = _availableCategories.first;
    }
  }

  int get _maxSplitAmount => widget.expense.amount - 1;

  int get _remainingAmount => widget.expense.amount - _splitAmount;

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // タイトル
          Text(
            '支出を切り出す',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '一部を別のカテゴリに移動します',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 元の支出情報
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expense.category,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '¥${_formatNumber(widget.expense.amount)}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 切り出す金額
          Text(
            '切り出す金額',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${_formatNumber(_splitAmount)}',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 12),

          // 単位選択
          _buildUnitSelector(),
          const SizedBox(height: 8),

          // ホイールピッカー
          SizedBox(
            height: 150,
            child: WheelPicker(
              key: ValueKey('split_$_splitUnit'),
              unit: _splitUnit,
              maxMultiplier: (_maxSplitAmount / _splitUnit).floor(),
              initialValue: _splitAmount,
              highlightColor: AppColors.accentBlueLight,
              onChanged: (value) {
                if (value <= _maxSplitAmount) {
                  setState(() {
                    _splitAmount = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // 移動先カテゴリ
          Text(
            '移動先カテゴリ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _targetCategory,
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(
                'カテゴリを選択',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                ),
              ),
              items: _availableCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _targetCategory = value;
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // プレビュー
          if (_splitAmount > 0 && _targetCategory != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentBlueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.expense.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '¥${_formatNumber(_remainingAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _targetCategory!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '¥${_formatNumber(_splitAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ボタン
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _splitAmount > 0 && _targetCategory != null
                      ? _performSplit
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _splitAmount > 0 && _targetCategory != null
                          ? AppColors.accentBlue
                          : AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '切り出す',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector() {
    final units = [10, 100, 1000];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: units.map((unit) {
          final isSelected = _splitUnit == unit;
          return GestureDetector(
            onTap: () {
              setState(() {
                _splitUnit = unit;
                _splitAmount = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$unit円',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _performSplit() async {
    if (_splitAmount <= 0 || _targetCategory == null) return;

    final db = DatabaseService();

    // 元の支出を更新
    final updatedOriginal = Expense(
      id: widget.expense.id,
      amount: _remainingAmount,
      category: widget.expense.category,
      grade: widget.expense.grade,
      memo: widget.expense.memo,
      createdAt: widget.expense.createdAt,
      parentId: widget.expense.parentId,
    );
    await db.updateExpense(updatedOriginal);

    // 新しい支出を作成
    final newExpense = Expense(
      amount: _splitAmount,
      category: _targetCategory!,
      grade: widget.expense.grade,
      memo: '${widget.expense.category}から切り出し',
      createdAt: widget.expense.createdAt,
      parentId: widget.expense.id,
    );
    await db.insertExpense(newExpense);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSplit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¥${_formatNumber(_splitAmount)} を $_targetCategory に切り出しました',
          style: GoogleFonts.plusJakartaSans(),
        ),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

void showSplitModal(BuildContext context, Expense expense, VoidCallback onSplit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SplitModal(
        expense: expense,
        onSplit: onSplit,
      ),
    ),
  );
}
