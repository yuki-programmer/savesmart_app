# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SaveSmart is a Japanese expense management app focused on "今日使えるお金" (daily allowance). It uses salary-date-based financial cycles, categorizes spending into three grades (節約/標準/ご褒美), and visualizes budget pace.

## Build Commands

```bash
flutter pub get                           # Install dependencies
flutter run                               # Run the app
flutter run --dart-define=DEV_TOOLS=true  # Run with developer tools enabled
flutter analyze                           # Analyze code for issues
flutter test                              # Run all tests
flutter test test/financial_cycle_test.dart  # Run specific test file
flutter build apk                         # Build for Android
flutter build ios                         # Build for iOS
flutter build windows                     # Build for Windows
```

## Developer Mode

DEV_TOOLS must be enabled via dart-define to access developer features:
- Premium override toggle (for testing premium-only features)
- Unlocked by tapping version 10 times in settings screen

Premium判定は必ず `context.watch<AppState>().isPremium` を参照する。

## Architecture

### State Management
Provider with ChangeNotifier pattern. `AppState` (`lib/services/app_state.dart`) is the central state manager that:
- Holds all expenses, categories, fixed costs, and budget data
- Provides computed getters for filtered views (today/week/month expenses)
- Calculates daily allowance using FinancialCycle
- All CRUD methods return `Future<bool>` for error handling

### Data Flow
```
UI (Screens/Widgets)
    ↓ Consumer<AppState> / context.watch/read
AppState (ChangeNotifier)
    ↓ async methods returning bool
DatabaseService (Singleton)
    ↓ sqflite
SQLite Database (savesmart.db)
```

### Database Schema (Version 8)
Tables: `expenses`, `categories`, `budgets`, `fixed_costs`, `fixed_cost_categories`, `quick_entries`, `daily_budgets`, `cycle_incomes`

Key fields:
- `expenses.grade`: 'saving' | 'standard' | 'reward'
- `expenses.parent_id`: Links split expenses to parent
- `fixed_costs.category_name_snapshot`: Preserves category name at creation time
- `quick_entries`: Quick entry templates (title, category, amount, grade, sort_order)
- `daily_budgets`: Fixed daily allowance per date (date PK, fixed_amount)
- `cycle_incomes`: Cycle-based income (cycle_key, main_income, sub_income, sub_income_name)

Indices:
- `idx_expenses_created_at`: Optimizes date-range queries
- `idx_expenses_category_created_at`: Optimizes category+date aggregation
- `idx_cycle_incomes_cycle_key`: Optimizes cycle income lookup

## Key Directories

```
lib/
├── config/          # AppColors (theme.dart), category_icons.dart, home_constants.dart
├── core/            # DevConfig, FinancialCycle (給料日ベースのサイクル計算)
├── models/          # Data models (Expense, Category, Budget, FixedCost, QuickEntry)
├── services/        # DatabaseService (singleton), AppState (ChangeNotifier)
├── screens/         # Main screens (home, add, history, analytics, settings, category_manage)
├── widgets/
│   ├── expense/     # add_breakdown_modal.dart, split_modal.dart
│   ├── analytics/   # burn_rate_chart.dart, income_sheet.dart
│   ├── home/        # hero_card.dart (時間別テーマ対応), quick_entry widgets
│   └── night_reflection_dialog.dart
└── utils/           # formatters.dart (formatNumber utility)
```

## Styling Conventions

- Typography: Google Fonts (Inter for UI, IBM Plex Sans for numbers)
- Colors: Defined in `AppColors` class (`lib/config/theme.dart`)
- Grade colors: Green (節約/saving), Blue (標準/standard), Orange (ご褒美/reward)
- Icons: Material Icons with `_outlined` variants

## Navigation

- Bottom tab navigation with `IndexedStack` (preserves screen state)
- Three main tabs: Home (0), Add (1), Analytics (2)
- Modals via `showModalBottomSheet` for split, edit, and income management
- Category management accessible from Settings and Add screen

