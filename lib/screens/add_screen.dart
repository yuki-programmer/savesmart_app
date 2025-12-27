import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../widgets/wheel_picker.dart';
import '../services/database_service.dart';
import '../models/budget.dart';
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

  // カテゴリリスト
  final List<String> _categories = List.from(AppConstants.defaultCategories);

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
            icon: '🎯',
            title: '予算を設定',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          // 金額表示
          Center(
            child: Text(
              '¥${_formatNumber(_budgetAmount)}',
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.accentBlue,
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
            key: ValueKey('budget_$_budgetUnit'),
            unit: _budgetUnit,
            maxMultiplier: _budgetUnit == 100000 ? 10 : 100,
            initialValue: _budgetAmount,
            highlightColor: AppColors.accentBlueLight,
            onChanged: (value) {
              setState(() {
                _budgetAmount = value;
              });
            },
          ),
          const SizedBox(height: 24),

          // 設定ボタン
          _buildGradientButton(
            label: '設定する',
            onPressed: _setBudget,
            colors: [AppColors.accentBlue, const Color(0xFF2563EB)],
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
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
            child: Text(
              breakdown['category'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
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
                      onTap: () {
                        if (controller.text.isNotEmpty) {
                          setState(() {
                            _categories.add(controller.text);
                          });
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

  void _showAddBreakdownModal() {
    int breakdownAmount = 0;
    int breakdownUnit = 100;
    String? breakdownCategory;
    final availableCategories = _categories
        .where((c) => c != _selectedCategory)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
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

                const Spacer(),

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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordExpense() async {
    if (_expenseAmount <= 0 || _selectedCategory == null) return;

    final expense = Expense(
      amount: _expenseAmount,
      category: _selectedCategory!,
      grade: _selectedType,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      createdAt: DateTime.now(),
    );

    await DatabaseService().insertExpense(expense);

    // 内訳も保存
    for (final breakdown in _breakdowns) {
      final breakdownExpense = Expense(
        amount: breakdown['amount'] as int,
        category: breakdown['category'] as String,
        grade: _selectedType,
        createdAt: DateTime.now(),
      );
      await DatabaseService().insertExpense(breakdownExpense);
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

    final now = DateTime.now();
    final budget = Budget(
      amount: _budgetAmount,
      year: now.year,
      month: now.month,
    );

    await DatabaseService().insertBudget(budget);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '予算を ¥${_formatNumber(_budgetAmount)} に設定しました',
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
