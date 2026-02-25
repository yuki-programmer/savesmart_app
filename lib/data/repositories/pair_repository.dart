import '../../models/pair.dart';

abstract class PairRepository {
  Future<Pair> createPair();
  Stream<Pair?> watchPair();
  Future<void> leavePair({required bool copyToLocal});
  Future<void> updatePlusState();
}
