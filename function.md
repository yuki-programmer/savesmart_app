# SaveSmart 機能一覧

## 概要

SaveSmartは「今日使えるお金」を軸にした家計管理アプリ。給料日ベースのサイクル管理で、日々の支出を3段階評価（節約/標準/ご褒美）で記録し、予算ペースを可視化する。

---

## 1. 初期設定フロー

### 1.1 給料日設定（Settings）
- 毎月の家計開始日を1〜28日から選択
- 設定した日から翌給料日前日までが1サイクル
- 例: 25日設定 → 1/25〜2/24が1月のサイクル

### 1.2 今月の予算設定（Home）
- 「今月使えるお金」をタップして金額入力
- この金額がサイクル全体の予算となる

### 1.3 固定費登録（Home）
- 家賃、光熱費、サブスクなど毎月固定の支出を登録
- 予算から自動差し引きされ、変動費の可処分額を算出

---

## 2. ホーム画面（Home）

### 2.1 今日使えるお金（メイン表示）
- **計算式**: (予算 - 固定費 - 昨日までの支出) ÷ 残り日数
- 毎朝0時に固定値として保存（日中は変動しない）
- 支出登録ごとに「明日の予測」がリアルタイム更新

### 2.2 明日の予測
- 現在の支出ペースで計算した明日の日割り額
- 今日の予算より増加 → 緑（節約成功）
- 今日の予算より減少 → 赤（使いすぎ）
- サイクル最終日は「今月もあと1日！」と表示

### 2.3 クイック登録
- よく使う支出パターンを事前登録（`quick_entries`テーブル）
- ワンタップで支出記録（タイトル/金額/カテゴリ/グレード）
- 2行×横スクロール形式で表示
- 長押しで編集モーダル
- 並び替え・削除機能（QuickEntryManageScreen）
- タイトルは任意（未入力時はカテゴリ名を表示）

### 2.4 今日の支出リスト
- 今日登録した支出を時系列表示
- タップで編集/分割/削除のアクションシート

---

## 3. 支出登録（Add）

### 3.1 金額入力（ホイールピッカー）
- ホイール式で金額を直感的に入力
- 単位切り替え: 10円 / 100円 / 1000円 / 1万 / 10万 / 100万
- 上限金額: 1000万円（全単位共通）
- リセットボタン（↻）: 金額を0円に戻す
- 単位切り替え時も金額を保持（リセットされない）
- スマートコンボ選択時は金額に応じて最適な単位を自動選択

### 3.2 グレード選択（3段階）
| グレード | 意味 | 色 |
|---------|------|-----|
| 節約 | 我慢・代替・安い選択 | 緑 |
| 標準 | 普通の支出 | 青 |
| ご褒美 | 自分へのご褒美・贅沢 | オレンジ |

### 3.3 カテゴリ選択
- 食費、日用品、交通費、趣味・娯楽、交際費、衣服・美容、健康、その他
- カテゴリ別の分析に使用

### 3.4 スマートコンボ
- カテゴリ選択後、過去の頻出（金額×グレード）組み合わせをチップ表示
- SQL集計で頻度順に取得（`getSmartCombos()`）
- タップで金額とグレードを自動入力
- グレード別にグループ化表示

### 3.5 メモ（任意）
- 自由テキストで詳細記録
- 履歴画面の検索対象

### 3.6 内訳機能（任意）
- 1つの支出を複数のカテゴリに分割して登録
- 例: 700円の「買い物」→ 130円「コーヒー」+ 80円「食料品」+ 490円「買い物」（残り）
- 合計金額は親金額と同額（増減しない）
- 内訳ごとに異なるカテゴリ・支出タイプを設定可能
- バリデーション: 内訳合計が親金額を超えるとエラー表示
- 保存時: 親は保存せず、内訳+残り分を独立した支出として保存

---

## 4. 履歴画面（History）

### 4.1 タイムライン表示
- サイクル開始日から今日まで全日程を縦表示
- 支出がない日も「記録なし」として表示
- 2カラム構成: 日付 | 支出内容

### 4.2 支出詳細
- 各支出にグレード色のアイコン表示
- 金額、カテゴリ、メモを表示

