import 'package:flutter_test/flutter_test.dart';
import 'package:save_smart_app/core/financial_cycle.dart';

void main() {
  group('FinancialCycle', () {
    group('normalizeDay', () {
      test('31日設定で2月は28日に正規化', () {
        // 2025年2月（平年）
        expect(FinancialCycle.normalizeDay(31, 2025, 2), 28);
      });

      test('31日設定で閏年2月は29日に正規化', () {
        // 2024年2月（閏年）
        expect(FinancialCycle.normalizeDay(31, 2024, 2), 29);
      });

      test('31日設定で4月は30日に正規化', () {
        expect(FinancialCycle.normalizeDay(31, 2025, 4), 30);
      });

      test('25日設定で2月はそのまま25日', () {
        expect(FinancialCycle.normalizeDay(25, 2025, 2), 25);
      });

      test('1日設定はどの月でも1日', () {
        expect(FinancialCycle.normalizeDay(1, 2025, 1), 1);
        expect(FinancialCycle.normalizeDay(1, 2025, 2), 1);
        expect(FinancialCycle.normalizeDay(1, 2025, 12), 1);
      });
    });

    group('getStartDate', () {
      test('給料日1日: 1月15日時点のサイクル開始日は1月1日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);
        expect(cycle.getStartDate(now), DateTime(2025, 1, 1));
      });

      test('給料日25日: 1月30日時点のサイクル開始日は1月25日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 1, 30);
        expect(cycle.getStartDate(now), DateTime(2025, 1, 25));
      });

      test('給料日25日: 1月10日時点のサイクル開始日は12月25日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 1, 10);
        expect(cycle.getStartDate(now), DateTime(2024, 12, 25));
      });

      test('給料日25日: 2月24日時点のサイクル開始日は1月25日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 24);
        expect(cycle.getStartDate(now), DateTime(2025, 1, 25));
      });

      test('給料日25日: 2月25日時点のサイクル開始日は2月25日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 25);
        expect(cycle.getStartDate(now), DateTime(2025, 2, 25));
      });

      test('年跨ぎ: 給料日25日で1月5日時点のサイクル開始日は12月25日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2026, 1, 5);
        expect(cycle.getStartDate(now), DateTime(2025, 12, 25));
      });
    });

    group('getEndDate', () {
      test('給料日1日: 1月のサイクル終了日は1月31日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);
        expect(cycle.getEndDate(now), DateTime(2025, 1, 31));
      });

      test('給料日25日: 1月25日開始のサイクル終了日は2月24日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 1, 30);
        expect(cycle.getEndDate(now), DateTime(2025, 2, 24));
      });

      test('給料日25日: 2月25日開始のサイクル終了日は3月24日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 28);
        expect(cycle.getEndDate(now), DateTime(2025, 3, 24));
      });

      test('年跨ぎ: 給料日25日で12月25日開始のサイクル終了日は1月24日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 12, 30);
        expect(cycle.getEndDate(now), DateTime(2026, 1, 24));
      });
    });

    group('getDaysRemaining', () {
      test('給料日1日: 1月15日時点の残り日数は17日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);
        // 1月15日〜1月31日 = 17日
        expect(cycle.getDaysRemaining(now), 17);
      });

      test('給料日1日: 月末日の残り日数は1日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 31);
        expect(cycle.getDaysRemaining(now), 1);
      });

      test('給料日25日: 1月30日時点の残り日数は26日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 1, 30);
        // 1月30日〜2月24日 = 26日
        expect(cycle.getDaysRemaining(now), 26);
      });
    });

    group('isLastDayOfCycle', () {
      test('給料日1日: 1月31日はサイクル最終日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        expect(cycle.isLastDayOfCycle(DateTime(2025, 1, 31)), true);
      });

      test('給料日1日: 1月30日はサイクル最終日ではない', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        expect(cycle.isLastDayOfCycle(DateTime(2025, 1, 30)), false);
      });

      test('給料日25日: 2月24日はサイクル最終日', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        expect(cycle.isLastDayOfCycle(DateTime(2025, 2, 24)), true);
      });

      test('給料日25日: 2月25日はサイクル最終日ではない（新サイクル開始日）', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        expect(cycle.isLastDayOfCycle(DateTime(2025, 2, 25)), false);
      });
    });

    group('getCycleKey', () {
      test('給料日1日: 1月のサイクルキー', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);
        expect(cycle.getCycleKey(now), 'cycle_2025_01_01');
      });

      test('給料日25日: 1月25日〜2月24日のサイクルキー', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 10);
        expect(cycle.getCycleKey(now), 'cycle_2025_01_25');
      });

      test('給料日25日: 2月25日以降のサイクルキー', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 26);
        expect(cycle.getCycleKey(now), 'cycle_2025_02_25');
      });
    });

    group('isDateInCurrentCycle', () {
      test('給料日25日: 1月30日はサイクル内', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 10);
        expect(cycle.isDateInCurrentCycle(DateTime(2025, 1, 30), now), true);
      });

      test('給料日25日: 1月24日はサイクル外（前のサイクル）', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 10);
        expect(cycle.isDateInCurrentCycle(DateTime(2025, 1, 24), now), false);
      });

      test('給料日25日: 2月25日はサイクル外（次のサイクル）', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 2, 10);
        expect(cycle.isDateInCurrentCycle(DateTime(2025, 2, 25), now), false);
      });
    });

    group('generateDatesFromStartToToday', () {
      test('給料日1日: 1月5日時点で5日分の日付が生成される', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 5);
        final dates = cycle.generateDatesFromStartToToday(now);

        expect(dates.length, 5);
        expect(dates.first, DateTime(2025, 1, 5)); // 今日が最初（降順）
        expect(dates.last, DateTime(2025, 1, 1));  // 開始日が最後
      });

      test('給料日25日: 1月30日時点で6日分の日付が生成される', () {
        const cycle = FinancialCycle(mainSalaryDay: 25);
        final now = DateTime(2025, 1, 30);
        final dates = cycle.generateDatesFromStartToToday(now);

        expect(dates.length, 6);
        expect(dates.first, DateTime(2025, 1, 30));
        expect(dates.last, DateTime(2025, 1, 25));
      });
    });

    group('calculateDailyAllowance', () {
      test('基本的な日割り計算', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);

        // 残り17日、予算30万、支出10万、固定費5万
        final allowance = cycle.calculateDailyAllowance(
          totalBudget: 300000,
          totalExpenses: 100000,
          fixedCosts: 50000,
          now: now,
        );

        // (300000 - 100000 - 50000) / 17 = 8823
        expect(allowance, 8823);
      });

      test('明日以降の予測計算', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);

        final allowance = cycle.calculateDailyAllowance(
          totalBudget: 300000,
          totalExpenses: 100000,
          fixedCosts: 50000,
          now: now,
          forTomorrow: true,
        );

        // (300000 - 100000 - 50000) / 16 = 9375
        expect(allowance, 9375);
      });
    });

    group('calculateAllowanceWithRefill', () {
      test('サブ収入追加後の日割り計算', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);

        // 残り予算10万、サブ収入5万追加、残り17日
        final newAllowance = cycle.calculateAllowanceWithRefill(
          currentRemaining: 100000,
          additionalIncome: 50000,
          now: now,
        );

        // (100000 + 50000) / 17 = 8823
        expect(newAllowance, 8823);
      });
    });

    group('後方互換性（給料日1日）', () {
      test('給料日1日の場合、従来のカレンダー月と同じ動作', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 1, 15);

        // 開始日 = 1月1日
        expect(cycle.getStartDate(now), DateTime(2025, 1, 1));

        // 終了日 = 1月31日
        expect(cycle.getEndDate(now), DateTime(2025, 1, 31));

        // 残り日数 = 31 - 15 + 1 = 17
        expect(cycle.getDaysRemaining(now), 17);
      });

      test('給料日1日の2月の終了日は2月末', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2025, 2, 15);

        expect(cycle.getEndDate(now), DateTime(2025, 2, 28));
      });

      test('給料日1日の閏年2月の終了日は2月29日', () {
        const cycle = FinancialCycle(mainSalaryDay: 1);
        final now = DateTime(2024, 2, 15);

        expect(cycle.getEndDate(now), DateTime(2024, 2, 29));
      });
    });

    group('エッジケース：月跨ぎ', () {
      test('給料日15日: 1月31日時点のサイクルは1月15日〜2月14日', () {
        const cycle = FinancialCycle(mainSalaryDay: 15);
        final now = DateTime(2025, 1, 31);

        expect(cycle.getStartDate(now), DateTime(2025, 1, 15));
        expect(cycle.getEndDate(now), DateTime(2025, 2, 14));
      });

      test('給料日15日: 2月1日時点のサイクルは1月15日〜2月14日', () {
        const cycle = FinancialCycle(mainSalaryDay: 15);
        final now = DateTime(2025, 2, 1);

        expect(cycle.getStartDate(now), DateTime(2025, 1, 15));
        expect(cycle.getEndDate(now), DateTime(2025, 2, 14));
      });

      test('給料日31日: 2月の処理（31日が存在しない月）', () {
        const cycle = FinancialCycle(mainSalaryDay: 31);
        final now = DateTime(2025, 2, 15);

        // 2月には31日がないので、1月31日開始
        expect(cycle.getStartDate(now), DateTime(2025, 1, 31));
        // 次のサイクルは2月28日開始なので、2月27日終了
        expect(cycle.getEndDate(now), DateTime(2025, 2, 27));
      });
    });
  });
}
