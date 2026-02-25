import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../remote/firestore_client.dart';
import '../remote/firestore_paths.dart';
import '../repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final AuthService _auth;
  final FirebaseFirestore _db;

  UserRepositoryImpl({
    AuthService? authService,
    FirestoreClient? firestoreClient,
  })  : _auth = authService ?? AuthService.instance,
        _db = (firestoreClient ?? FirestoreClient()).db;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return _db.collection(FirestorePaths.users).doc(uid);
  }

  Future<void> _ensureUserDoc(String uid) async {
    final doc = await _docRef(uid).get();
    if (doc.exists) return;
    final displayName = _auth.currentUser?.displayName;
    await _docRef(uid).set({
      'displayName': displayName,
      'pairId': null,
      'isPlus': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<UserProfile> getMe() async {
    final uid = _auth.currentUid;
    await _ensureUserDoc(uid);
    final doc = await _docRef(uid).get();
    return UserProfile.fromDoc(doc);
  }

  @override
  Stream<UserProfile> watchMe() async* {
    final uid = _auth.currentUid;
    await _ensureUserDoc(uid);
    yield* _docRef(uid).snapshots().map(UserProfile.fromDoc);
  }

  @override
  Future<void> upsertMe(UserProfile profile) async {
    await _docRef(profile.uid).set(
      profile.toMap(includeServerTimestamps: true),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updatePairId(String? pairId) async {
    final uid = _auth.currentUid;
    await _docRef(uid).update({
      'pairId': pairId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePlus(bool isPlus) async {
    final uid = _auth.currentUid;
    await _docRef(uid).update({
      'isPlus': isPlus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
