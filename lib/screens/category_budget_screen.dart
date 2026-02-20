import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../models/category_budget.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/amount_text_field.dart';

/// カテゴリ予算管理画面（リスト編集モード）
class CategoryBudgetScreen extends StatefulWidget {
  const CategoryBudgetScreen({super.key});

  @override
  State<CategoryBudgetScreen> createState() => _CategoryBudgetScreenState();
}

class _CategoryBudgetScreenState extends State<CategoryBudgetScreen> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final budgets = appState.categoryBudgets;
    final currencyFormat = appState.currencyFormat;

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: context.appTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'カテゴリ予算',
          style: AppTextStyles.screenTitle(context),
        ),
        centerTitle: true,
        actions: [
          if (budgets.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              },
              child: Text(
                _isEditMode ? '完了' : '編集',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue,
                ),
              ),
            ),
        ],
      ),
      body: budgets.isEmpty
          ? _buildEmptyState()
          : _buildBudgetList(budgets, currencyFormat),
      bottomNavigationBar: _buildAddButton(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: context.appTheme.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'カテゴリ予算が設定されていません',
            style: AppTextStyles.sectionTitle(context),
          ),
          const SizedBox(height: 8),
          Text(
            '下のボタンから追加できます',
            style: AppTextStyles.sub(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList(List<CategoryBudget> budgets, String currencyFormat) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        return _buildBudgetItem(budget, currencyFormat);
      },
    );
  }

  Widget _buildBudgetItem(CategoryBudget budget, String currencyFormat) {
    final periodLabel = budget.isRecurring ? '毎月' : '今月のみ';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(
                  Icons.remove_circle,
                  color: AppColors.accentRed,
                ),
                onPressed: () => _confirmDelete(budget),
              )
            : null,
        title: Text(
          budget.categoryName,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.appTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          periodLabel,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: context.appTheme.textMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(budget.budgetAmount, currencyFormat),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTheme.textPrimary,
              ),
            ),
            if (!_isEditMode) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.appTheme.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
        onTap: _isEditMode
            ? null
            : () => _showEditScreen(budget),
      ),
    );
  }

  void _confirmDelete(CategoryBudget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '削除の確認',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '「${budget.categoryName}」の予算設定を削除しますか？',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(color: context.appTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final appState = context.read<AppState>();
              await appState.deleteCategoryBudget(budget.id!);
            },
            child: Text(
              '削除',
              style: GoogleFonts.inter(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditScreen(CategoryBudget budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBudgetEditScreen(editingBudget: budget),
      ),
    );
  }

  Widget _buildAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryBudgetEditScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 20),
                const SizedBox(width: 8),
                Text(
                  'カテゴリ予算を追加',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// カテゴリ予算 登録/編集画面
class CategoryBudgetEditScreen extends StatefulWidget {
  final CategoryBudget? editingBudget;

  const CategoryBudgetEditScreen({
    super.key,
    this.editingBudget,
  });

  @override
  State<CategoryBudgetEditScreen> createState() =>
      _CategoryBudgetEditScreenState();
}

class _CategoryBudgetEditScreenState extends State<CategoryBudgetEditScreen> {
  int? _selectedCategoryId;
  String? _selectedCategory;
  int _budgetAmount = 0;
  String _periodType = 'recurring'; // 'recurring' or 'one_time'

  bool get _isEditing => widget.editingBudget != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final budget = widget.editingBudget!;
      _selectedCategoryId = budget.categoryId;
      _selectedCategory = budget.categoryName;
      _budgetAmount = budget.budgetAmount;
      _periodType = budget.periodType;
    }
  }

  bool get _canSubmit =>
      _selectedCategoryId != null && _selectedCategory != null && _budgetAmount > 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currencyFormat = appState.currencyFormat;

    // 利用可能なカテゴリ（編集時は自分自身も含める）
    List<String> availableCategories;
    if (_isEditing) {
      // 編集時: 自分以外の設定済みカテゴリを除外
      final currentCategoryName = widget.editingBudget!.categoryName;
      final budgetedCategories = appState.budgetedCategoryNames
          .where((name) => name != currentCategoryName)
          .toList();
      availableCategories = appState.categoryNames
          .where((name) => !budgetedCategories.contains(name))
          .toList();
      // 現在のカテゴリが削除されている場合も含める
      if (!availableCategories.contains(currentCategoryName)) {
        availableCategories.insert(0, currentCategoryName);
      }
    } else {
      // 新規時: 設定済みカテゴリを除外
      availableCategories = appState.unbudgetedCategoryNames;
    }

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          color: context.appTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? '予算を編集' : '予算を追加',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カテゴリ選択
            _buildSectionTitle('カテゴリ'),
            const SizedBox(height: 10),
            _buildCategoryDropdown(availableCategories),
            const SizedBox(height: 24),

            // 予算金額
            _buildSectionTitle('予算金額'),
            const SizedBox(height: 10),
            _buildAmountPicker(currencyFormat),
            const SizedBox(height: 24),

            // 期間タイプ
            _buildSectionTitle('期間'),
            const SizedBox(height: 10),
            _buildPeriodSelector(),
          ],
        ),
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.appTheme.textSecondary,
      ),
    );
  }

  Widget _buildCategoryDropdown(List<String> categories) {
    // 選択中のカテゴリが利用可能リストにない場合はnullにする
    // （保存後のリビルド時に発生するエラーを防ぐ）
    final effectiveValue = (_selectedCategory != null &&
            categories.contains(_selectedCategory))
        ? _selectedCategory
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          hint: Text(
            'カテゴリを選択',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: context.appTheme.textMuted,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: context.appTheme.textMuted),
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.appTheme.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            final appState = context.read<AppState>();
            final category = appState.categories.firstWhere(
              (c) => c.name == value,
              orElse: () => appState.categories.first,
            );
            setState(() {
              _selectedCategoryId = category.id;
              _selectedCategory = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAmountPicker(String currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.borderSubtle),
      ),
      child: Column(
        children: [
          // 金額入力
          AmountTextField(
            initialValue: _budgetAmount,
            fontSize: 32,
            accentColor: AppColors.accentBlue,
            onChanged: (value) {
              setState(() {
                _budgetAmount = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'タップして金額を入力',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.appTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.borderSubtle),
      ),
      child: Column(
        children: [
          _buildPeriodOption(
            value: 'recurring',
            title: '毎月（固定）',
            subtitle: '次の月も継続して設定されます',
            isFirst: true,
          ),
          Divider(height: 1, color: context.appTheme.borderSubtle),
          _buildPeriodOption(
            value: 'one_time',
            title: '今月のみ',
            subtitle: '次のサイクルで自動的に削除されます',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOption({
    required String value,
    required String title,
    required String subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = _periodType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _periodType = value;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.accentBlue : context.appTheme.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.appTheme.borderSubtle,
              disabledForegroundColor: context.appTheme.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isEditing ? '保存' : '追加',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final appState = context.read<AppState>();

    final budget = CategoryBudget(
      id: widget.editingBudget?.id,
      categoryId: _selectedCategoryId!,
      categoryName: _selectedCategory!,
      budgetAmount: _budgetAmount,
      periodType: _periodType,
      createdAt: widget.editingBudget?.createdAt ?? DateTime.now(),
    );

    bool success;
    if (_isEditing) {
      success = await appState.updateCategoryBudget(budget);
    } else {
      success = await appState.addCategoryBudget(budget);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '保存に失敗しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }
}