## Error Handling Pattern

AppState CRUD methods return `Future<bool>` (true=success, false=error). UI should check the result:

```dart
final success = await appState.addExpense(expense);
if (!success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('保存に失敗しました'), backgroundColor: AppColors.accentRed),
  );
}
```

## Utility Functions

Use `formatNumber()` and `formatCurrency()` from `lib/utils/formatters.dart`:
```dart
import '../utils/formatters.dart';
Text('¥${formatNumber(amount)}')  // ¥1,234
Text(formatCurrency(amount, currencyFormat))  // prefix: ¥1,234 / suffix: 1,234円
```

Currency format is stored in `AppState.currencyFormat` ('prefix' or 'suffix').

## Key Features

### Financial Cycle System (給料日ベース)
- `FinancialCycle` class at `lib/core/financial_cycle.dart`
- Custom 1-month cycle based on salary date (1-28) instead of calendar month
- Auto-normalizes for shorter months (31日設定 → 2月は28/29日に調整)
- Key methods: `getStartDate()`, `getEndDate()`, `getDaysRemaining()`, `getCycleKey()`
- Backward compatible with calendar month when salary day = 1
- Previous cycle methods: `getPreviousCycleKey()`, `getPreviousCycleStartDate()`, `getPreviousCycleEndDate()`

### Income Management (収入管理)
- `cycle_incomes` table stores main income and sub-income (Refill)
- Cycle key format: `cycle_YYYY_MM_DD` (based on salary date)
- Main income: Primary salary, used for budget calculation
- Sub-income (Refill): Additional income added to remaining budget
- Income changes trigger automatic daily allowance recalculation

### Daily Budget (今日使えるお金)
- **fixedTodayAllowance**: Fixed at day start, stored in `daily_budgets` table
  - Formula: (予算 - 昨日までの支出 - 固定費) / 残り日数
  - Does NOT change when expenses are added during the day
- **dynamicTomorrowForecast**: Recalculated on every expense change
  - Formula: (予算 - 今日までの支出 - 固定費) / (明日〜月末の日数)
  - Shows green if better than today's allowance (節約成功)
- Month-end edge case: Shows "今月もあと1日！" instead of tomorrow forecast

### Breakdown Feature (内訳機能)
- Split one expense into multiple categories at registration time
- Example: 700円「買い物」→ 130円「コーヒー」+ 80円「食料品」+ 490円「買い物」(残り)
- Total stays fixed (breakdowns + remaining = original amount)
- Validation: Cannot exceed parent amount
- Saves as independent expenses (no parent_id used for new breakdowns)

### History Screen (全履歴)
- Infinite scroll with lazy loading (50 items per page)
- Cycle boundary headers showing date ranges
- Full-text search across all time (category + memo)
- Split feature: Extract portion to different category

### Burn Rate Chart
- Shows cumulative spending percentage over the cycle
- Current cycle (blue solid) vs previous cycle (gray dashed)
- Falls back to ideal line if no previous cycle data (< 3 days of records)
- Comparison badge shows savings/overspending vs previous cycle

### Monthly Expense Trend (月間の支出推移)
- 12-month grade-based stacked bar chart (`MonthlyExpenseTrendChart`)
- Free feature (no subscription required)
- Horizontal scroll with fixed Y-axis
- Auto-scrolls to latest month
- Variable expenses only (fixed costs excluded)
- SQL aggregation: `DatabaseService.getMonthlyGradeBreakdownAll()`

### Home Screen Time Modes (時間別テーマ)
HeroCard (`lib/widgets/home/hero_card.dart`) has three visual modes based on time:
- **Day mode** (4:00〜5:59, 10:00〜18:59): Standard white card
- **Morning mode** (6:00〜9:59): Warm gradient background (orange/yellow)
- **Night mode** (19:00〜3:59): Dark navy card with adjusted typography

Time mode is purely visual theming. Night reflection dialog is a separate feature (1x/day prompt).