### 4.3 検索機能
- カテゴリ名/メモで絞り込み
- 検索中はフラットリスト表示

### 4.4 支出編集
- タップでアクションシート表示
- 編集: 金額/グレード/カテゴリ/メモを修正
- 分割: 1件を複数件に分割
- 削除: 支出を削除

---

## 5. 分析画面（Analytics）

### 5.1 今サイクルのまとめ
- サイクル期間（例: 1/25〜2/24）を表示
- 支出合計（変動費 + 固定費）
- 残りの使える金額

### 5.2 消費ペースグラフ（バーンレート）
- **Premiumのみ**
- X軸: サイクル日数、Y軸: 消費率(%)
- 今サイクル線（青・実線）と比較線（グレー・破線）
- 比較線の種類:
  - 前サイクルデータあり（記録日数3日以上）: 前サイクルの実績線
  - 前サイクルデータなし: 理想ライン（均等消費）
- 100%超 = 予算オーバー
- グラフ上部に前サイクル比較バッジ表示:
  - 節約中（緑）: `前サイクル比 -¥5,000（節約中）`
  - 使いすぎ（オレンジ）: `前サイクル比 +¥3,000（使いすぎ）`
- `startDay`パラメータで記録開始前の日付はスキップ

### 5.3 月間の支出推移
- **Freeで利用可能**
- 12ヶ月の月別支出をグレード別積み上げ棒グラフで表示
- 横スクロール対応（左固定Y軸）
- 最新月に自動スクロール
- 凡例: 節約（緑）/ 標準（青グレー）/ ご褒美（ゴールド）
- タップでツールチップ（月名 + 合計金額）
- 固定費は含まない（変動費のみ）
- 実装メソッド:
  - `AppState.getMonthlyExpenseTrend({months: 12})`: 月別グレード集計取得
  - `DatabaseService.getMonthlyGradeBreakdownAll({months})`: SQL集計
- ウィジェット: `MonthlyExpenseTrendChart` (`lib/widgets/analytics/monthly_expense_trend_chart.dart`)

### 5.4 日割り・週割りペース
- **Premiumのみ**
- カテゴリ別の日割り/週割り支出額
- 支出総額降順でソート

### 5.5 家計の余白
- **Premiumのみ**
- ペースバッファ（余剰額）の表示
  - 計算式: `予算ペース - 実支出`
  - アニメーション付きカウントアップ表示
- 格上げカテゴリ提案（最大3件）
  - 条件: バッファ > 0 かつ 標準/ご褒美 各1件以上
  - 全期間のご褒美上位から選択
  - カード表示: カテゴリ名、標準平均、ご褒美平均、差額、可能回数
  - タップでカテゴリ詳細画面へ遷移（Hero アニメーション）

### 5.6 カテゴリ別支出
- **Premiumのみ**
- 円グラフでカテゴリ比率を可視化（fl_chart使用）
- 固定費込み/抜き切り替えトグル
- 各セグメントタップでカテゴリ詳細画面へ遷移
- カテゴリ別の支出額リスト（降順ソート）

---

## 6. 設定画面（Settings）

### 6.1 家計設定
- 家計の開始日（給料日）変更
- カテゴリ管理（CategoryManageScreenへ遷移）

### 6.2 アプリ情報
- バージョン表示
- プラン表示（Free / Premium）

### 6.3 開発者オプション（Dev Only）
- バージョン10回タップで解放
- Premium override（強制ON/OFF）
- Releaseビルドでは非表示

---

## 7. カテゴリ管理（CategoryManageScreen）

### 7.1 アクセス方法
- 設定画面の「カテゴリ管理」から遷移
- Add画面のカテゴリセクション「編集」ボタンから遷移

### 7.2 機能
- カテゴリ一覧表示
- カテゴリの並び替え（ドラッグ＆ドロップ）
- カテゴリの追加・編集・削除
- デフォルトカテゴリの保護（削除不可）

---

## 8. 固定費管理

### 8.1 固定費一覧（Home）
- 登録済み固定費をリスト表示
- 合計額を自動計算

### 8.2 固定費登録
- 項目名、金額、カテゴリを入力
- カテゴリ: 住居、光熱費、通信、保険、サブスク、その他

