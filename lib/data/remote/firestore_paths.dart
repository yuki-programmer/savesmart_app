class FirestorePaths {
  static const String users = 'users';
  static const String pairs = 'pairs';
  static const String pairInvites = 'pairInvites';

  static String pairExpenses(String pairId) => 'pairs/$pairId/expenses';
  static String pairBudgets(String pairId) => 'pairs/$pairId/budgets';
  static String pairFixedCosts(String pairId) => 'pairs/$pairId/fixedCosts';
  static String pairScheduledExpenses(String pairId) => 'pairs/$pairId/scheduledExpenses';
  static String pairCategories(String pairId) => 'pairs/$pairId/categories';
}
