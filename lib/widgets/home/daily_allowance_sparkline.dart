import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

/// 今日使えるお金のSparklineチャート（前日比リズム表示）
class DailyAllowanceSparkline extends StatefulWidget {
  final List<Map<String, dynamic>> historyData; // [{ 'date': DateTime, 'amount': int }, ...]
  final Color lineColor;
  final double height;
  final double strokeWidth;
  final String currencyFormat;

  const DailyAllowanceSparkline({
    super.key,
    required this.historyData,
    this.lineColor = AppColors.accentBlue,
    this.height = 40,
    this.strokeWidth = 1.5,
    this.currencyFormat = 'prefix',
  });

  @override
  State<DailyAllowanceSparkline> createState() => _DailyAllowanceSparklineState();
}

class _DailyAllowanceSparklineState extends State<DailyAllowanceSparkline> {
  int? _tappedIndex;
  Offset? _tapPosition;

  @override
  Widget build(BuildContext context) {
    // データが3点未満の場合は表示しない（6日取得、最低3日必要 = 2点表示可能）
    if (widget.historyData.length < 3) {
      return SizedBox(height: widget.height);
    }

    // 最後の5日分のみ表示（最初の1日は比較用）
    final displayData = widget.historyData.skip(1).toList();

    return GestureDetector(
      onTapDown: (details) {
        _handleTap(details.localPosition, displayData);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: widget.height,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: displayData,
                lineColor: widget.lineColor,
                strokeWidth: widget.strokeWidth,
                tappedIndex: _tappedIndex,
              ),
              size: Size.infinite,
            ),
          ),
          if (_tappedIndex != null && _tapPosition != null)
            _buildTooltip(context, displayData),
        ],
      ),
    );
  }

  void _handleTap(Offset position, List<Map<String, dynamic>> displayData) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final dataCount = displayData.length;

    // タップ位置から最も近いデータポイントを特定
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < dataCount; i++) {
      final x = (i / (dataCount - 1)) * width;
      final distance = (position.dx - x).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // タップ範囲内（20px以内）ならツールチップ表示
    if (minDistance < 20) {
      setState(() {
        _tappedIndex = closestIndex;
        _tapPosition = position;
      });
      // 3秒後に自動的に非表示
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _tappedIndex == closestIndex) {
          setState(() {
            _tappedIndex = null;
            _tapPosition = null;
          });
        }
      });
    }
  }

  Widget _buildTooltip(BuildContext context, List<Map<String, dynamic>> displayData) {
    if (_tappedIndex == null || _tappedIndex! >= displayData.length) {
      return const SizedBox.shrink();
    }

    final data = displayData[_tappedIndex!];
    final date = data['date'] as DateTime;
    final amount = data['amount'] as int;
    final isToday = _tappedIndex == displayData.length - 1;

    String message;
    Color bgColor;

    // displayDataのindex 0は、historyDataのindex 1（2日目）
    // 比較には historyData[0]（1日目）を使う
    final originalIndex = _tappedIndex! + 1;
    final prevAmount = widget.historyData[originalIndex - 1]['amount'] as int;
    final diff = amount - prevAmount;

    if (diff > 0) {
      // 控えめの日
      message = '昨日より +${formatCurrency(diff, widget.currencyFormat)}';
      bgColor = AppColors.accentGreen;
    } else if (diff < 0) {
      // 使った日
      message = '今日は -${formatCurrency(diff.abs(), widget.currencyFormat)} 使った';
      bgColor = AppColors.accentRed;
    } else {
      // 変化なし
      message = '昨日と同じ';
      bgColor = Colors.grey.shade600;
    }

    return Positioned(
      left: _tapPosition!.dx - 60,
      top: -50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDateLabel(date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatCurrency(amount, widget.currencyFormat),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}/${date.day}($weekday)';
  }
}

class _SparklinePainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color lineColor;
  final double strokeWidth;
  final int? tappedIndex;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.strokeWidth,
    this.tappedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    // データから最小値・最大値を取得
    final amounts = data.map((d) => d['amount'] as int).toList();
    final minAmount = amounts.reduce((a, b) => a < b ? a : b).toDouble();
    final maxAmount = amounts.reduce((a, b) => a > b ? a : b).toDouble();

    // Y軸に余白を持たせる（10%）
    final range = maxAmount - minAmount;
    final paddedMin = minAmount - range * 0.1;
    final paddedMax = maxAmount + range * 0.1;
    final paddedRange = paddedMax - paddedMin;

    // 全て同じ値の場合（フラットライン）は中央に描画
    final isFlat = paddedRange == 0;

    // 各点の座標を計算
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final amount = (data[i]['amount'] as int).toDouble();
      final x = (i / (data.length - 1)) * size.width;
      final y = isFlat
          ? size.height / 2
          : size.height - ((amount - paddedMin) / paddedRange) * size.height;
      points.add(Offset(x, y));
    }

    // 線分ごとに前日比で色分けして描画
    for (int i = 0; i < data.length - 1; i++) {
      final currentAmount = data[i]['amount'] as int;
      final nextAmount = data[i + 1]['amount'] as int;
      final diff = nextAmount - currentAmount;

      Color segmentColor;
      if (diff > 0) {
        // 前日比プラス（控えめ）→ 緑
        segmentColor = AppColors.accentGreen;
      } else if (diff < 0) {
        // 前日比マイナス（使った）→ 赤
        segmentColor = AppColors.accentRed;
      } else {
        // 変化なし → グレー
        segmentColor = Colors.grey.shade400;
      }

      final segmentPaint = Paint()
        ..color = segmentColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(points[i], points[i + 1], segmentPaint);
    }

    // 各点にドット表示
    for (int i = 0; i < data.length; i++) {
      final isToday = i == data.length - 1;
      final isTapped = i == tappedIndex;

      // 今日の点は大きく（1.3倍）、白縁をつける
      if (isToday) {
        // 白縁
        final outerDotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 5, outerDotPaint);

        // 内側の点
        final innerDotPaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], 3.5, innerDotPaint);
      } else {
        // 通常の点
        final dotPaint = Paint()
          ..color = isTapped ? lineColor : lineColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i], isTapped ? 3.5 : 2.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return data != oldDelegate.data ||
        lineColor != oldDelegate.lineColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        tappedIndex != oldDelegate.tappedIndex;
  }
}
