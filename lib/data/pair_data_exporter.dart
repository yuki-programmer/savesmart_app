abstract class PairDataExporter {
  Future<void> exportPairToLocal(String pairId);
}

class NoopPairDataExporter implements PairDataExporter {
  @override
  Future<void> exportPairToLocal(String pairId) async {
    // Intentional no-op. Real implementation will copy Firestore data to SQLite.
  }
}
