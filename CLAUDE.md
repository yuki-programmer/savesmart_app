# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SaveSmart is a Japanese expense management app that categorizes spending into three grades (節約/標準/ご褒美) and calculates savings by comparing against a "standard" baseline.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Run the app (standard)
flutter run

# Run with developer tools enabled
flutter run --dart-define=DEV_TOOLS=true

# Analyze code
flutter analyze

# Build for production
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows
```

## Developer Mode

DEV_TOOLS must be enabled via dart-define to access developer features:
- Premium override toggle (for testing premium-only features)
- Unlocked by tapping version 10 times in settings screen

Premium判定は必ず `context.watch<AppState>().isPremium` を参照する。

## Architecture

### State Management
Provider with ChangeNotifier pattern. `AppState` (`lib/services/app_state.dart`) is the central state manager that:
- Holds all expenses, categories, and budget data
- Provides computed getters for filtered views (today/week/month expenses)
- Calculates savings using grade-based formulas

### Data Flow
```
UI (Screens/Widgets)
    ↓ Consumer<AppState>
AppState (ChangeNotifier)
    ↓ async methods
DatabaseService (Singleton)
    ↓ sqflite
SQLite Database (savesmart.db)
```

### Database Schema
Three tables: `expenses`, `categories`, `budgets`. Key fields:
- `expenses.grade`: 'saving' | 'standard' | 'reward'
- `expenses.parent_id`: Links split expenses to parent

### Savings Calculation Logic
- **Saving grade:** savings = amount / 0.7 - amount (assumes 30% discount)
- **Standard grade:** no adjustment
- **Reward grade:** loss = amount - amount / 1.3 (assumes 30% premium)

## Key Directories

- `lib/config/` - Theme colors (`AppColors`) and constants (`AppConstants`)
- `lib/core/` - DevConfig for developer mode gating
- `lib/models/` - Data models (Expense, Category, Budget)
- `lib/services/` - DatabaseService and AppState
- `lib/screens/` - Main screens (home, add, history, analytics, settings, category_manage)
- `lib/widgets/` - Reusable widgets (wheel_picker, split_modal, bottom_nav, edit_amount_modal)

## Key Dependencies

- `fl_chart` - Pie charts in analytics screen
- `sqflite` / `sqflite_common_ffi` - SQLite for mobile and desktop
- `provider` - State management
- `google_fonts` - Typography (Inter, IBM Plex Sans)

## Styling Conventions

- Typography: Google Fonts (Inter for UI, IBM Plex Sans for numbers)
- Color scheme defined in `AppColors` class (`lib/config/theme.dart`)
- Grade colors: Green (節約), Blue (標準), Orange (ご褒美)
- Icons: Material Icons with `_outlined` variants for grades

## Navigation

- Bottom tab navigation with `IndexedStack` (preserves screen state)
- Floating action button opens add expense screen
- Modals for split, edit, and category management

## Desktop Support

FFI initialization in `main.dart` enables Windows/Linux/macOS via `sqflite_common_ffi`.
