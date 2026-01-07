import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/app_state.dart';

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
  late TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final currentAmount = appState.getMonthlyAvailableAmount(widget.month);
    _controller = TextEditingController(
      text: currentAmount != null ? currentAmount.toString() : '',
    );
    _validateInput(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput(String value) {
    final parsed = int.tryParse(value);
    setState(() {
      _isValid = parsed != null && parsed > 0;
    });
  }

  Future<void> _save() async {
    if (!_isValid) return;

    final amount = int.parse(_controller.text);
    await context.read<AppState>().setMonthlyAvailableAmount(widget.month, amount);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    await context.read<AppState>().setMonthlyAvailableAmount(widget.month, null);
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentAmount = appState.getMonthlyAvailableAmount(widget.month);
    final hasCurrentValue = currentAmount != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Padding(
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
                '今月の使える金額',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withOpacity(0.9),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // サブテキスト
              Text(
                '貯金・固定費も含めて、今月手元に入る金額の合計',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // 入力フィールド
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: _validateInput,
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
                  const SizedBox(width: 12),
                  Text(
                    '円',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // 現在の設定値表示
              if (hasCurrentValue) ...[
                const SizedBox(height: 12),
                Text(
                  '現在の設定: ¥${_formatNumber(currentAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ボタン
              Row(
                children: [
                  // クリアボタン（設定済みの場合のみ表示）
                  if (hasCurrentValue)
                    Expanded(
                      child: GestureDetector(
                        onTap: _clear,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'クリア',
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
                  if (hasCurrentValue) const SizedBox(width: 12),

                  // 保存ボタン
                  Expanded(
                    child: GestureDetector(
                      onTap: _isValid ? _save : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isValid
                              ? AppColors.accentBlue
                              : AppColors.textMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '保存',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isValid
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
        ),
      ),
    );
  }
}
