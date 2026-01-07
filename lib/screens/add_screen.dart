import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../widgets/wheel_picker.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import 'fixed_cost_screen.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  // グレード選択状態（nullの場合はグレード選択画面を表示）
  String? _selectedGrade;

  // 支出入力
  int _expenseAmount = 0;
  int _expenseUnit = 100;
  String? _selectedCategory;
  final TextEditingController _memoController = TextEditingController();
  final List<Map<String, dynamic>> _breakdowns = [];

  // グレード定義
  final List<Map<String, dynamic>> _grades = [
    {
      'value': 'saving',
      'label': '節約',
      'description': 'いい判断',
      'icon': Icons.savings_outlined,
      'color': AppColors.accentGreen,
      'lightColor': AppColors.accentGreenLight,
      'shadowOpacity': 0.06,
    },
    {
      'value': 'standard',
      'label': '標準',
      'description': 'いつも通り',
      'icon': Icons.balance_outlined,
      'color': AppColors.accentBlue,
      'lightColor': AppColors.accentBlueLight,
      'shadowOpacity': 0.03,
    },
    {
      'value': 'reward',
      'label': 'ご褒美',
      'description': 'たまの楽しみ',
      'icon': Icons.star_outline,
      'color': AppColors.accentOrange,
      'lightColor': AppColors.accentOrangeLight,
      'shadowOpacity': 0.04,
    },
  ];

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedGrade == null) {
      return _buildGradeSelectionScreen();
    } else {
      return _buildExpenseInputScreen();
    }
  }

  // ========== グレード選択画面 ==========
  Widget _buildGradeSelectionScreen() {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildGradeHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // 問い
                    Text(
                      'これはどんな買い物？',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ディスクレーマー
                    Text(
                      '迷ったら、直感でOK',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'あとからいつでも変更できます',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // グレード選択カード
                    ..._grades.map((grade) => _buildGradeCard(grade)),
                    const SizedBox(height: 16),
                    // 固定費を登録するリンク
                    _buildFixedCostLink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '支出を記録',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.9),
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> grade) {
    final isSaving = grade['value'] == 'saving';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGrade = grade['value'] as String;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSaving ? 0.025 : 0.015),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (grade['lightColor'] as Color).withOpacity(isSaving ? 0.9 : 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  grade['icon'] as IconData,
                  size: 22,
                  color: grade['color'] as Color,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // ラベルと説明
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary.withOpacity(0.9),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grade['description'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // 矢印
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedCostLink() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FixedCostScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '固定費を登録する',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 金額・カテゴリ入力画面 ==========
  Widget _buildExpenseInputScreen() {
    final selectedGradeData = _grades.firstWhere(
      (g) => g['value'] == _selectedGrade,
    );

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildExpenseHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 選択中のグレード表示（タップで変更可能）
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGrade = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedGradeData['lightColor'] as Color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedGradeData['color'] as Color,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selectedGradeData['icon'] as IconData,
                              size: 18,
                              color: selectedGradeData['color'] as Color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedGradeData['label'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selectedGradeData['color'] as Color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color: selectedGradeData['color'] as Color,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 金額表示
                    Center(
                      child: Text(
                        '¥${_formatNumber(_expenseAmount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: selectedGradeData['color'] as Color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 単位選択
                    _buildUnitSelector(
                      units: [10, 100, 1000, 10000],
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
                      maxMultiplier: _expenseUnit >= 1000 ? 100 : 99,
                      initialValue: _expenseAmount,
                      highlightColor: selectedGradeData['lightColor'] as Color,
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
                        Row(
                          children: [
                            Text(
                              'カテゴリ',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'あとで変更できます',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _showAddCategoryModal,
                          child: Text(
                            '+ 新規追加',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedGradeData['color'] as Color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCategoryGrid(selectedGradeData),
                    const SizedBox(height: 24),

                    // 内訳セクション
                    if (_breakdowns.isNotEmpty) ...[
                      Text(
                        '内訳',
                        style: GoogleFonts.inter(
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

                    // メモ入力
                    Text(
                      'メモ（任意）',
                      style: GoogleFonts.inter(
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
                        hintStyle: GoogleFonts.inter(
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
                      _buildExpenseSummary(selectedGradeData),
                    if (_expenseAmount > 0 && _selectedCategory != null)
                      const SizedBox(height: 24),

                    // 記録ボタン
                    _buildGradientButton(
                      label: '記録する',
                      onPressed: _recordExpense,
                      colors: [
                        selectedGradeData['color'] as Color,
                        (selectedGradeData['color'] as Color).withOpacity(0.8),
                      ],
                    ),
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

  Widget _buildExpenseHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedGrade = null;
              });
            },
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
              '支出を記録',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.9),
                height: 1.3,
              ),
            ),
          ),
          Container(
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
            child: IconButton(
              icon: Icon(Icons.close, size: 20, color: AppColors.textSecondary.withOpacity(0.7)),
              onPressed: () {
                setState(() {
                  _selectedGrade = null;
                });
              },
            ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(Map<String, dynamic> gradeData) {
    final categories = context.watch<AppState>().categoryNames;
    final gradeColor = gradeData['color'] as Color;
    final gradeLightColor = gradeData['lightColor'] as Color;

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
              color: isSelected ? gradeLightColor : AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? gradeColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? gradeColor : AppColors.textSecondary,
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
                  style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
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
            style: GoogleFonts.ibmPlexSans(
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
        return {
          'label': '💰 節約',
          'color': AppColors.accentGreenLight,
          'textColor': AppColors.accentGreen
        };
      case 'reward':
        return {
          'label': '⭐ ご褒美',
          'color': AppColors.accentPurpleLight,
          'textColor': AppColors.accentPurple
        };
      default:
        return {
          'label': '🎯 標準',
          'color': AppColors.accentBlueLight,
          'textColor': AppColors.accentBlue
        };
    }
  }

  int get _breakdownsTotal =>
      _breakdowns.fold(0, (sum, b) => sum + (b['amount'] as int));

  int get _mainCategoryAmount => _expenseAmount - _breakdownsTotal;

  Widget _buildExpenseSummary(Map<String, dynamic> gradeData) {
    final hasBreakdowns = _breakdowns.isNotEmpty;
    final mainTypeInfo = _getTypeInfo(_selectedGrade ?? 'standard');
    final gradeColor = gradeData['color'] as Color;
    final gradeLightColor = gradeData['lightColor'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradeLightColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '登録内容',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: gradeColor,
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
                    style: GoogleFonts.inter(
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
                      style: GoogleFonts.inter(
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
                style: GoogleFonts.ibmPlexSans(
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
                          style: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                      style: GoogleFonts.ibmPlexSans(
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '¥${_formatNumber(_expenseAmount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: gradeColor,
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
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.accentRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '内訳の合計が入力金額を超えています',
                      style: GoogleFonts.inter(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.textMuted.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '内訳を追加',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '必要な人だけ',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colors[0].withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
                style: GoogleFonts.inter(
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
                  hintStyle: GoogleFonts.inter(
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
                            style: GoogleFonts.inter(
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
                          await context
                              .read<AppState>()
                              .addCategory(controller.text);
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
                            style: GoogleFonts.inter(
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
      {
        'key': 'saving',
        'label': '💰 節約',
        'color': AppColors.accentGreenLight,
        'textColor': AppColors.accentGreen
      },
      {
        'key': 'standard',
        'label': '🎯 標準',
        'color': AppColors.accentBlueLight,
        'textColor': AppColors.accentBlue
      },
      {
        'key': 'reward',
        'label': '⭐ ご褒美',
        'color': AppColors.accentPurpleLight,
        'textColor': AppColors.accentPurple
      },
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
                color: isSelected ? type['color'] as Color : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isSelected ? type['textColor'] as Color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  type['label'] as String,
                  style: GoogleFonts.inter(
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
    final availableCategories =
        categories.where((c) => c != _selectedCategory).toList();

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
                          style: GoogleFonts.inter(
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
                            style: GoogleFonts.ibmPlexSans(
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
                            units: [10, 100, 1000, 10000],
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
                            maxMultiplier: breakdownUnit >= 1000 ? 100 : 99,
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
                          style: GoogleFonts.inter(
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
                              style: GoogleFonts.inter(
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
                                  style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
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
                                style: GoogleFonts.inter(
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
    if (_expenseAmount <= 0) return;

    // カテゴリ未選択の場合はデフォルトカテゴリを使用
    final category = _selectedCategory ?? 'その他';

    // 内訳がある場合、メイン金額が0以下なら登録しない
    if (_breakdowns.isNotEmpty && _mainCategoryAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '内訳の合計が入力金額を超えています',
            style: GoogleFonts.inter(),
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
    final mainAmount =
        _breakdowns.isNotEmpty ? _mainCategoryAmount : _expenseAmount;

    final expense = Expense(
      amount: mainAmount,
      category: category,
      grade: _selectedGrade ?? 'standard',
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

    final gradeData = _grades.firstWhere(
      (g) => g['value'] == _selectedGrade,
      orElse: () => _grades[1],
    );

    // 入力をリセットしてグレード選択に戻る
    setState(() {
      _expenseAmount = 0;
      _selectedCategory = null;
      _memoController.clear();
      _breakdowns.clear();
      _selectedGrade = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¥${_formatNumber(expense.amount)} を記録しました',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: gradeData['color'] as Color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
