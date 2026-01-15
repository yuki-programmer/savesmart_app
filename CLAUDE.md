# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SaveSmart is a Japanese expense management app that categorizes spending into three grades (節約/標準/ご褒美) and calculates savings by comparing against a "standard" baseline.

## Build Commands

```bash
flutter pub get                           # Install dependencies
flutter run                               # Run the app
flutter run --dart-define=DEV_TOOLS=true  # Run with developer tools enabled
flutter analyze                           # Analyze code for issues
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
- Provides computed getters for filtered views (today/week/month/previous month expenses)
- Calculates savings using grade-based formulas
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

### Database Schema (Version 7)
Tables: `expenses`, `categories`, `budgets`, `fixed_costs`, `fixed_cost_categories`, `quick_entries`, `daily_budgets`, `incomes`

Key fields:
- `expenses.grade`: 'saving' | 'standard' | 'reward'
- `expenses.parent_id`: Links split expenses to parent
- `fixed_costs.category_name_snapshot`: Preserves category name at creation time
- `quick_entries`: Quick entry templates (title, category, amount, grade, sort_order)
- `daily_budgets`: Fixed daily allowance per date (date PK, fixed_amount)

Indices:
- `idx_expenses_created_at`: Optimizes date-range queries
- `idx_expenses_category_created_at`: Optimizes category+date aggregation

### Savings Calculation Logic
- **Saving grade:** savings = amount / 0.7 - amount (assumes 30% discount)
- **Standard grade:** no adjustment
- **Reward grade:** loss = amount - amount / 1.3 (assumes 30% premium)

## Key Directories

```
lib/
├── config/          # AppColors (theme.dart), AppConstants (constants.dart)
├── core/            # DevConfig, FinancialCycle (給料日ベースのサイクル計算)
├── models/          # Data models (Expense, Category, Budget, FixedCost, FixedCostCategory, QuickEntry)
├── services/        # DatabaseService (singleton), AppState (ChangeNotifier)
├── screens/         # Main screens (home, add, history, analytics, settings, fixed_cost, quick_entry_manage)
├── widgets/
│   ├── expense/     # Add expense related widgets
│   ├── analytics/   # Analytics charts and sheets
│   ├── fixed_cost/  # Fixed cost management widgets
│   └── quick_entry/ # Quick entry edit modal
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
- Modals via `showModalBottomSheet` for split, edit, and category management

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

Use `formatNumber()` from `lib/utils/formatters.dart` for displaying amounts with thousand separators:
```dart
import '../utils/formatters.dart';
Text('¥${formatNumber(amount)}')  // ¥1,234
```

## Key Features

### Financial Cycle System (給料日ベース)
- `FinancialCycle` class at `lib/core/financial_cycle.dart`
- Custom 1-month cycle based on salary date (1-31) instead of calendar month
- Auto-normalizes for shorter months (31日設定 → 2月は28/29日に調整)
- Key methods: `getStartDate()`, `getEndDate()`, `getDaysRemaining()`, `getCycleKey()`
- Backward compatible with calendar month when salary day = 1

### Income Management (収入管理)
- `incomes` table stores main income and sub-income (Refill)
- Cycle key format: `cycle_YYYY_MM_DD` (based on salary date)
- Main income: Primary salary, used for budget calculation
- Sub-income (Refill): Additional income added to remaining budget

### Monthly Available Amount
- Budget stored in DB with cycle key
- `thisMonthAvailableAmount` / `previousMonthAvailableAmount` getters
- Disposable amount = Total income - Fixed costs total

### Burn Rate Chart (`lib/widgets/burn_rate_chart.dart`)
- Shows cumulative spending percentage over the month
- Supports comparison line (ideal line for first month, previous month line thereafter)
- Handles mid-month start: `startDay` parameter skips drawing before first record day
- Lines drawn with CustomPainter, dashed lines for comparison

### Category Breakdown (`analytics_screen.dart`)
- Toggle between "固定費抜き" (excluding fixed costs) and "固定費込み" (including fixed costs)
- Pie chart using fl_chart package

### Category Detail Analysis (`category_detail_screen.dart`)
- MBTI-style 3-segment bar showing saving/standard/reward ratios
- Toggle between count and amount display modes
- 6-month average comparison per grade
- Monthly trend stacked bar chart (12 months, horizontal scroll, auto-scroll to current month)
- SQL aggregation via `getMonthlyGradeBreakdown()` for performance
- Label visibility threshold: 8% minimum to prevent unreadable text

