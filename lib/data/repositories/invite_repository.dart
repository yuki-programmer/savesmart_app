import '../../models/pair_invite.dart';

abstract class InviteRepository {
  Future<PairInvite> createInvite();
  Future<void> acceptInvite(String code);
  Future<void> revokeInvite(String code);
}
