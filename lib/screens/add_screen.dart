import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/category_icons.dart';
import '../utils/formatters.dart';
import '../widgets/amount_text_field.dart';
import '../widgets/expense/add_breakdown_modal.dart';
import '../widgets/income_sheet.dart';
import '../services/app_state.dart';
import '../services/performance_service.dart';
import '../models/expense.dart';
import 'fixed_cost_screen.dart';
import 'category_manage_screen.dart';
import 'add_scheduled_expense_screen.dart';
import 'premium_screen.dart';

/// 支出記録画面（1ページ完結型）
/// 入力順: カテゴリ → 金額 → 支出タイプ
class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> with ScreenTraceMixin {
  @override
  String get screenTraceName => 'Add';

  // 入力状態
  int? _selectedCategoryId;
  String? _selectedCategory;
  int _expenseAmount = 0;
  late String _selectedGrade; // 設定から初期化
  final TextEditingController _memoController = TextEditingController();
  bool _isInitialized = false;

  // 支出日（デフォルトは今日）
  DateTime _expenseDate = DateTime.now();

  // 内訳リスト
  List<Map<String, dynamic>> _breakdowns = [];

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
  bool get _canSubmit => _selectedCategoryId != null && _selectedCategory != null && _expenseAmount > 0;

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
  Future<void> _loadSmartCombos(int categoryId) async {
    setState(() {
      _isLoadingCombos = true;
    });

    final appState = context.read<AppState>();
    final combos = await appState.getSmartCombos(categoryId);

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
    });
  }

  /// 支出日を選択
  Future<void> _selectExpenseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      locale: const Locale('ja'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  /// 支出日をフォーマット
  String _formatExpenseDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return '今日';

    final yesterday = today.subtract(const Duration(days: 1));
    if (target == yesterday) return '昨日';

    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}/${date.day}（$weekday）';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final appState = context.read<AppState>();
      _selectedGrade = appState.defaultExpenseGrade;
      _isInitialized = true;
    }
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
                    // 予定支出登録ボタン（Premium機能）
                    _buildScheduledExpenseButton(),
                    const SizedBox(height: 10),
                    // 収入・固定費ボタン（横並び）
                    _buildIncomeAndFixedCostRow(),
                    const SizedBox(height: 16),
                    // ① カテゴリ選択
                    _buildCategorySection(),
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
                    const SizedBox(height: 24),
                    // ⑤ 支出日（デフォルト今日）
                    _buildDateSelector(),
                    const SizedBox(height: 24),
                    // ⑥ 内訳（任意）
                    _buildBreakdownSection(),
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

  /// 予定支出登録ボタン（Premium機能）
  Widget _buildScheduledExpenseButton() {
    final isPremium = context.watch<AppState>().isPremium;

    return GestureDetector(
      onTap: () {
        if (isPremium) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddScheduledExpenseScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PremiumScreen(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isPremium
              ? AppColors.accentBlue.withValues(alpha: 0.08)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPremium
                ? AppColors.accentBlue.withValues(alpha: 0.2)
                : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 20,
              color: isPremium ? AppColors.accentBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '将来の支出を登録',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPremium ? AppColors.accentBlue : AppColors.textSecondary,
                ),
              ),
            ),
            if (!isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Plus',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isPremium ? AppColors.accentBlue : AppColors.textMuted,
            ),
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
    final categories = context.watch<AppState>().categories;

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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryManageScreen(),
                  ),
                );
              },
              child: Text(
                '編集',
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
            final isSelected = _selectedCategory == category.name;
            final icon = CategoryIcons.getIcon(category.icon);
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryId = category.id;
                  _selectedCategory = category.name;
                });
                // カテゴリ選択時にスマート・コンボを取得
                if (category.id != null) {
                  _loadSmartCombos(category.id!);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedGradeData['lightColor'] as Color
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? _selectedGradeData['color'] as Color
                        : Colors.black.withValues(alpha: 0.06),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (_selectedGradeData['color'] as Color)
                                .withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? _selectedGradeData['color'] as Color
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? _selectedGradeData['color'] as Color
                            : AppColors.textSecondary,
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
                  color: lightColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
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
                        color: color.withValues(alpha: 0.15),
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
        // 金額入力（タップでキーボード表示）
        Center(
          child: AmountTextField(
            initialValue: _expenseAmount,
            accentColor: _selectedGradeData['color'] as Color,
            onChanged: (value) {
              setState(() {
                _expenseAmount = value;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        // 入力ヒント
        Text(
          'タップして金額を入力',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
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
                      color: isSelected ? color : Colors.black.withValues(alpha: 0.06),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
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
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
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

  /// ⑤ 支出日セクション
  Widget _buildDateSelector() {
    final isToday = _formatExpenseDate(_expenseDate) == '今日';

    return GestureDetector(
      onTap: _selectExpenseDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? Colors.black.withValues(alpha: 0.06)
                : AppColors.accentBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // カレンダーアイコン
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.bgPrimary
                    : AppColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: isToday ? AppColors.textSecondary : AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            // ラベルと日付
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '支出日',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatExpenseDate(_expenseDate),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isToday ? AppColors.textPrimary : AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
            // 矢印
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// ⑥ 内訳セクション
  Widget _buildBreakdownSection() {
    final remainingAmount = _expenseAmount - _breakdownsTotal;
    final hasOverflow = remainingAmount < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '内訳（任意）',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            // 追加ボタン（残り金額がある場合のみ有効）
            GestureDetector(
              onTap: remainingAmount > 0 ? _showAddBreakdownModal : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: remainingAmount > 0
                      ? AppColors.accentBlueLight.withValues(alpha: 0.5)
                      : AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 16,
                      color: remainingAmount > 0
                          ? AppColors.accentBlue
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '追加',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: remainingAmount > 0
                            ? AppColors.accentBlue
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 説明テキスト（金額未入力 or 内訳なし）
        if (_expenseAmount == 0)
          Text(
            '先に金額を入力してください',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          )
        else if (_breakdowns.isEmpty)
          Text(
            '¥${formatNumber(_expenseAmount)}の内訳を追加できます',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        // 内訳リスト
        if (_breakdowns.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._breakdowns.asMap().entries.map((entry) {
            final index = entry.key;
            final breakdown = entry.value;
            final gradeData = _getGradeData(breakdown['type'] as String);
            final color = gradeData['color'] as Color;
            final lightColor = gradeData['lightColor'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: lightColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 金額
                  Text(
                    '¥${formatNumber(breakdown['amount'] as int)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // カテゴリ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      breakdown['category'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 支出タイプ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      gradeData['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 削除ボタン
                  GestureDetector(
                    onTap: () => _removeBreakdown(index),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }),
          // 残り（メインカテゴリ分）
          if (remainingAmount > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _selectedGradeData['lightColor'] as Color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_selectedGradeData['color'] as Color).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '¥${formatNumber(remainingAmount)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCategory ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(残り)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // エラー表示（オーバーフロー）
          if (hasOverflow)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.accentRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '内訳の合計が支出額を超えています',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.accentRed,
                    ),
                  ),
                ],
              ),
            ),
          // 合計表示
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.borderSubtle.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '合計',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '¥${formatNumber(_expenseAmount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 内訳合計
  int get _breakdownsTotal =>
      _breakdowns.fold(0, (sum, b) => sum + (b['amount'] as int));

  /// 内訳追加モーダルを表示
  void _showAddBreakdownModal() {
    final categories = context.read<AppState>().categories;
    showAddBreakdownModal(
      context: context,
      availableCategories: categories,
      onAdd: (breakdown) {
        setState(() {
          _breakdowns.add(breakdown);
        });
      },
    );
  }

  /// 内訳を削除
  void _removeBreakdown(int index) {
    setState(() {
      _breakdowns.removeAt(index);
    });
  }

  /// 収入・固定費ボタン（横並び）
  Widget _buildIncomeAndFixedCostRow() {
    final appState = context.watch<AppState>();
    final income = appState.thisMonthAvailableAmount;

    return Row(
      children: [
        // 収入ボタン
        Expanded(
          child: GestureDetector(
            onTap: () => showIncomeSheet(context, DateTime.now()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '収入',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          income != null
                              ? '¥${formatNumber(income)}'
                              : '未設定',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: income != null
                                ? AppColors.accentBlue
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 固定費ボタン
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FixedCostScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '固定費を登録',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
            color: Colors.black.withValues(alpha: 0.04),
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
              color: _canSubmit ? gradeColor : AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
              boxShadow: _canSubmit
                  ? [
                      BoxShadow(
                        color: gradeColor.withValues(alpha: 0.3),
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
    final appState = context.read<AppState>();
    setState(() {
      _selectedCategoryId = null;
      _selectedCategory = null;
      _expenseAmount = 0;
      _selectedGrade = appState.defaultExpenseGrade;
      _smartCombos = [];
      _breakdowns = [];
      _memoController.clear();
      _expenseDate = DateTime.now();
    });
  }

  /// 支出を記録
  Future<void> _recordExpense() async {
    if (!_canSubmit) return;

    final appState = context.read<AppState>();
    final now = DateTime.now();
    // 選択した日付に現在の時刻を組み合わせる
    final expenseDateTime = DateTime(
      _expenseDate.year,
      _expenseDate.month,
      _expenseDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    bool success;
    int savedCount = 0;

    if (_breakdowns.isEmpty) {
      // 内訳がない場合は通常の登録
      final expense = Expense(
        amount: _expenseAmount,
        categoryId: _selectedCategoryId!,
        category: _selectedCategory!,
        grade: _selectedGrade,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        createdAt: expenseDateTime,
      );
      success = await appState.addExpense(expense);
      savedCount = 1;
    } else {
      // 内訳がある場合：親は保存せず、内訳のみ独立した支出として保存
      // 合計金額は_expenseAmountのまま（内訳の合計 + 残り = _expenseAmount）
      try {
        // 内訳を個別の支出として保存
        for (final breakdown in _breakdowns) {
          final breakdownExpense = Expense(
            amount: breakdown['amount'] as int,
            categoryId: breakdown['categoryId'] as int,
            category: breakdown['category'] as String,
            grade: breakdown['type'] as String? ?? _selectedGrade,
            createdAt: expenseDateTime,
          );
          await appState.addExpense(breakdownExpense);
          savedCount++;
        }

        // 残り金額があればメインカテゴリで保存
        final remainingAmount = _expenseAmount - _breakdownsTotal;
        if (remainingAmount > 0) {
          final remainingExpense = Expense(
            amount: remainingAmount,
            categoryId: _selectedCategoryId!,
            category: _selectedCategory!,
            grade: _selectedGrade,
            memo: _memoController.text.isEmpty ? null : _memoController.text,
            createdAt: expenseDateTime,
          );
          await appState.addExpense(remainingExpense);
          savedCount++;
        }

        success = true;
      } catch (e) {
        success = false;
      }
    }

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
          _breakdowns.isEmpty
              ? '¥${formatNumber(_expenseAmount)} を記録しました'
              : '¥${formatNumber(_expenseAmount)} を記録しました（$savedCount件に分割）',
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
