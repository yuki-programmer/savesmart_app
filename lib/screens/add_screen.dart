import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../widgets/wheel_picker.dart';
import '../services/app_state.dart';
import '../models/expense.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  // 支出セクション
  bool _isExpenseExpanded = true;
  bool _isBudgetExpanded = false;
  int _expenseAmount = 0;
  int _expenseUnit = 100;
  String? _selectedCategory;
  String _selectedType = 'standard';
  final TextEditingController _memoController = TextEditingController();
  final List<Map<String, dynamic>> _breakdowns = [];

  // 予算セクション
  int _budgetAmount = 0;
  int _budgetUnit = 10000;
  bool _isAddMode = true; // true: 追加, false: 減額

  // カテゴリリストはAppStateから取得

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildExpenseSection(),
                    const SizedBox(height: 16),
                    _buildBudgetSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '追加',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
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
              icon: const Icon(Icons.close, size: 22),
              color: AppColors.textSecondary,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAccordionHeader(
            icon: '💸',
            title: '支出を記録',
            isExpanded: _isExpenseExpanded,
            onTap: () {
              setState(() {
                _isExpenseExpanded = !_isExpenseExpanded;
              });
            },
          ),
          if (_isExpenseExpanded) _buildExpenseContent(),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAccordionHeader(
            icon: '💰',
            title: '予算を調整',
            isExpanded: _isBudgetExpanded,
            onTap: () {
              setState(() {
                _isBudgetExpanded = !_isBudgetExpanded;
              });
            },
          ),
          if (_isBudgetExpanded) _buildBudgetContent(),
        ],
      ),
    );
  }

  Widget _buildAccordionHeader({
    required String icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 金額表示
          Center(
            child: Text(
              '¥${_formatNumber(_expenseAmount)}',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.accentGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 単位選択
          _buildUnitSelector(
            units: [10, 100, 1000],
            selectedUnit: _expenseUnit,
            onChanged: (unit) {
              setState(() {
                _expenseUnit = unit;
                _expenseAmount = 0;
              });
            },
          ),
          const SizedBox(height: 8),

          // ホイールピッカー
          WheelPicker(
            key: ValueKey('expense_$_expenseUnit'),
            unit: _expenseUnit,
            maxMultiplier: _expenseUnit == 1000 ? 100 : 99,
            initialValue: _expenseAmount,
            highlightColor: AppColors.accentGreenLight,
            onChanged: (value) {
              setState(() {
                _expenseAmount = value;
              });
            },
          ),
          const SizedBox(height: 24),

          // カテゴリ選択
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'カテゴリ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _showAddCategoryModal,
                child: Text(
                  '+ 新規追加',
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
          _buildCategoryGrid(),
          const SizedBox(height: 24),

          // 内訳セクション
          if (_breakdowns.isNotEmpty) ...[
            Text(
              '内訳',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._breakdowns.map((b) => _buildBreakdownItem(b)),
            const SizedBox(height: 12),
          ],
          _buildAddBreakdownButton(),
          const SizedBox(height: 24),

          // タイプ選択
          Text(
            'タイプ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildTypeSelector(),
          const SizedBox(height: 24),

          // メモ入力
          Text(
            'メモ（任意）',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            decoration: InputDecoration(
              hintText: '例: スタバ 新作フラペチーノ',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.bgPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 登録内容の確認表示
          if (_expenseAmount > 0 && _selectedCategory != null)
            _buildExpenseSummary(),
          if (_expenseAmount > 0 && _selectedCategory != null)
            const SizedBox(height: 24),

          // 記録ボタン
          _buildGradientButton(
            label: '記録する',
            onPressed: _recordExpense,
            colors: [AppColors.accentGreen, AppColors.accentGreenDark],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetContent() {
    final currentBudget = context.watch<AppState>().currentBudget?.amount ?? 0;
    final newBudget = _isAddMode
        ? currentBudget + _budgetAmount
        : currentBudget - _budgetAmount;
    final isValidBudget = newBudget >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // 現在の予算表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '現在の予算',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${_formatNumber(currentBudget)}',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 追加/減額トグル
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAddMode = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAddMode ? AppColors.accentGreenLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '＋ 追加',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isAddMode ? AppColors.accentGreen : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAddMode = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: !_isAddMode ? AppColors.accentRedLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '− 減額',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !_isAddMode ? AppColors.accentRed : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 調整金額表示
          Center(
            child: Text(
              '${_isAddMode ? '+' : '-'} ¥${_formatNumber(_budgetAmount)}',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: _isAddMode ? AppColors.accentGreen : AppColors.accentRed,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 単位選択
          _buildUnitSelector(
            units: [1000, 10000, 100000],
            selectedUnit: _budgetUnit,
            onChanged: (unit) {
              setState(() {
                _budgetUnit = unit;
                _budgetAmount = 0;
              });
            },
            labels: ['1000円', '1万円', '10万円'],
          ),
          const SizedBox(height: 8),

          // ホイールピッカー
          WheelPicker(
            key: ValueKey('budget_${_budgetUnit}_$_isAddMode'),
            unit: _budgetUnit,
            maxMultiplier: _budgetUnit == 100000 ? 10 : 100,
            initialValue: _budgetAmount,
            highlightColor: _isAddMode ? AppColors.accentGreenLight : AppColors.accentRedLight,
            onChanged: (value) {
              setState(() {
                _budgetAmount = value;
              });
            },
          ),
          const SizedBox(height: 20),

          // プレビュー表示
          if (_budgetAmount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isValidBudget
                    ? (_isAddMode ? AppColors.accentGreenLight : AppColors.accentRedLight).withOpacity(0.5)
                    : AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isValidBudget
                      ? (_isAddMode ? AppColors.accentGreen : AppColors.accentRed).withOpacity(0.3)
                      : AppColors.accentRed.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '変更後の予算',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '¥${_formatNumber(newBudget)}',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isValidBudget
                              ? (_isAddMode ? AppColors.accentGreen : AppColors.accentRed)
                              : AppColors.accentRed,
                        ),
                      ),
                    ],
                  ),
                  if (!isValidBudget) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '予算がマイナスになります',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (_budgetAmount > 0) const SizedBox(height: 24),

          // 確定ボタン
          _buildGradientButton(
            label: _isAddMode ? '予算を追加' : '予算を減額',
            onPressed: isValidBudget && _budgetAmount > 0 ? _setBudget : () {},
            colors: _isAddMode
                ? [AppColors.accentGreen, AppColors.accentGreenDark]
                : [AppColors.accentRed, const Color(0xFFDC2626)],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector({
    required List<int> units,
    required int selectedUnit,
    required Function(int) onChanged,
    List<String>? labels,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(units.length, (index) {
          final unit = units[index];
          final isSelected = selectedUnit == unit;
          final label = labels != null ? labels[index] : '$unit円';
          return GestureDetector(
            onTap: () => onChanged(unit),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = context.watch<AppState>().categoryNames;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategory == category;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentGreenLight
                  : AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentGreen
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                category,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdownItem(Map<String, dynamic> breakdown) {
    final type = breakdown['type'] as String? ?? 'standard';
    final typeInfo = _getTypeInfo(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  breakdown['category'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeInfo['color'] as Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeInfo['label'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: typeInfo['textColor'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${_formatNumber(breakdown['amount'] as int)}',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _breakdowns.remove(breakdown);
              });
            },
            child: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(String type) {
    switch (type) {
      case 'saving':
        return {'label': '💰 節約', 'color': AppColors.accentGreenLight, 'textColor': AppColors.accentGreen};
      case 'reward':
        return {'label': '⭐ ご褒美', 'color': AppColors.accentPurpleLight, 'textColor': AppColors.accentPurple};
      default:
        return {'label': '🎯 標準', 'color': AppColors.accentBlueLight, 'textColor': AppColors.accentBlue};
    }
  }

  int get _breakdownsTotal => _breakdowns.fold(0, (sum, b) => sum + (b['amount'] as int));

  int get _mainCategoryAmount => _expenseAmount - _breakdownsTotal;

  Widget _buildExpenseSummary() {
    final hasBreakdowns = _breakdowns.isNotEmpty;
    final mainTypeInfo = _getTypeInfo(_selectedType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentGreenLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '登録内容',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(height: 12),

          // メインカテゴリ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _selectedCategory ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mainTypeInfo['color'] as Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mainTypeInfo['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: mainTypeInfo['textColor'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '¥${_formatNumber(hasBreakdowns ? _mainCategoryAmount : _expenseAmount)}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // 内訳がある場合
          if (hasBreakdowns) ...[
            const SizedBox(height: 8),
            ...(_breakdowns.map((b) {
              final typeInfo = _getTypeInfo(b['type'] as String? ?? 'standard');
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          b['category'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeInfo['color'] as Color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeInfo['label'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: typeInfo['textColor'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '¥${_formatNumber(b['amount'] as int)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            })),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '合計',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '¥${_formatNumber(_expenseAmount)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGreen,
                  ),
                ),
              ],
            ),
          ],

          // 内訳合計がメイン金額を超えている場合の警告
          if (hasBreakdowns && _mainCategoryAmount < 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '内訳の合計が入力金額を超えています',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddBreakdownButton() {
    return GestureDetector(
      onTap: _showAddBreakdownModal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentBlue,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              color: AppColors.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '内訳を追加',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      {'key': 'saving', 'label': '💰 節約', 'color': AppColors.accentGreenLight, 'textColor': AppColors.accentGreen},
      {'key': 'standard', 'label': '🎯 標準', 'color': AppColors.accentBlueLight, 'textColor': AppColors.accentBlue},
      {'key': 'reward', 'label': '⭐ ご褒美', 'color': AppColors.accentPurpleLight, 'textColor': AppColors.accentPurple},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedType == type['key'];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedType = type['key'] as String;
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: type['key'] != 'reward' ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? type['color'] as Color
                    : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? type['textColor'] as Color
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  type['label'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? type['textColor'] as Color
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
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

  void _showAddCategoryModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'カテゴリを追加',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'カテゴリ名を入力',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.bgPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'キャンセル',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
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
                      onTap: () async {
                        if (controller.text.isNotEmpty) {
                          await context.read<AppState>().addCategory(controller.text);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '追加',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildBreakdownTypeSelector({
    required String selectedType,
    required Function(String) onChanged,
  }) {
    final types = [
      {'key': 'saving', 'label': '💰 節約', 'color': AppColors.accentGreenLight, 'textColor': AppColors.accentGreen},
      {'key': 'standard', 'label': '🎯 標準', 'color': AppColors.accentBlueLight, 'textColor': AppColors.accentBlue},
      {'key': 'reward', 'label': '⭐ ご褒美', 'color': AppColors.accentPurpleLight, 'textColor': AppColors.accentPurple},
    ];

    return Row(
      children: types.map((type) {
        final isSelected = selectedType == type['key'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type['key'] as String),
            child: Container(
              margin: EdgeInsets.only(
                right: type['key'] != 'reward' ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? type['color'] as Color
                    : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? type['textColor'] as Color
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  type['label'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? type['textColor'] as Color
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddBreakdownModal() {
    int breakdownAmount = 0;
    int breakdownUnit = 100;
    String? breakdownCategory;
    String breakdownType = 'standard';
    final categories = context.read<AppState>().categoryNames;
    final availableCategories = categories
        .where((c) => c != _selectedCategory)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // スクロール可能なコンテンツ
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '内訳を追加',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 金額表示
                        Center(
                          child: Text(
                            '¥${_formatNumber(breakdownAmount)}',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 単位選択
                        Center(
                          child: _buildUnitSelector(
                            units: [10, 100, 1000],
                            selectedUnit: breakdownUnit,
                            onChanged: (unit) {
                              setModalState(() {
                                breakdownUnit = unit;
                                breakdownAmount = 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ホイールピッカー
                        SizedBox(
                          height: 160,
                          child: WheelPicker(
                            key: ValueKey('breakdown_$breakdownUnit'),
                            unit: breakdownUnit,
                            maxMultiplier: breakdownUnit == 1000 ? 100 : 99,
                            initialValue: breakdownAmount,
                            highlightColor: AppColors.accentBlueLight,
                            onChanged: (value) {
                              setModalState(() {
                                breakdownAmount = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // カテゴリ選択
                        Text(
                          'カテゴリ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                            value: breakdownCategory,
                            hint: Text(
                              'カテゴリを選択',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                              ),
                            ),
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: availableCategories.map((category) {
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
                              setModalState(() {
                                breakdownCategory = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // タイプ選択
                        Text(
                          'タイプ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildBreakdownTypeSelector(
                          selectedType: breakdownType,
                          onChanged: (type) {
                            setModalState(() {
                              breakdownType = type;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ボタン（固定）
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.bgPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'キャンセル',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
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
                          onTap: () {
                            if (breakdownAmount > 0 && breakdownCategory != null) {
                              setState(() {
                                _breakdowns.add({
                                  'amount': breakdownAmount,
                                  'category': breakdownCategory,
                                  'type': breakdownType,
                                });
                              });
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '追加',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordExpense() async {
    if (_expenseAmount <= 0 || _selectedCategory == null) return;

    // 内訳がある場合、メイン金額が0以下なら登録しない
    if (_breakdowns.isNotEmpty && _mainCategoryAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '内訳の合計が入力金額を超えています',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final appState = context.read<AppState>();

    // 内訳がある場合はメイン金額から内訳合計を差し引く
    final mainAmount = _breakdowns.isNotEmpty ? _mainCategoryAmount : _expenseAmount;

    final expense = Expense(
      amount: mainAmount,
      category: _selectedCategory!,
      grade: _selectedType,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      createdAt: DateTime.now(),
    );

    if (_breakdowns.isNotEmpty) {
      // 内訳がある場合はaddExpenseWithBreakdownsを使用
      await appState.addExpenseWithBreakdowns(expense, _breakdowns);
    } else {
      await appState.addExpense(expense);
    }

    if (!mounted) return;

    // 入力をリセット
    setState(() {
      _expenseAmount = 0;
      _selectedCategory = null;
      _selectedType = 'standard';
      _memoController.clear();
      _breakdowns.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¥${_formatNumber(expense.amount)} を記録しました',
          style: GoogleFonts.plusJakartaSans(),
        ),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _setBudget() async {
    if (_budgetAmount <= 0) return;

    final appState = context.read<AppState>();
    final currentBudget = appState.currentBudget?.amount ?? 0;
    final newBudget = _isAddMode
        ? currentBudget + _budgetAmount
        : currentBudget - _budgetAmount;

    // マイナスになる場合は設定しない
    if (newBudget < 0) return;

    await appState.setBudget(newBudget);

    if (!mounted) return;

    final message = _isAddMode
        ? '予算を ¥${_formatNumber(_budgetAmount)} 追加しました'
        : '予算を ¥${_formatNumber(_budgetAmount)} 減額しました';

    // 入力をリセット
    setState(() {
      _budgetAmount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(),
        ),
        backgroundColor: _isAddMode ? AppColors.accentGreen : AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
