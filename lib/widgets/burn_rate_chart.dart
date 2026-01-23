import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// 比較線のタイプ
enum ComparisonLineType {
  ideal,    // 理想線（初月または前月データ不足時）
  previous, // 前月線
}

/// 予算消化ペースの折れ線グラフ（CustomPainter実装）
class BurnRateChart extends StatelessWidget {
  /// 日ごとの累積支出率（%）。index 0 = 1日目
  final List<double> dailyRates;

  /// 今日の日（1-indexed）
  final int todayDay;

  /// 当月の日数
  final int daysInMonth;

  /// 今月の記録開始日（1-indexed）。この日より前は線を描画しない
  final int startDay;

  /// サイクル開始日（X軸ラベル表示用）。null = カレンダー月（1日開始）
  final DateTime? cycleStartDate;

  /// 前月の日ごとの累積支出率（%）。null = 前月データなし
  final List<double>? previousMonthRates;

  /// 前月の日数
  final int? previousMonthDays;

  /// 前月の記録開始日（1-indexed）。null = 1日から開始
  final int? previousMonthStartDay;

  const BurnRateChart({
    super.key,
    required this.dailyRates,
    required this.todayDay,
    required this.daysInMonth,
    this.startDay = 1,
    this.cycleStartDate,
    this.previousMonthRates,
    this.previousMonthDays,
    this.previousMonthStartDay,
  });

  /// 前月データが有効かどうか（記録日数>=3）
  bool get _hasSufficientPreviousData {
    if (previousMonthRates == null || previousMonthDays == null) return false;
    if (previousMonthRates!.isEmpty) return false;

    // 記録開始日を考慮して、実際に記録がある日数をカウント
    final prevStartDay = previousMonthStartDay ?? 1;
    int recordedDays = 0;
    double lastRate = 0;
    for (int i = prevStartDay - 1; i < previousMonthRates!.length; i++) {
      if (previousMonthRates![i] > lastRate) {
        recordedDays++;
        lastRate = previousMonthRates![i];
      }
    }

    return recordedDays >= 3;
  }

  /// 比較線のタイプを決定
  ComparisonLineType get _comparisonLineType {
    return _hasSufficientPreviousData
        ? ComparisonLineType.previous
        : ComparisonLineType.ideal;
  }

  /// 理想線データを生成（月全体に表示）
  List<double> _generateIdealLine() {
    // 理想線: d=1で0%, d=Dで100%の直線
    return List.generate(daysInMonth, (i) {
      return (i / (daysInMonth - 1)) * 100;
    });
  }

  /// 前月比較線データを生成（当月日数に補間、前月の開始日も考慮）
  /// 返り値: (rates, startDay) - startDayは前月補間後の開始日
  (List<double?>, int) _generatePreviousMonthLine() {
    final prevRates = previousMonthRates!;
    final prevDays = previousMonthDays!;
    final prevStartDay = previousMonthStartDay ?? 1;

    final result = <double?>[];

    for (int d = 1; d <= daysInMonth; d++) {
      // t = (d - 1)/(D_curr - 1) * (D_prev - 1) + 1
      final t = (d - 1) / (daysInMonth - 1) * (prevDays - 1) + 1;

      // 補間元の日が前月の開始日より前の場合はnull（ギャップ）
      if (t < prevStartDay) {
        result.add(null);
        continue;
      }

      final floorT = t.floor().clamp(1, prevDays);
      final ceilT = t.ceil().clamp(1, prevDays);
      final fraction = t - t.floor();

      // 0-indexed に変換
      final y1 = prevRates[floorT - 1];
      final y2 = prevRates[ceilT - 1];

      // 線形補間: lerp(y1, y2, fraction)
      final interpolated = y1 + (y2 - y1) * fraction;
      result.add(interpolated.clamp(0, 100));
    }

    // 補間後の開始日を計算
    int interpolatedStartDay = 1;
    for (int i = 0; i < result.length; i++) {
      if (result[i] != null) {
        interpolatedStartDay = i + 1;
        break;
      }
    }

    return (result, interpolatedStartDay);
  }

