/// 給料日を基準とした独自の1ヶ月サイクルを管理するクラス
///
/// カレンダー月（1日〜末日）ではなく、給料日から次の給料日前日までを
/// 1サイクルとして扱うことで、実際の家計管理に沿った予算計算を実現する。
class FinancialCycle {
  /// サイクル開始日（給料日）: 1〜31
  final int mainSalaryDay;

  const FinancialCycle({this.mainSalaryDay = 1});

  /// 月末を超えないよう正規化した日を返す
  ///
  /// 例: 31日が設定されているが、2月の場合は28日（または29日）を返す
  static int normalizeDay(int day, int year, int month) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return day > lastDayOfMonth ? lastDayOfMonth : day;
  }

  /// 指定日時が属するサイクルの開始日を返す
  ///
  /// - 今日が給料日以降: 今月の給料日
  /// - 今日が給料日より前: 先月の給料日
  DateTime getStartDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDayThisMonth = normalizeDay(mainSalaryDay, now.year, now.month);

    if (today.day >= normalizedDayThisMonth) {
      // 今月の給料日以降 → 今月の給料日がサイクル開始
      return DateTime(now.year, now.month, normalizedDayThisMonth);
    } else {
      // 今月の給料日より前 → 先月の給料日がサイクル開始
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;
      final normalizedDayPrevMonth = normalizeDay(mainSalaryDay, prevYear, prevMonth);
      return DateTime(prevYear, prevMonth, normalizedDayPrevMonth);
    }
  }

  /// 指定日時が属するサイクルの終了日を返す（次のサイクル開始日の前日）
  DateTime getEndDate(DateTime now) {
    final startDate = getStartDate(now);

    // 次のサイクル開始日を計算
    final nextMonth = startDate.month == 12 ? 1 : startDate.month + 1;
    final nextYear = startDate.month == 12 ? startDate.year + 1 : startDate.year;
    final normalizedDayNextMonth = normalizeDay(mainSalaryDay, nextYear, nextMonth);
    final nextCycleStart = DateTime(nextYear, nextMonth, normalizedDayNextMonth);

    // 次のサイクル開始日の前日が終了日
    return nextCycleStart.subtract(const Duration(days: 1));
  }

  /// サイクル終了日までの残り日数（今日を含む）
  int getDaysRemaining(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final endDate = getEndDate(now);
    return endDate.difference(today).inDays + 1;
  }

  /// サイクルの総日数
  int getTotalDays(DateTime now) {
    final startDate = getStartDate(now);
    final endDate = getEndDate(now);
    return endDate.difference(startDate).inDays + 1;
  }

  /// サイクル開始日からの経過日数（今日を含む）
  int getDaysElapsed(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final startDate = getStartDate(now);
    return today.difference(startDate).inDays + 1;
  }

  /// サイクル開始日から今日までのすべての日付を生成（降順）
  List<DateTime> generateDatesFromStartToToday(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final startDate = getStartDate(now);

    final dates = <DateTime>[];
    var current = today;
    while (!current.isBefore(startDate)) {
      dates.add(current);
      current = current.subtract(const Duration(days: 1));
    }
    return dates;
  }

  /// 一意のサイクルキーを生成（例: 'cycle_2026_01_25'）
  ///
  /// このキーはDBでサイクルごとの予算を識別するために使用する
  String getCycleKey(DateTime now) {
    final startDate = getStartDate(now);
    final year = startDate.year.toString();
    final month = startDate.month.toString().padLeft(2, '0');
    final day = startDate.day.toString().padLeft(2, '0');
    return 'cycle_${year}_${month}_$day';
  }

  /// 指定日付がどのサイクルに属するかを判定し、そのサイクルキーを返す
  String getCycleKeyForDate(DateTime date) {
    return getCycleKey(date);
  }

  /// 前サイクルのキーを取得
  ///
  /// 現在のサイクル開始日の前日を基準に、そのサイクルのキーを返す
  String getPreviousCycleKey(DateTime now) {
    final currentStart = getStartDate(now);
    // 現在サイクルの開始日の前日 = 前サイクルの最終日
    final prevCycleLastDay = currentStart.subtract(const Duration(days: 1));
    return getCycleKey(prevCycleLastDay);
  }

  /// 前サイクルの開始日を取得
  DateTime getPreviousCycleStartDate(DateTime now) {
    final currentStart = getStartDate(now);
    final prevCycleLastDay = currentStart.subtract(const Duration(days: 1));
    return getStartDate(prevCycleLastDay);
  }

  /// 前サイクルの終了日を取得
  DateTime getPreviousCycleEndDate(DateTime now) {
    final currentStart = getStartDate(now);
    // 現在サイクルの開始日の前日が前サイクルの終了日
    return currentStart.subtract(const Duration(days: 1));
  }

  /// 前サイクルの総日数を取得
  int getPreviousCycleTotalDays(DateTime now) {
    final prevStart = getPreviousCycleStartDate(now);
    final prevEnd = getPreviousCycleEndDate(now);
    return prevEnd.difference(prevStart).inDays + 1;
  }

  /// 後方互換: 給料日が1日の場合はカレンダー月と同じキー形式を返す
  ///
  /// 既存の 'monthly_amount_YYYY-MM' との互換性を維持
  String getLegacyMonthKey(DateTime now) {
    if (mainSalaryDay == 1) {
      // 従来の月単位キー
      return '${now.year}-${now.month.toString().padLeft(2, '0')}';
    } else {
      // サイクルベースの場合は開始日の年月
      final startDate = getStartDate(now);
      return '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
    }
  }

  /// 月末日かどうか（サイクル終了日かどうか）
  bool isLastDayOfCycle(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final endDate = getEndDate(now);
    return today.year == endDate.year &&
        today.month == endDate.month &&
        today.day == endDate.day;
  }

  /// 指定日がサイクル内に含まれるかどうか
  bool isDateInCurrentCycle(DateTime date, DateTime now) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final startDate = getStartDate(now);
    final endDate = getEndDate(now);

    return !targetDate.isBefore(startDate) && !targetDate.isAfter(endDate);
  }

  /// 日割り予算を計算
  ///
  /// - [totalBudget]: サイクルの総予算
  /// - [totalExpenses]: サイクル内の累計支出
  /// - [fixedCosts]: 固定費合計
  /// - [now]: 現在日時
  /// - [forTomorrow]: trueの場合、明日以降の日割りを計算
  int calculateDailyAllowance({
    required int totalBudget,
    required int totalExpenses,
    required int fixedCosts,
    required DateTime now,
    bool forTomorrow = false,
  }) {
    final remaining = totalBudget - totalExpenses - fixedCosts;
    final daysRemaining = getDaysRemaining(now);

    if (forTomorrow) {
      // 明日以降の予測: 今日を除く
      final daysAfterToday = daysRemaining - 1;
      if (daysAfterToday <= 0) return 0;
      return remaining ~/ daysAfterToday;
    } else {
      // 今日の日割り
      if (daysRemaining <= 0) return 0;
      return remaining ~/ daysRemaining;
    }
  }

  /// サブ収入（Refill）を加算した後の日割り予算を計算
  ///
  /// Allowance_new = (Budget_remaining + Income_sub) / Days_remaining
  int calculateAllowanceWithRefill({
    required int currentRemaining,
    required int additionalIncome,
    required DateTime now,
  }) {
    final daysRemaining = getDaysRemaining(now);
    if (daysRemaining <= 0) return 0;
    return (currentRemaining + additionalIncome) ~/ daysRemaining;
  }

  @override
  String toString() {
    return 'FinancialCycle(mainSalaryDay: $mainSalaryDay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialCycle && other.mainSalaryDay == mainSalaryDay;
  }

  @override
  int get hashCode => mainSalaryDay.hashCode;
}