### 8.3 固定費編集/削除
- タップで編集モーダル
- 削除ボタンで削除

---

## 9. データ管理

### 9.1 ローカルDB（SQLite） - Version 8
- **expenses**: 支出データ（id, amount, category, grade, memo, created_at, parent_id）
- **categories**: カテゴリマスタ（id, name, sort_order, is_default, icon）
- **budgets**: 予算（id, amount, year, month）※ UNIQUE (year, month)
- **fixed_cost_categories**: 固定費カテゴリマスタ
- **fixed_costs**: 固定費データ（category_name_snapshot保存）
- **quick_entries**: クイック登録テンプレート（title, category, amount, grade, memo, sort_order）
- **daily_budgets**: 日別固定予算（date PK, fixed_amount）
- **cycle_incomes**: サイクル別収入（cycle_key, main_income, sub_income, sub_income_name）

インデックス:
- `idx_expenses_created_at`: 日付範囲クエリ最適化
- `idx_expenses_category_created_at`: カテゴリ×日付集計最適化
- `idx_cycle_incomes_cycle_key`: サイクル別収入取得最適化

### 9.2 SharedPreferences
- 給料日設定（main_salary_day）
- Premium状態（store_premium）
- 開発者モード設定（dev_premium_override）

---

## 10. FinancialCycle（給料日サイクル）

### 10.1 サイクル計算
- 給料日から翌給料日前日までを1サイクルとして管理
- 月末日が存在しない月は自動調整（31日設定で2月→28/29日）

### 10.2 サイクルキー
- フォーマット: `cycle_YYYY_MM_DD`（開始日ベース）
- 予算・収入データの紐付けに使用

### 10.3 日数計算
- 残り日数: 今日からサイクル終了日まで（今日含む）
- 経過日数: サイクル開始日から今日まで

---

## 11. Premium機能

### 11.1 Free版で使える機能
- 今日使えるお金の表示
- 支出登録（グレード/カテゴリ/メモ）
- 履歴閲覧・検索
- 固定費管理
- クイック登録
- 今サイクルのまとめ（支出合計のみ）

### 11.2 Premium限定機能
- 消費ペースグラフ
- 日割り・週割りペース分析
- 家計の余白計算
- カテゴリ別円グラフ

---

## 12. 収入管理システム（実装済み）

### 12.1 cycle_incomes テーブル
- `id`: 主キー
- `cycle_key`: サイクル識別子（例: `cycle_2025_01_25`）※給料日ベース
- `main_income`: メイン収入（給料）
- `sub_income`: サブ収入合計（Refill）
- `sub_income_name`: サブ収入の名前（将来の複数対応用）
- `created_at`: 登録日時
- インデックス: `idx_cycle_incomes_cycle_key`

### 12.2 収入登録UI（income_sheet.dart）
- メイン収入（給料）: 1サイクルに1件、更新可能
- サブ収入（補填・ボーナス等）: 追加・削除可能
- 収入合計をリアルタイム表示
- サイクル期間を表示（例: 2025/01/25 〜 2025/02/24）
- AppStateから`getMainIncome()` / `getSubIncomes()`で取得

### 12.3 DB一元管理
- 予算データはSharedPreferencesからDBへ移行済み
- `thisMonthAvailableAmount`はDBの収入合計（main + sub）から計算
- 収入変更時に今日の固定予算を自動再計算（`_recalculateTodayAllowance()`）

### 12.4 Refill機能
- サブ収入追加時に日割り額が自動再計算
- フロー: `addSubIncome()` → `_reloadCycleIncome()` → `_recalculateTodayAllowance()`
- 残り日数で可処分金額を再配分

---

## 13. 前サイクル比較機能（Phase 3-A 実装済み）

### 13.1 FinancialCycle拡張
- `getPreviousCycleKey()`: 前サイクルのキーを取得
- `getPreviousCycleStartDate()`: 前サイクルの開始日を取得
- `getPreviousCycleEndDate()`: 前サイクルの終了日を取得
- `getPreviousCycleTotalDays()`: 前サイクルの総日数を取得

### 13.2 サイクル別支出集計（DatabaseService）
- `getDailyExpensesByCycle()`: 指定期間の日ごとの支出合計を取得
- `getTotalExpensesByCycle()`: 指定期間の支出合計を取得

