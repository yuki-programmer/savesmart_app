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

### Database Schema (Version 4)
Tables: `expenses`, `categories`, `budgets`, `fixed_costs`, `fixed_cost_categories`

Key fields:
- `expenses.grade`: 'saving' | 'standard' | 'reward'
- `expenses.parent_id`: Links split expenses to parent
- `fixed_costs.category_name_snapshot`: Preserves category name at creation time

Indices (v4):
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
├── core/            # DevConfig for developer mode gating
├── models/          # Data models (Expense, Category, Budget, FixedCost, FixedCostCategory)
├── services/        # DatabaseService (singleton), AppState (ChangeNotifier)
├── screens/         # Main screens (home, add, history, analytics, settings, fixed_cost)
├── widgets/
│   ├── expense/     # Add expense related widgets
│   ├── analytics/   # Analytics charts and sheets
│   └── fixed_cost/  # Fixed cost management widgets
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

### Monthly Available Amount
- Stored per month in SharedPreferences with key `monthly_amount_YYYY-MM`
- `thisMonthAvailableAmount` / `previousMonthAvailableAmount` getters
- Disposable amount = Available amount - Fixed costs total

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