### Fixed Costs
- Stored separately from variable expenses
- Has its own category system (`fixed_cost_categories`)
- `categoryNameSnapshot` preserves category name at creation time

### Quick Entry (クイック登録)
- Templates for frequently used expenses stored in `quick_entries` table
- Home screen displays tiles that record expense with 1-tap
- Managed via QuickEntryManageScreen (list with 3-dot menu for edit/delete)
- Title is optional (defaults to category name if empty)

### Daily Budget (今日使えるお金)
- **fixedTodayAllowance**: Fixed at day start, stored in `daily_budgets` table
  - Formula: (予算 - 昨日までの支出 - 固定費) / 残り日数
  - Does NOT change when expenses are added during the day
- **dynamicTomorrowForecast**: Recalculated on every expense change
  - Formula: (予算 - 今日までの支出 - 固定費) / (明日〜月末の日数)
  - Shows green if better than today's allowance (節約成功)
- Month-end edge case: Shows "今月もあと1日！" instead of tomorrow forecast

### Smart Combo Prediction (スマート・コンボ)
- SQL aggregation of frequently used amount+grade combinations per category
- Displayed as chips after category selection in AddScreen
- Tapping auto-fills amount and grade

### History Screen (履歴)
- Vertical timeline format with 2-column layout (date | content)
- Shows all dates from month start to today (descending), including empty days
- Tap expense row to open action bottom sheet (edit, split, delete)
- Search mode shows flat list filtered by category/memo

### Night Reflection (夜の振り返り)
- `NightReflectionDialog` at `lib/widgets/night_reflection_dialog.dart`
- Home screen switches between day card and night card based on time
- Time-based display conditions:
  - 19:00〜23:59: Always show night card (even with new expenses)
  - 00:00〜03:59: Show night card only if no expenses registered today
  - 04:00〜18:59: Always show day card
- Night card shows: today's total spending + tomorrow's budget (日割り)
- Tap night card to open fullscreen reflection dialog (can be viewed multiple times)
- Logic via `NightReflectionDialog.shouldShowNightCard(hasTodayExpense: bool)`

## Desktop Support

FFI initialization in `main.dart` enables Windows/Linux/macOS via `sqflite_common_ffi`.

## Japanese UI Text

All user-facing text is in Japanese. Common terms:
- 節約 (setsuyaku) = saving grade
- 標準 (hyoujun) = standard grade
- ご褒美 (gohoubi) = reward grade
- 固定費 (koteihi) = fixed costs
- 変動費 (hendouhi) = variable costs
- 使える金額 (tsukaeru kingaku) = available amount
- 可処分金額 (kashobun kingaku) = disposable amount
- 家計の余裕 (kakei no yoyuu) = budget margin
- 格上げカテゴリ (kakuage category) = upgrade recommendation category

## AppState Key Methods

### Time-series Data
```dart
// Generate month keys for 0-padding
static List<String> generateMonthKeys(int months)  // Returns ['2024-01', '2024-02', ...]

// Get category monthly trend with 0-padding for missing months
Future<List<Map<String, dynamic>>> getCategoryMonthlyTrend(String categoryName, {int months = 12})
```

### Category Analysis
```dart
// Full category detail analysis (this month + 6-month avg)
Map<String, dynamic> getCategoryDetailAnalysis(String categoryName)

// Upgrade recommendation categories (1+ reward records, max 3)
List<Map<String, dynamic>> getUpgradeCategories()
```

### Partial Reload (Performance)
```dart
_reloadExpenses()           // Reload only expenses
_reloadCategories()         // Reload only categories
_reloadFixedCosts()         // Reload only fixed costs
_reloadFixedCostCategories() // Reload only fixed cost categories
_reloadBudget()             // Reload only budget
_reloadQuickEntries()       // Reload only quick entries
```

### Quick Entry Methods
```dart
addQuickEntry(QuickEntry)    // Add new template
updateQuickEntry(QuickEntry) // Update existing template
deleteQuickEntry(int id)     // Delete template
executeQuickEntry(QuickEntry) // Create expense from template and save
getSmartCombos(String category) // Get frequent amount+grade combos for category
```

### Daily Budget Methods
```dart
fixedTodayAllowance          // Getter: today's fixed allowance (from DB)
dynamicTomorrowForecast      // Getter: tomorrow's forecast (calculated)
isLastDayOfMonth             // Getter: bool for month-end edge case
_loadOrCreateTodayAllowance() // Load from DB or calculate and save
```

## Hero Animation Pattern

When using Hero widgets with complex content, add `flightShuttleBuilder` to prevent overflow during animation:

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
