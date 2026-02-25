import '../../models/user_profile.dart';

abstract class UserRepository {
  Future<UserProfile> getMe();
  Stream<UserProfile> watchMe();
  Future<void> upsertMe(UserProfile profile);
  Future<void> updatePairId(String? pairId);
  Future<void> updatePlus(bool isPlus);
}