### 13.3 前サイクルデータ取得（AppState）
- `getPreviousCycleBurnRateData()`: 前サイクルの累積支出率を計算
  - 返り値: `{ rates, startDay, totalDays, income, disposable, totalExpenses }`
  - 記録日数3日以上で比較線表示
- `getCycleComparisonDiff()`: 今サイクルと前サイクルの同時点での差額を計算
  - 正の値 = 今サイクルの方が支出が少ない（節約中）
  - 負の値 = 今サイクルの方が支出が多い（使いすぎ）

### 13.4 支出ペースグラフ（BurnRateChart）
- **今サイクル線**: 青の実線
- **前サイクル線**: グレーの点線（記録日数3日以上で表示）
- **理想線**: グレーの点線（前サイクルデータがない場合のフォールバック）
- 凡例: 「今サイクル」「前サイクル」または「理想」

### 13.5 前サイクル比較バッジ
- 前サイクル同時点との差額を表示
- 節約中（緑）: `前サイクル比 -¥5,000（節約中）`
- 使いすぎ（オレンジ）: `前サイクル比 +¥3,000（使いすぎ）`
- グラフ上部に表示

### 13.6 日数補間
- サイクル日数が異なる場合でも正確に比較
- 進捗率ベースの補間: `prevEquivalentDay = progress * prevTotalDays`

### 13.7 実装メソッド（AppState）
- `getPreviousCycleBurnRateData()`: 前サイクルのバーンレートデータ取得
  - 返り値: `{ rates: List<double>, startDay: int, totalDays: int, income: int, disposable: int, totalExpenses: int }`
  - 記録日数3日未満の場合はnull
- `getCycleComparisonDiff()`: 前サイクル同時点との差額を計算
  - 正の値 = 今サイクルの方が支出少ない（節約中）
  - 負の値 = 今サイクルの方が支出多い（使いすぎ）

---

## 14. 全履歴表示機能（Phase 3-B 実装済み）

### 14.1 DatabaseService拡張
- `getAllExpensesPaged(limit, offset)`: 全支出をページネーションで取得
- `getAllExpensesCount()`: 全支出の総件数を取得
- `searchExpensesPaged(query, limit, offset)`: 全期間検索（ページネーション対応）
- `searchExpensesCount(query)`: 検索結果の総件数を取得

### 14.2 履歴画面の全期間開放
- 現在のサイクルに限定されていた表示制限を撤廃
- 全履歴をスクロールで閲覧可能
- ヘッダーに「全 N 件」と総件数を表示

### 14.3 サイクル境界ヘッダー
- サイクルの変わり目に境界線（ヘッダー）を表示
- フォーマット: `YYYY/MM/DD 〜 YYYY/MM/DD`
- 表示条件: `HeaderVisible(i) = true if i=0 or CycleKey(i) ≠ CycleKey(i-1)`
- 青系のアクセントカラーでスタイリング

### 14.4 無限スクロール（Lazy Loading）
- 初回ロード: 50件
- スクロール末尾200px手前で追加ロード
- ローディングインジケーター表示
- `_hasMore`フラグで追加ロード可否を管理

### 14.5 全期間検索
- 検索対象: カテゴリ名・メモ（部分一致）
- 検索結果もページネーション対応
- 検索結果にもサイクル境界ヘッダーを表示
- 検索結果件数をUIに表示

### 14.6 UI変更点
- 検索バーのヒントテキスト: 「カテゴリ・メモで検索（全期間）」
- 日付表示: 月初日と今日に「○月」ラベルを追加
- ボトムシートに日付表示を追加（過去データの編集時に分かりやすく）
- 削除・編集後は履歴リストも自動リロード
- ヘッダーに「全 N 件」と総件数を表示

### 14.7 分割機能（SplitModal）
- 履歴から支出をタップ → 「この支出を切り出す」を選択
- 分割先のカテゴリと金額を指定
- 元の支出は減額、新しい支出を作成（parent_id で紐付け）
- 分割後は履歴リストを自動更新

---

## 15. カテゴリ詳細分析（Category Detail Screen）（実装済み）

