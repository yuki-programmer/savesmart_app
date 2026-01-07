import 'package:flutter/material.dart';
import '../config/theme.dart';

/// 予算消化ペースの折れ線グラフ（CustomPainter実装）
class BurnRateChart extends StatelessWidget {
  /// 日ごとの累積支出率（%）。index 0 = 1日目
  final List<double> dailyRates;

  /// 今日の日（1-indexed）
  final int todayDay;

  /// 当月の日数
  final int daysInMonth;

  const BurnRateChart({
    super.key,
    required this.dailyRates,
    required this.todayDay,
    required this.daysInMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: CustomPaint(
        size: Size.infinite,
        painter: _BurnRateChartPainter(
          dailyRates: dailyRates,
          todayDay: todayDay,
          daysInMonth: daysInMonth,
        ),
      ),
    );
  }
}

class _BurnRateChartPainter extends CustomPainter {
  final List<double> dailyRates;
  final int todayDay;
  final int daysInMonth;

  _BurnRateChartPainter({
    required this.dailyRates,
    required this.todayDay,
    required this.daysInMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyRates.isEmpty) return;

    // 描画領域の設定（ラベル用の余白を確保）
    const double leftPadding = 32;
    const double rightPadding = 8;
    const double topPadding = 8;
    const double bottomPadding = 20;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    const chartLeft = leftPadding;
    const chartTop = topPadding;
    final chartBottom = chartTop + chartHeight;

    // 最大値の決定（100%または実績最大+5%）
    final maxRate = dailyRates.isNotEmpty
        ? dailyRates.reduce((a, b) => a > b ? a : b)
        : 100.0;
    final yMax = maxRate > 100 ? (maxRate + 10).clamp(100.0, 200.0) : 100.0;

    // グリッドの描画
    _drawGrid(canvas, size, chartLeft, chartTop, chartWidth, chartHeight, yMax);

    // 軸ラベルの描画
    _drawAxisLabels(
        canvas, size, chartLeft, chartTop, chartWidth, chartHeight, chartBottom, yMax);

    // 折れ線の描画
    _drawLine(canvas, chartLeft, chartTop, chartWidth, chartHeight, yMax);

    // 今日のドットを描画
    _drawTodayDot(canvas, chartLeft, chartTop, chartWidth, chartHeight, yMax);
  }

  void _drawGrid(Canvas canvas, Size size, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.15)
      ..strokeWidth = 1;

    // 横線（0%, 50%, 100%）
    final yPositions = [0.0, 50.0, 100.0];
    for (final yValue in yPositions) {
      if (yValue > yMax) continue;
      final y = chartTop + chartHeight * (1 - yValue / yMax);
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartLeft + chartWidth, y),
        gridPaint,
      );
    }

    // 100%超えの場合、100%ラインを強調
    if (yMax > 100) {
      final y100 = chartTop + chartHeight * (1 - 100 / yMax);
      final warningPaint = Paint()
        ..color = AppColors.accentRed.withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(chartLeft, y100),
        Offset(chartLeft + chartWidth, y100),
        warningPaint,
      );
    }
  }

  void _drawAxisLabels(Canvas canvas, Size size, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double chartBottom, double yMax) {
    final textStyle = TextStyle(
      color: AppColors.textMuted.withOpacity(0.6),
      fontSize: 10,
    );

    // Y軸ラベル（0%, 50%, 100%）
    final yLabels = ['0%', '50%', '100%'];
    final yValues = [0.0, 50.0, 100.0];
    for (var i = 0; i < yLabels.length; i++) {
      if (yValues[i] > yMax) continue;
      final y = chartTop + chartHeight * (1 - yValues[i] / yMax);
      final textSpan = TextSpan(text: yLabels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // X軸ラベル（1日、中間日、末日）
    final xLabels = [1, (daysInMonth / 2).round(), daysInMonth];
    for (final day in xLabels) {
      final x = chartLeft + (day - 1) / (daysInMonth - 1) * chartWidth;
      final textSpan = TextSpan(text: '$day', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartBottom + 4),
      );
    }
  }

  void _drawLine(Canvas canvas, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    if (dailyRates.isEmpty) return;

    // 今日までのデータのみ描画
    final dataLength = todayDay.clamp(1, dailyRates.length);

    // 100%以下と100%超えで色分け
    final normalPaint = Paint()
      ..color = AppColors.accentBlue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final overPaint = Paint()
      ..color = AppColors.accentRed.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    Path? overPath;

    for (var i = 0; i < dataLength; i++) {
      final x = chartLeft + i / (daysInMonth - 1) * chartWidth;
      final rate = dailyRates[i].clamp(0.0, yMax);
      final y = chartTop + chartHeight * (1 - rate / yMax);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 100%を超えた瞬間から赤い線に切り替え
        if (dailyRates[i] > 100 && (i == 0 || dailyRates[i - 1] <= 100)) {
          // 100%超え開始点
          overPath = Path();
          overPath.moveTo(x, y);
        }

        if (overPath != null && dailyRates[i] > 100) {
          overPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(path, normalPaint);
    if (overPath != null) {
      canvas.drawPath(overPath, overPaint);
    }
  }

  void _drawTodayDot(Canvas canvas, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    if (todayDay < 1 || todayDay > dailyRates.length) return;

    final rate = dailyRates[todayDay - 1];
    final x = chartLeft + (todayDay - 1) / (daysInMonth - 1) * chartWidth;
    final y = chartTop + chartHeight * (1 - rate.clamp(0.0, yMax) / yMax);

    // ドットの色（100%超えなら赤系）
    final dotColor = rate > 100
        ? AppColors.accentRed.withOpacity(0.9)
        : AppColors.accentBlue;

    // 外側の円（白いアウトライン）
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), 6, outerPaint);

    // 内側の円
    final innerPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), 4, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _BurnRateChartPainter oldDelegate) {
    return oldDelegate.dailyRates != dailyRates ||
        oldDelegate.todayDay != todayDay ||
        oldDelegate.daysInMonth != daysInMonth;
  }
}