### Night Reflection (夜の振り返り)
- Triggered via HeroCard tap when `canOpenReflection` is true
- SharedPreferences tracks if reflection was opened today (`reflection_opened_YYYY-MM-DD`)
- Shows today's total spending and tomorrow's forecasted budget
- Night mode display does NOT equal reflection availability

## Desktop Support

FFI initialization in `main.dart` enables Windows/Linux/macOS via `sqflite_common_ffi`.

## Japanese UI Text

All user-facing text is in Japanese. Common terms:
- 節約 (setsuyaku) = saving grade
- 標準 (hyoujun) = standard grade
- ご褒美 (gohoubi) = reward grade
- 固定費 (koteihi) = fixed costs
- 内訳 (uchiwake) = breakdown
- 家計の開始日 (kakei no kaishi bi) = financial cycle start date (salary day)

## AppState Key Methods

### Partial Reload (Performance)
```dart
_reloadExpenses()           // Reload only expenses
_reloadCategories()         // Reload only categories
_reloadFixedCosts()         // Reload only fixed costs
_reloadQuickEntries()       // Reload only quick entries
_reloadCycleIncome()        // Reload only cycle income
```

### Income Methods
```dart
Future<Map<String, dynamic>?> getMainIncome()
Future<List<Map<String, dynamic>>> getSubIncomes()
Future<void> setMainIncome(int amount)
Future<void> addSubIncome(String name, int amount)
```

### Previous Cycle Comparison
```dart
Future<Map<String, dynamic>?> getPreviousCycleBurnRateData()
Future<int?> getCycleComparisonDiff()  // Positive = saving, Negative = overspending
```

## Hero Animation Pattern

When using Hero widgets with complex content, add `flightShuttleBuilder` to prevent overflow:

```dart
Hero(
  tag: 'category_$categoryName',
  flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(4)),
      ),
    );
  },
  child: /* Complex widget */,
)
```

## Wheel Picker (金額入力)

Add screen uses a wheel picker for amount input (`lib/screens/add_screen.dart`):
- Units: 10円, 100円, 1000円, 1万, 10万, 100万
- Max amount: 1000万円 (unified across all units)
- Reset button (↻) on the left resets amount to 0
- Unit switching preserves the current amount (does not reset)
- Smart combo auto-select adjusts unit based on selected quick entry amount

## Performance Optimization

### Selector Pattern (HomeScreen)
Use `Selector<AppState, T>` instead of `Consumer<AppState>` to minimize rebuilds:
```dart
Selector<AppState, _HeroCardData>(
  selector: (_, appState) => _HeroCardData(
    fixedTodayAllowance: appState.fixedTodayAllowance,
    dynamicTomorrowForecast: appState.dynamicTomorrowForecast,
  ),
  builder: (context, data, child) => HeroCard(...),
)
```
Data classes must implement `==` and `hashCode` for proper comparison.

### SQL Aggregation (DatabaseService)
Prefer SQL aggregation over in-memory filtering for large datasets:
```dart
// Good: SQL aggregation
await _db.getCategoryStats(cycleStartDate: start, cycleEndDate: end);

// Avoid: In-memory filtering for aggregation
_expenses.where(...).fold(0, (sum, e) => sum + e.amount);
```

Key SQL methods:
- `getTodayTotal()`, `getTodayExpenses()`
- `getExpenseTotalUntilYesterday(cycleStartDate:)`
- `getCycleTotalExpenses(cycleStartDate:, cycleEndDate:)`
- `getCategoryStats(cycleStartDate:, cycleEndDate:)`
- `getMonthlyGradeBreakdownAll(months:)`

### Caching (AppState)
AppState caches frequently accessed data with date-based invalidation:
- `_cachedTodayExpenses`, `_cachedTodayTotal` (invalidated daily)
- `_cachedThisMonthExpenses` (invalidated on cycle change)
- Call `_invalidateExpensesCaches()` after expense modifications

## Reference Documentation

See `function.md` for detailed feature specifications in Japanese.