### 15.1 概要
- **Premiumのみ**
- カテゴリ別の詳細な支出分析画面
- 円グラフのカテゴリタップまたは格上げカテゴリカードから遷移

### 15.2 MBTI風3セグメントバー
- 節約/標準/ご褒美の比率を3セグメントで可視化
- グレードカラー（緑/青/オレンジ）で色分け
- ラベル表示閾値: 8%以上のセグメントのみ表示

### 15.3 表示モード切り替え
- 回数モード: 各グレードの支出回数を表示
- 金額モード: 各グレードの合計金額を表示
- トグルボタンで切り替え可能

### 15.4 今月のデータ
- グレード別集計（金額、回数、平均）
- 今月の合計金額・合計回数

### 15.5 過去6ヶ月の平均比較
- グレード別の6ヶ月平均（金額・回数・平均）
- 今月と比較して増減を確認

### 15.6 月別トレンドチャート
- 12ヶ月の月別支出を横スクロール表示
- 積み上げ棒グラフ（グレード別色分け）
- 現在月に自動スクロール
- 0円の月も表示（0埋め対応）
- SQL集計による高速化（`getMonthlyGradeBreakdown()`）

### 15.7 実装メソッド（AppState）
- `getCategoryDetailAnalysis(categoryName)`: カテゴリ詳細分析データ取得
  - 返り値: `{ thisMonth: {...}, last6MonthsAvg: {...}, totalAmount: int, totalCount: int }`
- `getCategoryMonthlyTrend(categoryName, {months: 12})`: 月別トレンド取得
  - 0埋め対応（`generateMonthKeys()`で月キー生成）
  - 返り値: `[{ month: 'YYYY-MM', monthLabel: 'M月', saving: int, standard: int, reward: int, total: int }, ...]`

---

## 16. ホーム画面時間別テーマ & Night Reflection（実装済み）

### 16.1 HeroCard 時間別テーマ
HeroCard（`lib/widgets/home/hero_card.dart`）は時間帯に応じて3つのビジュアルモードを切り替え:

| モード | 時間帯 | 背景スタイル |
|--------|--------|-------------|
| Day | 4:00〜5:59, 10:00〜18:59 | 白背景（標準） |
| Morning | 6:00〜9:59 | 暖色グラデーション（オレンジ/イエロー） |
| Night | 19:00〜3:59 | ダークネイビー背景（#1E2340） |

- 時間別テーマは**純粋なビジュアル変更**
- Night Reflection機能とは独立（夜テーマ ≠ 振り返り可能）

### 16.2 HeroCard 共通表示
全モード共通で「今日使えるお金」をメイン表示:
- 金額（大きなフォント）
- 明日の予測（節約成功で緑、使いすぎで赤）
- サイクル最終日は「今月もあと1日！」

### 16.3 Night Reflection（夜の振り返り）
- 1日1回の振り返り体験機能
- SharedPreferencesで開封状態を管理（`reflection_opened_YYYY-MM-DD`）
- HeroCardタップで振り返りダイアログを表示
- ウィジェット: `NightReflectionDialog` (`lib/widgets/night_reflection_dialog.dart`)

### 16.4 振り返りダイアログ（NightReflectionDialog）
- `showGeneralDialog`で表示（モーダル）
- 背景: 0.85暗転（ダークネイビー #1A1F3C）
- アニメーション: 300msのフェード + 下から上への微細スライド（offsetY: 0.02）
- コンテンツ:
  - 🌙 アイコン + 「今日のふりかえり」タイトル
  - 今日の総支出（`appState.todayTotal`）
  - 明日の予算（日割り）（`dynamicTomorrowForecast`）を大きく表示
  - 条件別メッセージ:
    - 支出0円: 「今日はお金を使わない日でした。素晴らしい！」
    - 支出あり: 「今日もお疲れさま。明日はこの金額を目安にいこう。」
- 閉じるボタンのみ（戻るボタン/×ボタンなし）

