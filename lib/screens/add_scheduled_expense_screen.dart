import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/category_icons.dart';
import '../utils/formatters.dart';
import '../widgets/amount_text_field.dart';
import '../services/app_state.dart';
import '../models/scheduled_expense.dart';

/// 予定支出登録画面（Premium機能）
class AddScheduledExpenseScreen extends StatefulWidget {
  /// 編集モードの場合、既存の予定支出を渡す
  final ScheduledExpense? editingExpense;

  /// 確認モード（過去日の予定支出を確認・修正して実績に変換）
  final bool isConfirmationMode;

  const AddScheduledExpenseScreen({
    super.key,
    this.editingExpense,
    this.isConfirmationMode = false,
  });

  @override
  State<AddScheduledExpenseScreen> createState() =>
      _AddScheduledExpenseScreenState();
}

class _AddScheduledExpenseScreenState extends State<AddScheduledExpenseScreen> {
  // 入力状態
  int? _selectedCategoryId;
  String? _selectedCategory;
  int _expenseAmount = 0;
  late String _selectedGrade;
  final TextEditingController _memoController = TextEditingController();
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  bool _isInitialized = false;

  bool get _isEditing => widget.editingExpense != null;
  bool get _isConfirmation => widget.isConfirmationMode;

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
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.editingExpense!;
      _selectedCategoryId = e.categoryId;
      _selectedCategory = e.category;
      _expenseAmount = e.amount;
      _selectedGrade = e.grade;
      _memoController.text = e.memo ?? '';
      _scheduledDate = e.scheduledDate;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && !_isEditing) {
      final appState = context.read<AppState>();
      _selectedGrade = appState.defaultExpenseGrade;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _selectedCategoryId != null && _selectedCategory != null && _expenseAmount > 0;

  Map<String, dynamic> get _selectedGradeData =>
      _grades.firstWhere((g) => g['value'] == _selectedGrade);

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    final appState = context.read<AppState>();

    bool success;

    if (_isConfirmation) {
      // 確認モード: 修正して実績に変換
      success = await appState.confirmScheduledExpenseWithModification(
        widget.editingExpense!,
        newAmount: _expenseAmount,
        newCategoryId: _selectedCategoryId,
        newCategory: _selectedCategory,
        newGrade: _selectedGrade,
        newMemo: _memoController.text.isNotEmpty ? _memoController.text : null,
      );
    } else {
      final scheduledExpense = ScheduledExpense(
        id: _isEditing ? widget.editingExpense!.id : null,
        amount: _expenseAmount,
        categoryId: _selectedCategoryId!,
        category: _selectedCategory!,
        grade: _selectedGrade,
        memo: _memoController.text.isNotEmpty ? _memoController.text : null,
        scheduledDate: _scheduledDate,
        createdAt: _isEditing ? widget.editingExpense!.createdAt : DateTime.now(),
      );

      if (_isEditing) {
        success = await appState.updateScheduledExpense(scheduledExpense);
      } else {
        success = await appState.addScheduledExpense(scheduledExpense);
      }
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      final errorMessage = _isConfirmation
          ? '確認に失敗しました'
          : (_isEditing ? '更新に失敗しました' : '登録に失敗しました');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}/${date.day}（$weekday）';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.categories;
    final currencyFormat = appState.currencyFormat;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isConfirmation
              ? '予定支出を確認'
              : (_isEditing ? '予定支出を編集' : '予定支出を登録'),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // 予定日選択
                    _buildDateSelector(),

                    const SizedBox(height: 24),

                    // カテゴリ選択
                    _buildSectionTitle('カテゴリ'),
                    const SizedBox(height: 12),
                    _buildCategoryGrid(categories),

                    const SizedBox(height: 24),

                    // 金額入力
                    _buildSectionTitle('金額'),
                    const SizedBox(height: 12),
                    _buildAmountInput(currencyFormat),

                    const SizedBox(height: 24),

                    // グレード選択
                    _buildSectionTitle('支出タイプ'),
                    const SizedBox(height: 12),
                    _buildGradeSelector(),

                    const SizedBox(height: 24),

                    // メモ入力
                    _buildSectionTitle('メモ（任意）'),
                    const SizedBox(height: 12),
                    _buildMemoInput(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // 登録ボタン
            _buildSubmitButton(currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildDateSelector() {
    // 確認モードでは日付変更不可（読み取り専用で表示）
    final isReadOnly = _isConfirmation;

    return GestureDetector(
      onTap: isReadOnly ? null : _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isReadOnly
              ? AppColors.textMuted.withValues(alpha: 0.08)
              : AppColors.accentBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isReadOnly
                ? AppColors.textMuted.withValues(alpha: 0.2)
                : AppColors.accentBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isReadOnly
                    ? AppColors.textMuted.withValues(alpha: 0.15)
                    : AppColors.accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 22,
                color: isReadOnly ? AppColors.textMuted : AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '予定日',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(_scheduledDate),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isReadOnly
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (!isReadOnly)
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategory == category.name;
        final icon = CategoryIcons.getIcon(category.icon);

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryId = category.id;
              _selectedCategory = category.name;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (_selectedGradeData['lightColor'] as Color)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? (_selectedGradeData['color'] as Color)
                    : AppColors.borderSubtle,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? (_selectedGradeData['color'] as Color)
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  category.name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (_selectedGradeData['color'] as Color)
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountInput(String currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // 金額入力
          AmountTextField(
            initialValue: _expenseAmount,
            fontSize: 32,
            accentColor: _selectedGradeData['color'] as Color,
            onChanged: (value) {
              setState(() {
                _expenseAmount = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'タップして金額を入力',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSelector() {
    return Row(
      children: _grades.map((grade) {
        final isSelected = _selectedGrade == grade['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: grade != _grades.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGrade = grade['value'];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      isSelected ? grade['lightColor'] as Color : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? grade['color'] as Color
                        : AppColors.borderSubtle,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      grade['icon'] as IconData,
                      size: 24,
                      color: isSelected
                          ? grade['color'] as Color
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      grade['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? grade['color'] as Color
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMemoInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: TextField(
        controller: _memoController,
        maxLines: 2,
        decoration: InputDecoration(
          hintText: '例：飲み会、旅行代など',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
          contentPadding: const EdgeInsets.all(14),
          border: InputBorder.none,
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _canSubmit ? _handleSubmit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _canSubmit
                  ? (_selectedGradeData['color'] as Color)
                  : AppColors.textMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_note,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConfirmation
                      ? '${formatCurrency(_expenseAmount, currencyFormat)} を確認'
                      : (_isEditing
                          ? '予定を更新'
                          : '${formatCurrency(_expenseAmount, currencyFormat)} を予定に追加'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
