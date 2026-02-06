import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// 金額入力用のTextField
/// - OS標準の数字キーボードを使用
/// - 最大金額: 1000万円（10,000,000円）
class AmountTextField extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final Color? accentColor;
  final double fontSize;
  final bool autofocus;

  const AmountTextField({
    super.key,
    this.initialValue = 0,
    required this.onChanged,
    this.accentColor,
    this.fontSize = 48,
    this.autofocus = false,
  });

  @override
  State<AmountTextField> createState() => _AmountTextFieldState();
}

class _AmountTextFieldState extends State<AmountTextField> {
  late TextEditingController _controller;
  int _lastExternalValue = 0;

  static const int maxAmount = 10000000; // 1000万円

  @override
  void initState() {
    super.initState();
    _lastExternalValue = widget.initialValue;
    _controller = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toString() : '',
    );
  }

  @override
  void didUpdateWidget(AmountTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部から値が変更された場合のみ更新（コンボ選択、プリセットなど）
    // onChangedによる自己更新は無視する
    if (widget.initialValue != _lastExternalValue) {
      _lastExternalValue = widget.initialValue;
      final currentText = _controller.text;
      final currentValue = int.tryParse(currentText) ?? 0;
      if (currentValue != widget.initialValue) {
        _controller.text = widget.initialValue > 0 ? widget.initialValue.toString() : '';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.isEmpty) {
      widget.onChanged(0);
      return;
    }

    // 最大値チェック
    int parsed = int.tryParse(value) ?? 0;
    if (parsed > maxAmount) {
      parsed = maxAmount;
      _controller.text = parsed.toString();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }

    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppColors.accentBlue;

    return IntrinsicWidth(
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8), // 最大8桁（1000万）
        ],
        style: GoogleFonts.ibmPlexSans(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          color: context.appTheme.textPrimary,
        ),
        decoration: InputDecoration(
          prefixText: '¥',
          prefixStyle: GoogleFonts.ibmPlexSans(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: context.appTheme.textPrimary,
          ),
          hintText: '0',
          hintStyle: GoogleFonts.ibmPlexSans(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            color: context.appTheme.textMuted.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: color, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: _onChanged,
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
