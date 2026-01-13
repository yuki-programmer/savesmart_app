import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../utils/formatters.dart';
import '../widgets/wheel_picker.dart';
import '../widgets/expense/add_category_modal.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import 'fixed_cost_screen.dart';

/// 支出記録画面（1ページ完結型）
/// 入力順: カテゴリ → 金額 → 支出タイプ
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  // 入力状態
  String? _selectedCategory;
  int _expenseAmount = 0;
  int _expenseUnit = 100;
  String _selectedGrade = 'standard'; // デフォルト: 標準
  final TextEditingController _memoController = TextEditingController();

  // スマート・コンボ予測
  List<Map<String, dynamic>> _smartCombos = [];
  bool _isLoadingCombos = false;

  // グレード定義
  final List<Map<String, dynamic>> _grades = [
    {
      'value': 'saving',
      'label': '節約',
      'icon': Icons.savings_outlined,
      'color': AppColors.accentGreen,
      'lightColor': AppColors.accentGreenLight,
    },
    {
      'value': 'standard',
      'label': '標準',
      'icon': Icons.balance_outlined,
      'color': AppColors.accentBlue,
      'lightColor': AppColors.accentBlueLight,
    },
    {
      'value': 'reward',
      'label': 'ご褒美',
      'icon': Icons.star_outline,
      'color': AppColors.accentOrange,
      'lightColor': AppColors.accentOrangeLight,
    },
  ];

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  // 登録ボタンの有効化条件
  bool get _canSubmit => _selectedCategory != null && _expenseAmount > 0;

  // 選択中のグレードデータ
  Map<String, dynamic> get _selectedGradeData =>
      _grades.firstWhere((g) => g['value'] == _selectedGrade);

  // グレードに対応するデータを取得
  Map<String, dynamic> _getGradeData(String grade) {
    return _grades.firstWhere(
      (g) => g['value'] == grade,
      orElse: () => _grades[1], // fallback to standard
    );
  }

  /// カテゴリ選択時にスマート・コンボを取得
  Future<void> _loadSmartCombos(String category) async {
    setState(() {
      _isLoadingCombos = true;
    });

    final appState = context.read<AppState>();
    final combos = await appState.getSmartCombos(category);

    if (mounted) {
      setState(() {
        _smartCombos = combos;
        _isLoadingCombos = false;
      });
    }
  }

  /// コンボチップをタップ時に金額と支出タイプを自動入力
  void _applyCombo(Map<String, dynamic> combo) {
    setState(() {
      _expenseAmount = combo['amount'] as int;
      _selectedGrade = combo['grade'] as String;
      // 適切な単位を自動選択
      if (_expenseAmount >= 10000) {
        _expenseUnit = 10000;
      } else if (_expenseAmount >= 1000) {
        _expenseUnit = 1000;
      } else if (_expenseAmount >= 100) {
        _expenseUnit = 100;
      } else {
        _expenseUnit = 10;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            _buildHeader(),
            // メインコンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ① カテゴリ選択
                    _buildCategorySection(),
                    const SizedBox(height: 10),
                    // 固定費リンク（カテゴリ直下）
                    _buildFixedCostLink(),
                    const SizedBox(height: 16),
                    // スマート・コンボ予測（カテゴリ選択後に表示）
                    if (_selectedCategory != null) _buildSmartComboSection(),
                    if (_selectedCategory != null) const SizedBox(height: 20),
                    // ② 金額入力
                    _buildAmountSection(),
                    const SizedBox(height: 28),
                    // ③ 支出タイプ選択
                    _buildGradeSection(),
                    const SizedBox(height: 24),
                    // ④ メモ（任意）
                    _buildMemoSection(),
                  ],
                ),
              ),
            ),
            // ⑤ 登録ボタン（固定）
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  /// ヘッダー（タイトル）
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: Text(
          '支出を記録',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// ① カテゴリ選択セクション
  Widget _buildCategorySection() {
    final categories = context.watch<AppState>().categoryNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'カテゴリ',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => showAddCategoryModal(context),
              child: Text(
                '+ 新規追加',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // カテゴリチップグリッド
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
                // カテゴリ選択時にスマート・コンボを取得
                _loadSmartCombos(category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedGradeData['lightColor'] as Color
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? _selectedGradeData['color'] as Color
                        : Colors.black.withOpacity(0.06),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (_selectedGradeData['color'] as Color)
                                .withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? _selectedGradeData['color'] as Color
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// スマート・コンボ予測セクション
  Widget _buildSmartComboSection() {
    // ローディング中
    if (_isLoadingCombos) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // コンボが無い場合は非表示
    if (_smartCombos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Row(
          children: [
            const Icon(
              Icons.bolt,
              size: 16,
              color: AppColors.accentOrange,
            ),
            const SizedBox(width: 6),
            Text(
              'よく使う組み合わせ',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // コンボチップ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _smartCombos.map((combo) {
            final amount = combo['amount'] as int;
            final grade = combo['grade'] as String;
            final gradeData = _getGradeData(grade);
            final color = gradeData['color'] as Color;
            final lightColor = gradeData['lightColor'] as Color;
            final label = gradeData['label'] as String;

            return GestureDetector(
              onTap: () => _applyCombo(combo),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: lightColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¥${formatNumber(amount)}',
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
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// ② 金額入力セクション
  Widget _buildAmountSection() {
    return Column(
      children: [
        // 金額表示（中央に大きく）
        Center(
          child: Text(
            '¥${formatNumber(_expenseAmount)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _expenseAmount > 0
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 単位切替チップ
        _buildUnitSelector(),
        const SizedBox(height: 8),
        // ホイールピッカー
        WheelPicker(
          key: ValueKey('expense_${_expenseUnit}_$_expenseAmount'),
          unit: _expenseUnit,
          maxMultiplier: _expenseUnit >= 1000 ? 100 : 99,
          initialValue: _expenseAmount,
          highlightColor: AppColors.bgPrimary,
          onChanged: (value) {
            setState(() {
              _expenseAmount = value;
            });
          },
        ),
      ],
    );
  }

  /// 単位選択UI
  Widget _buildUnitSelector() {
    final units = [10, 100, 1000, 10000];
    final labels = ['10円', '100円', '1000円', '1万円'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(units.length, (index) {
          final unit = units[index];
          final isSelected = _expenseUnit == unit;
          return GestureDetector(
            onTap: () {
              setState(() {
                _expenseUnit = unit;
                _expenseAmount = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.bgPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labels[index],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// ③ 支出タイプ選択セクション
  Widget _buildGradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '支出タイプ',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // グレードチップ（横並び）
        Row(
          children: _grades.map((grade) {
            final isSelected = _selectedGrade == grade['value'];
            final color = grade['color'] as Color;
            final lightColor = grade['lightColor'] as Color;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGrade = grade['value'] as String;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                    right: grade['value'] != 'reward' ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? lightColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.black.withOpacity(0.06),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        grade['icon'] as IconData,
                        size: 22,
                        color: isSelected ? color : AppColors.textMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        grade['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? color : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // 補足テキスト
        Center(
          child: Text(
            '迷ったら直感でOK。あとから変更できます',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  /// ④ メモセクション
  Widget _buildMemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'メモ（任意）',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _memoController,
          decoration: InputDecoration(
            hintText: '例: スタバ 新作フラペチーノ',
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMuted.withOpacity(0.7),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _selectedGradeData['color'] as Color,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 固定費リンク
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 16,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
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
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// ⑤ 登録ボタン（固定）
  Widget _buildSubmitButton() {
    final gradeColor = _selectedGradeData['color'] as Color;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _canSubmit ? _recordExpense : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _canSubmit ? gradeColor : AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _canSubmit
                  ? [
                      BoxShadow(
                        color: gradeColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                _canSubmit
                    ? '¥${formatNumber(_expenseAmount)} を記録'
                    : '記録する',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _canSubmit ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 入力をリセット
  void _resetInput() {
    setState(() {
      _selectedCategory = null;
      _expenseAmount = 0;
      _expenseUnit = 100;
      _selectedGrade = 'standard';
      _smartCombos = [];
      _memoController.clear();
    });
  }

  /// 支出を記録
  Future<void> _recordExpense() async {
    if (!_canSubmit) return;

    final appState = context.read<AppState>();

    final expense = Expense(
      amount: _expenseAmount,
      category: _selectedCategory!,
      grade: _selectedGrade,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      createdAt: DateTime.now(),
    );

    final success = await appState.addExpense(expense);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '保存に失敗しました',
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

    final gradeColor = _selectedGradeData['color'] as Color;

    // 成功メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¥${formatNumber(expense.amount)} を記録しました',
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

    // 入力をリセット
    _resetInput();
  }
}
