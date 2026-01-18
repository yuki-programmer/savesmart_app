import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';

/// 今月の使える金額を入力するBottom Sheet
Future<void> showIncomeSheet(BuildContext context, DateTime month) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _IncomeSheetContent(month: month),
  );
}

class _IncomeSheetContent extends StatefulWidget {
  final DateTime month;

  const _IncomeSheetContent({required this.month});

  @override
  State<_IncomeSheetContent> createState() => _IncomeSheetContentState();
}

class _IncomeSheetContentState extends State<_IncomeSheetContent> {
  late TextEditingController _mainIncomeController;
  late TextEditingController _subIncomeController;
  late TextEditingController _subIncomeNameController;
  bool _isMainValid = false;
  bool _isSubValid = false;
  bool _isLoading = true;
  bool _showSubIncomeForm = false;

  // DB から取得したデータ
  Map<String, dynamic>? _mainIncome;
  List<Map<String, dynamic>> _subIncomes = [];

  @override
  void initState() {
    super.initState();
    _mainIncomeController = TextEditingController();
    _subIncomeController = TextEditingController();
    _subIncomeNameController = TextEditingController();
    _loadIncomeData();
  }

  @override
  void dispose() {
    _mainIncomeController.dispose();
    _subIncomeController.dispose();
    _subIncomeNameController.dispose();
    super.dispose();
  }

  Future<void> _loadIncomeData() async {
    final appState = context.read<AppState>();

    final mainIncome = await appState.getMainIncome();
    final subIncomes = await appState.getSubIncomes();

    setState(() {
      _mainIncome = mainIncome;
      _subIncomes = subIncomes;
      _isLoading = false;

      if (mainIncome != null) {
        _mainIncomeController.text = mainIncome['amount'].toString();
        _validateMainInput(_mainIncomeController.text);
      }
    });
  }

  void _validateMainInput(String value) {
    final parsed = int.tryParse(value);
    setState(() {
      _isMainValid = parsed != null && parsed > 0;
    });
  }

  void _validateSubInput(String value) {
    final parsed = int.tryParse(value);
    final hasName = _subIncomeNameController.text.trim().isNotEmpty;
    setState(() {
      _isSubValid = parsed != null && parsed > 0 && hasName;
    });
  }

  Future<void> _saveMainIncome() async {
    if (!_isMainValid) return;

    final amount = int.parse(_mainIncomeController.text);
    await context.read<AppState>().setMainIncome(amount);
    if (!mounted) return;
    await _loadIncomeData();
  }

  Future<void> _addSubIncome() async {
    if (!_isSubValid) return;

    final amount = int.parse(_subIncomeController.text);
    final name = _subIncomeNameController.text.trim();
    await context.read<AppState>().addSubIncome(amount, name);

    if (!mounted) return;

    // フォームをクリアして再読み込み
    _subIncomeController.clear();
    _subIncomeNameController.clear();
    setState(() {
      _showSubIncomeForm = false;
      _isSubValid = false;
    });
    await _loadIncomeData();
  }

  Future<void> _deleteIncome(int id) async {
    await context.read<AppState>().deleteIncome(id);
    if (!mounted) return;
    await _loadIncomeData();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final totalIncome = appState.thisMonthAvailableAmount ?? 0;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ドラッグハンドル
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // タイトル
                    Text(
                      '今サイクルの収入',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withOpacity(0.9),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // サイクル期間表示
                    Text(
                      '${appState.cycleStartDate.month}/${appState.cycleStartDate.day} 〜 ${appState.cycleEndDate.month}/${appState.cycleEndDate.day}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // メイン収入セクション
                    _buildMainIncomeSection(),
                    const SizedBox(height: 20),

                    // サブ収入セクション
                    _buildSubIncomeSection(),
                    const SizedBox(height: 24),

                    // 収入合計
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '収入合計',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            '¥${formatNumber(totalIncome)}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 閉じるボタン
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '閉じる',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMainIncomeSection() {
    final hasMainIncome = _mainIncome != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'メイン収入（給料）',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mainIncomeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: _validateMainInput,
                decoration: InputDecoration(
                  hintText: '例：250000',
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textMuted.withOpacity(0.5),
                    fontSize: 16,
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
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '円',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isMainValid ? _saveMainIncome : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isMainValid
                      ? AppColors.accentBlue
                      : AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasMainIncome ? '更新' : '保存',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isMainValid
                        ? Colors.white
                        : AppColors.textMuted.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubIncomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'サブ収入（補填・ボーナス等）',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.8),
              ),
            ),
            if (!_showSubIncomeForm)
              GestureDetector(
                onTap: () => setState(() => _showSubIncomeForm = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '追加',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 登録済みサブ収入リスト
        if (_subIncomes.isNotEmpty) ...[
          ..._subIncomes.map((sub) => _buildSubIncomeItem(sub)),
          const SizedBox(height: 10),
        ],

        // サブ収入追加フォーム
        if (_showSubIncomeForm) _buildSubIncomeForm(),

        // サブ収入がない場合のヒント
        if (_subIncomes.isEmpty && !_showSubIncomeForm)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'ボーナスや臨時収入があれば追加できます',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted.withOpacity(0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubIncomeItem(Map<String, dynamic> sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  sub['name'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${formatNumber(sub['amount'] as int)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGreen,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteIncome(sub['id'] as int),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubIncomeForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名前入力
          TextField(
            controller: _subIncomeNameController,
            onChanged: (_) => _validateSubInput(_subIncomeController.text),
            decoration: InputDecoration(
              hintText: '名目（例：ボーナス）',
              hintStyle: GoogleFonts.inter(
                color: AppColors.textMuted.withOpacity(0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // 金額入力
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subIncomeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: _validateSubInput,
                  decoration: InputDecoration(
                    hintText: '金額',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.textMuted.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '円',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ボタン
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _subIncomeController.clear();
                    _subIncomeNameController.clear();
                    setState(() {
                      _showSubIncomeForm = false;
                      _isSubValid = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _isSubValid ? _addSubIncome : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isSubValid
                          ? AppColors.accentGreen
                          : AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '追加',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isSubValid
                              ? Colors.white
                              : AppColors.textMuted.withOpacity(0.6),
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
}