### 16.5 スタイリング定数
`lib/config/home_constants.dart`:
- 背景色: screenBackground (#F7F7F5)
- カード背景: cardBackground (white)
- 夜カード背景: nightCardBackground (#1E2340)
- 角丸: heroCardRadius (16.0)
- 金額フォントサイズ: heroAmountSize (48.0) / heroAmountSizeNight (42.0)

---

## 17. AppState 主要メソッド一覧

### 17.1 支出・固定費 CRUD（全て Future<bool> を返す）
```dart
addExpense(Expense)              // 支出追加
updateExpense(Expense)           // 支出更新
deleteExpense(int id)            // 支出削除
splitExpense(int id, int splitAmount, String newCategory, {String? grade})  // 支出分割

addFixedCost(FixedCost)          // 固定費追加
updateFixedCost(FixedCost)       // 固定費更新
removeFixedCost(int id)          // 固定費削除

addQuickEntry(QuickEntry)        // クイック登録追加
updateQuickEntry(QuickEntry)     // クイック登録更新
deleteQuickEntry(int id)         // クイック登録削除
executeQuickEntry(QuickEntry)    // クイック登録実行（支出作成）
```

### 17.2 収入管理
```dart
Future<Map<String, dynamic>?> getMainIncome()
  // 返り値: { 'amount': int, 'cycleKey': String }

Future<List<Map<String, dynamic>>> getSubIncomes()
  // 返り値: [{ 'name': String, 'amount': int }, ...]

Future<void> setMainIncome(int amount)      // メイン収入設定
Future<void> addSubIncome(String name, int amount)   // サブ収入追加
Future<void> removeSubIncome(String name)   // サブ収入削除
```

### 17.3 カテゴリ分析
```dart
// カテゴリ別グレード内訳（今月）
Map<String, Map<String, int>> getCategoryGradeBreakdown(String categoryName)
  // 返り値: { 'saving': {'amount': int, 'count': int, 'avg': int}, 'standard': {...}, 'reward': {...} }

// カテゴリ詳細分析（今月 + 6ヶ月平均）
Map<String, dynamic> getCategoryDetailAnalysis(String categoryName)
  // 返り値: { 'thisMonth': {...}, 'last6MonthsAvg': {...}, 'totalAmount': int, 'totalCount': int }

// 月別トレンド（12ヶ月、0埋め対応）
Future<List<Map<String, dynamic>>> getCategoryMonthlyTrend(String categoryName, {int months = 12})
  // 返り値: [{ 'month': 'YYYY-MM', 'monthLabel': 'M月', 'saving': int, 'standard': int, 'reward': int, 'total': int }, ...]

// 月間支出推移（全カテゴリ、グレード別積み上げ）
Future<List<Map<String, dynamic>>> getMonthlyExpenseTrend({int months = 12})
  // 返り値: [{ 'month': 'YYYY-MM', 'monthLabel': 'M月', 'saving': int, 'standard': int, 'reward': int, 'total': int }, ...]

// 格上げ可能カテゴリ（最大3件）
List<Map<String, dynamic>> getUpgradeCategories()
  // 返り値: [{ 'category': String, 'diff': int, 'possibleCount': int, 'standardAvg': int, 'rewardAvg': int }, ...]
  // 条件: buffer > 0 && 標準1件以上 && ご褒美1件以上
```

### 17.4 サイクル・予算系ゲッター
```dart
DateTime get cycleStartDate           // サイクル開始日
DateTime get cycleEndDate             // サイクル終了日
String get currentCycleKey            // 'cycle_YYYY_MM_DD'
List<DateTime> get cycleAllDates      // サイクル開始〜今日の全日程（降順）

int? get thisMonthAvailableAmount     // 今月の使える金額（収入合計）
int? get disposableAmount             // 可処分金額（収入 - 固定費）
int? get fixedTodayAllowance          // 今日の固定額（日割り、日中不変）
int? get dynamicTomorrowForecast      // 明日の予測（支出で変動）
int? get paceBuffer                   // 余裕額（予算ペース - 実支出）

int get thisMonthTotal                // 変動費合計
int get todayTotal                    // 今日の支出合計
int get thisWeekTotal                 // 今週の支出合計
int get fixedCostsTotal               // 固定費合計
bool get isLastDayOfMonth             // サイクル最終日判定
int get remainingDaysInMonth          // 残り日数（今日含む）
```

### 17.5 バーンレート・前サイクル比較
```dart
Future<Map<String, dynamic>?> getPreviousCycleBurnRateData()
  // 返り値: { 'rates': List<double>, 'startDay': int, 'totalDays': int, 'income': int, 'disposable': int, 'totalExpenses': int }
  // 記録日数3日未満の場合はnull

Future<int?> getCycleComparisonDiff()
  // 返り値: 前サイクル比較差額（正=節約中, 負=使いすぎ）
```

### 17.6 スマートコンボ予測
```dart
Future<List<Map<String, dynamic>>> getSmartCombos(String category)
  // 返り値: [{ 'amount': int, 'grade': String, 'frequency': int }, ...]
  // SQL集計で頻度順に取得
```

### 17.7 タブ・UI制御
```dart
void requestTabChange(int tabIndex)           // タブ切り替えリクエスト
void requestOpenIncomeSheet()                 // 分析タブ + IncomeSheet自動起動

int? consumeRequestedTabIndex()               // タブリクエスト消費
bool consumeOpenIncomeSheetRequest()          // IncomeSheetリクエスト消費
```

### 17.8 部分リロード（パフォーマンス最適化）
```dart
_reloadExpenses()               // 支出のみリロード
_reloadCategories()             // カテゴリのみリロード
_reloadFixedCosts()             // 固定費のみリロード
_reloadFixedCostCategories()    // 固定費カテゴリのみリロード
_reloadBudget()                 // 予算のみリロード
_reloadQuickEntries()           // クイック登録のみリロード
_reloadCycleIncome()            // 収入のみリロード
```

---

## 18. 主要な実装パターン

### 18.1 エラーハンドリング
```dart
final success = await appState.addExpense(expense);
if (!success) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('保存に失敗しました'), backgroundColor: AppColors.accentRed),
  );
}
```

### 18.2 FinancialCycle の使用
```dart
// サイクル内判定
final inCycle = _financialCycle.isDateInCurrentCycle(expense.createdAt, DateTime.now());

// サイクルキー取得
final cycleKey = _financialCycle.getCycleKey(DateTime.now());
```

### 18.3 Hero アニメーション（カテゴリ遷移）
```dart
Hero(
  tag: 'category_$categoryName',
  flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: categoryColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  },
  child: /* カテゴリカード */,
)
```

### 18.4 FutureBuilder の活用
```dart
// バーンレートチャートで前サイクルデータ取得
FutureBuilder<Map<String, dynamic>?>(
  future: appState.getPreviousCycleBurnRateData(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      // 前サイクルデータを使用
    }
    // ...
  },
)
```

---

## 19. Premium機能と制限

### 19.1 Premium判定
- ロジック: `context.watch<AppState>().isPremium`
- 優先順位: `_devPremiumOverride ?? _storePremium`
- 開発者モード: バージョン10回タップで解放（DEV_TOOLS=true時のみ）

### 19.2 Free版で使える機能
- ホーム画面の全表示（今日使えるお金、明日の予測、クイック登録、固定費）
- 支出登録（グレード/カテゴリ/メモ）
- 履歴閲覧・検索（全期間）
- 支出編集・分割・削除
- 固定費管理
- クイック登録管理
- 収入管理（メイン + Refill）
- Night Reflection
- 今サイクルのまとめ（支出合計のみ）

### 19.3 Premium専用機能
- AnalyticsScreen の全セクション（展開可能）
  - カテゴリ別支出（円グラフ）
  - 日割り・週割りペース分析
  - 支出ペース（バーンレートチャート）
  - 家計の余白（格上げカテゴリ提案）
- CategoryDetailScreen（カテゴリ詳細分析）
  - MBTI風3セグメントバー
  - 月別トレンドチャート（12ヶ月）

---

## 20. 既知の制限事項 / 未実装項目

### 20.1 AnalyticsScreen の「詳細」セクション
- ダミーコンテンツのみ
- 今後の拡張予定

### 20.2 複数の Refill（副収入）管理
- テーブル構造は対応（`sub_income_name`）
- UI は現在 1 つのみ表示（拡張可能）

### 20.3 カスタム期間選択
- 固定で給料日ベースのサイクル
- カスタム期間選択は未実装

### 20.4 高度な支出予測
- 基本的な日割り計算のみ
- 機械学習ベースの予測は未実装
