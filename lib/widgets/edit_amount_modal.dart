import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import 'wheel_picker.dart';

class EditAmountModal extends StatefulWidget {
  final Expense expense;
  final VoidCallback onUpdate;

  const EditAmountModal({
    super.key,
    required this.expense,
    required this.onUpdate,
  });

  @override
  State<EditAmountModal> createState() => _EditAmountModalState();
}

class _EditAmountModalState extends State<EditAmountModal> {
  late int _newAmount;
  late int _unit;

  @override
  void initState() {
    super.initState();
    _newAmount = widget.expense.amount;
    // 金額に応じて適切な単位を選択
    if (widget.expense.amount >= 10000) {
      _unit = 1000;
    } else if (widget.expense.amount >= 1000) {
      _unit = 100;
    } else {
      _unit = 10;
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // タイトル
          Text(
            '金額を修正',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withOpacity(0.9),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.expense.category}の金額を変更します',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),

          // 現在の金額
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '現在の金額',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withOpacity(0.75),
                    height: 1.4,
                  ),
                ),
                Text(
                  '¥${_formatNumber(widget.expense.amount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 新しい金額
          Text(
            '新しい金額',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${_formatNumber(_newAmount)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: AppColors.accentOrange,
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
              key: ValueKey('edit_$_unit'),
              unit: _unit,
              maxMultiplier: _unit == 1000 ? 100 : 99,
              initialValue: _newAmount,
              highlightColor: AppColors.accentOrangeLight,
              onChanged: (value) {
                setState(() {
                  _newAmount = value;
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // 差額表示
          if (_newAmount != widget.expense.amount)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _newAmount > widget.expense.amount
                    ? AppColors.accentRedLight.withOpacity(0.6)
                    : AppColors.accentGreenLight.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _newAmount > widget.expense.amount
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 16,
                    color: _newAmount > widget.expense.amount
                        ? AppColors.accentRed
                        : AppColors.accentGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¥${_formatNumber((_newAmount - widget.expense.amount).abs())} ${_newAmount > widget.expense.amount ? '増加' : '減少'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _newAmount > widget.expense.amount
                          ? AppColors.accentRed
                          : AppColors.accentGreen,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),

          // ボタン
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _newAmount > 0 && _newAmount != widget.expense.amount
                      ? _performUpdate
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _newAmount > 0 && _newAmount != widget.expense.amount
                          ? AppColors.accentOrange.withOpacity(0.9)
                          : AppColors.textMuted.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '変更する',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
          final isSelected = _unit == unit;
          return GestureDetector(
            onTap: () {
              setState(() {
                _unit = unit;
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
                style: GoogleFonts.inter(
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

  Future<void> _performUpdate() async {
    if (_newAmount <= 0) return;

    final updatedExpense = Expense(
      id: widget.expense.id,
      amount: _newAmount,
      category: widget.expense.category,
      grade: widget.expense.grade,
      memo: widget.expense.memo,
      createdAt: widget.expense.createdAt,
      parentId: widget.expense.parentId,
    );

    await DatabaseService().updateExpense(updatedExpense);

    if (!mounted) return;
    Navigator.pop(context);
    widget.onUpdate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '金額を ¥${_formatNumber(_newAmount)} に更新しました',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: AppColors.accentOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

void showEditAmountModal(BuildContext context, Expense expense, VoidCallback onUpdate) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: EditAmountModal(
        expense: expense,
        onUpdate: onUpdate,
      ),
    ),
  );
}