  @override
  Widget build(BuildContext context) {
    final comparisonType = _comparisonLineType;

    // 比較線データを生成
    List<double?> comparisonRates;
    int comparisonStartDay;

    if (comparisonType == ComparisonLineType.ideal) {
      // 理想線は月全体に表示
      comparisonRates = _generateIdealLine().map((e) => e as double?).toList();
      comparisonStartDay = 1;
    } else {
      // 前月線は前月の開始日を考慮
      final (rates, startDayResult) = _generatePreviousMonthLine();
      comparisonRates = rates;
      comparisonStartDay = startDayResult;
    }

    return Column(
      children: [
        // 凡例
        _buildLegend(comparisonType),
        const SizedBox(height: 8),
        // グラフ
        Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: CustomPaint(
            size: Size.infinite,
            painter: _BurnRateChartPainter(
              dailyRates: dailyRates,
              todayDay: todayDay,
              daysInMonth: daysInMonth,
              startDay: startDay,
              cycleStartDate: cycleStartDate,
              comparisonRates: comparisonRates,
              comparisonStartDay: comparisonStartDay,
              comparisonType: comparisonType,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(ComparisonLineType type) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 今サイクル
        _buildLegendItem(
          color: AppColors.accentBlue,
          label: '今サイクル',
          isDashed: false,
        ),
        const SizedBox(width: 16),
        // 比較線
        _buildLegendItem(
          color: AppColors.textMuted.withValues(alpha: 0.5),
          label: type == ComparisonLineType.previous ? '前サイクル' : '理想',
          isDashed: true,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 線のサンプル
        SizedBox(
          width: 16,
          height: 2,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              isDashed: isDashed,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 凡例の線を描画するPainter
class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;

  _LegendLinePainter({
    required this.color,
    required this.isDashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (isDashed) {
      _drawDashedLine(
        canvas,
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 2.0;
    final distance = (p2 - p1).distance;
    final dx = (p2.dx - p1.dx) / distance;
    final dy = (p2.dy - p1.dy) / distance;

    var currentX = p1.dx;
    var currentY = p1.dy;
    var drawn = 0.0;

    while (drawn < distance) {
      final nextDrawn = (drawn + dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        Offset(currentX, currentY),
        Offset(p1.dx + dx * nextDrawn, p1.dy + dy * nextDrawn),
        paint,
      );
      drawn = nextDrawn + dashSpace;
      currentX = p1.dx + dx * drawn;
      currentY = p1.dy + dy * drawn;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDashed != isDashed;
  }
}

class _BurnRateChartPainter extends CustomPainter {
  final List<double> dailyRates;
  final int todayDay;
  final int daysInMonth;
  final int startDay;
  final DateTime? cycleStartDate;
  final List<double?> comparisonRates;
  final int comparisonStartDay;
  final ComparisonLineType comparisonType;

  _BurnRateChartPainter({
    required this.dailyRates,
    required this.todayDay,
    required this.daysInMonth,
    required this.startDay,
    this.cycleStartDate,
    required this.comparisonRates,
    required this.comparisonStartDay,
    required this.comparisonType,
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

    // 比較線の描画（今月線より先に描画して背面に）
    _drawComparisonLine(canvas, chartLeft, chartTop, chartWidth, chartHeight, yMax);

    // 今月の折れ線の描画
    _drawLine(canvas, chartLeft, chartTop, chartWidth, chartHeight, yMax);

    // 今日のドットを描画
    _drawTodayDot(canvas, chartLeft, chartTop, chartWidth, chartHeight, yMax);
  }

  void _drawGrid(Canvas canvas, Size size, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.15)
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
        ..color = AppColors.accentRed.withValues(alpha: 0.3)
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
      color: AppColors.textMuted.withValues(alpha: 0.6),
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

    // X軸ラベル（開始日、中間日、終了日）
    // サイクル開始日が設定されている場合は、実際のカレンダー日付を表示
    final cycleDayPositions = [1, (daysInMonth / 2).round(), daysInMonth];
    for (final cycleDay in cycleDayPositions) {
      final x = chartLeft + (cycleDay - 1) / (daysInMonth - 1) * chartWidth;

      // ラベルテキストを決定
      String labelText;
      if (cycleStartDate != null) {
        // サイクル開始日からcycleDay-1日後の日付を計算
        final labelDate = cycleStartDate!.add(Duration(days: cycleDay - 1));
        labelText = '${labelDate.day}';
      } else {
        // カレンダー月モード（従来どおり）
        labelText = '$cycleDay';
      }

      final textSpan = TextSpan(text: labelText, style: textStyle);
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

  /// 比較線を描画（点線）
  void _drawComparisonLine(Canvas canvas, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    if (comparisonRates.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 連続したセグメントごとにPathを作成（nullでギャップ）
    Path? currentPath;
    final paths = <Path>[];

    for (var i = 0; i < comparisonRates.length; i++) {
      final rate = comparisonRates[i];

      if (rate == null) {
        // ギャップ：現在のパスを保存して新しいパスを開始
        if (currentPath != null) {
          paths.add(currentPath);
          currentPath = null;
        }
        continue;
      }

      final x = chartLeft + i / (daysInMonth - 1) * chartWidth;
      final y = chartTop + chartHeight * (1 - rate.clamp(0.0, yMax) / yMax);

      if (currentPath == null) {
        currentPath = Path();
        currentPath.moveTo(x, y);
      } else {
        currentPath.lineTo(x, y);
      }
    }

    // 最後のパスを追加
    if (currentPath != null) {
      paths.add(currentPath);
    }

    // 各パスを点線で描画
    for (final path in paths) {
      _drawDashedPath(canvas, path, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final nextDistance = (distance + dashWidth).clamp(0.0, metric.length);
        final extractPath = metric.extractPath(distance, nextDistance);
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + dashSpace;
      }
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
      ..color = AppColors.accentRed.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? path;
    Path? overPath;
    bool pathStarted = false;

    // startDayから描画開始（それ以前はギャップ）
    for (var i = startDay - 1; i < dataLength; i++) {
      final x = chartLeft + i / (daysInMonth - 1) * chartWidth;
      final rate = dailyRates[i].clamp(0.0, yMax);
      final y = chartTop + chartHeight * (1 - rate / yMax);

      if (!pathStarted) {
        path = Path();
        path.moveTo(x, y);
        pathStarted = true;
      } else {
        // 100%を超えた瞬間から赤い線に切り替え
        if (dailyRates[i] > 100 && dailyRates[i - 1] <= 100) {
          // 100%超え開始点
          overPath = Path();
          overPath.moveTo(x, y);
        }

        if (overPath != null && dailyRates[i] > 100) {
          overPath.lineTo(x, y);
        } else {
          path?.lineTo(x, y);
        }
      }
    }

    if (path != null) {
      canvas.drawPath(path, normalPaint);
    }
    if (overPath != null) {
      canvas.drawPath(overPath, overPaint);
    }
  }

  void _drawTodayDot(Canvas canvas, double chartLeft, double chartTop,
      double chartWidth, double chartHeight, double yMax) {
    if (todayDay < 1 || todayDay > dailyRates.length) return;
    // 記録開始前の日にはドットを表示しない
    if (todayDay < startDay) return;

    final rate = dailyRates[todayDay - 1];
    final x = chartLeft + (todayDay - 1) / (daysInMonth - 1) * chartWidth;
    final y = chartTop + chartHeight * (1 - rate.clamp(0.0, yMax) / yMax);

    // ドットの色（100%超えなら赤系）
    final dotColor = rate > 100
        ? AppColors.accentRed.withValues(alpha: 0.9)
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
        oldDelegate.daysInMonth != daysInMonth ||
        oldDelegate.startDay != startDay ||
        oldDelegate.cycleStartDate != cycleStartDate ||
        oldDelegate.comparisonRates != comparisonRates ||
        oldDelegate.comparisonStartDay != comparisonStartDay ||
        oldDelegate.comparisonType != comparisonType;
  }
}
