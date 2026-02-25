import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pair_invite.dart';
import '../../services/auth_service.dart';
import '../remote/firestore_client.dart';
import '../remote/firestore_paths.dart';
import '../repositories/invite_repository.dart';
import '../repositories/user_repository.dart';

class InviteRepositoryImpl implements InviteRepository {
  static const int _inviteCodeLength = 6;
  static const int _maxGenerateAttempts = 5;

  final AuthService _auth;
  final FirebaseFirestore _db;
  final UserRepository _userRepository;

  InviteRepositoryImpl({
    AuthService? authService,
    FirestoreClient? firestoreClient,
    required UserRepository userRepository,
  })  : _auth = authService ?? AuthService.instance,
        _db = (firestoreClient ?? FirestoreClient()).db,
        _userRepository = userRepository;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(FirestorePaths.pairInvites);

  String _generateCode() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      _inviteCodeLength,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  Future<PairInvite> createInvite() async {
    final uid = _auth.currentUid;
    final me = await _userRepository.getMe();
    final pairId = me.pairId;
    if (pairId == null) {
      throw StateError('Pair is not created.');
    }

    for (int i = 0; i < _maxGenerateAttempts; i++) {
      final code = _generateCode();
      final docRef = _invites.doc(code);
      final exists = await docRef.get();
      if (exists.exists) continue;

      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      final invite = PairInvite(
        code: code,
        pairId: pairId,
        createdBy: uid,
        expiresAt: expiresAt,
        usedBy: null,
        usedAt: null,
      );

      await docRef.set(invite.toMap());
      return invite;
    }

    throw StateError('Failed to generate invite code.');
  }

  @override
  Future<void> acceptInvite(String code) async {
    final uid = _auth.currentUid;
    final inviteRef = _invites.doc(code);

    await _db.runTransaction((tx) async {
      final inviteDoc = await tx.get(inviteRef);
      if (!inviteDoc.exists) {
        throw StateError('Invite code not found.');
      }

      final invite = PairInvite.fromDoc(inviteDoc);
      if (invite.usedBy != null) {
        throw StateError('Invite code already used.');
      }
      if (invite.expiresAt.isBefore(DateTime.now())) {
        throw StateError('Invite code expired.');
      }

      final pairRef = _db.collection(FirestorePaths.pairs).doc(invite.pairId);
      final pairDoc = await tx.get(pairRef);
      if (!pairDoc.exists) {
        throw StateError('Pair not found.');
      }
      final pairData = pairDoc.data() ?? {};
      final memberUids = List<String>.from(pairData['memberUids'] ?? const <String>[]);
      if (memberUids.length >= 2) {
        throw StateError('Pair is full.');
      }

      tx.update(inviteRef, {
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      memberUids.add(uid);
      tx.update(pairRef, {
        'memberUids': memberUids,
      });

      tx.update(
        _db.collection(FirestorePaths.users).doc(uid),
        {
          'pairId': invite.pairId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Future<void> revokeInvite(String code) async {
    await _invites.doc(code).delete();
  }
}
