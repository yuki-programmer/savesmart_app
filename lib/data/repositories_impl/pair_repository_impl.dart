import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pair.dart';
import '../../services/auth_service.dart';
import '../pair_data_exporter.dart';
import '../remote/firestore_client.dart';
import '../remote/firestore_paths.dart';
import '../repositories/pair_repository.dart';
import '../repositories/user_repository.dart';

class PairRepositoryImpl implements PairRepository {
  final AuthService _auth;
  final FirebaseFirestore _db;
  final UserRepository _userRepository;
  final PairDataExporter _pairDataExporter;

  PairRepositoryImpl({
    AuthService? authService,
    FirestoreClient? firestoreClient,
    required UserRepository userRepository,
    PairDataExporter? pairDataExporter,
  })  : _auth = authService ?? AuthService.instance,
        _db = (firestoreClient ?? FirestoreClient()).db,
        _userRepository = userRepository,
        _pairDataExporter = pairDataExporter ?? NoopPairDataExporter();

  CollectionReference<Map<String, dynamic>> get _pairs =>
      _db.collection(FirestorePaths.pairs);

  DocumentReference<Map<String, dynamic>> _pairDoc(String pairId) =>
      _pairs.doc(pairId);

  @override
  Future<Pair> createPair() async {
    final uid = _auth.currentUid;
    final me = await _userRepository.getMe();

    final docRef = _pairs.doc();
    final bool plusActive = me.isPlus;
    final String? plusOwnerUid = me.isPlus ? uid : null;

    await _db.runTransaction((tx) async {
      tx.set(docRef, {
        'memberUids': [uid],
        'plusActive': plusActive,
        'plusOwnerUid': plusOwnerUid,
        'plusGraceUntil': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(
        _db.collection(FirestorePaths.users).doc(uid),
        {
          'pairId': docRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });

    final created = await docRef.get();
    return Pair.fromDoc(created);
  }

  @override
  Stream<Pair?> watchPair() {
    return _userRepository.watchMe().asyncExpand((me) {
      final pairId = me.pairId;
      if (pairId == null) {
        return Stream<Pair?>.value(null);
      }
      return _pairDoc(pairId)
          .snapshots()
          .map((doc) => doc.exists ? Pair.fromDoc(doc) : null);
    });
  }

  @override
  Future<void> leavePair({required bool copyToLocal}) async {
    final uid = _auth.currentUid;
    final me = await _userRepository.getMe();
    final pairId = me.pairId;
    if (pairId == null) return;

    if (copyToLocal) {
      await _pairDataExporter.exportPairToLocal(pairId);
    }

    await _db.runTransaction((tx) async {
      final pairDoc = await tx.get(_pairDoc(pairId));
      if (!pairDoc.exists) {
        tx.update(
          _db.collection(FirestorePaths.users).doc(uid),
          {
            'pairId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        return;
      }

      final data = pairDoc.data() ?? {};
      final memberUids = List<String>.from(data['memberUids'] ?? const <String>[]);
      memberUids.remove(uid);

      final currentPlusOwner = data['plusOwnerUid'] as String?;
      final bool isPlusOwnerLeaving = currentPlusOwner == uid;

      DateTime? graceUntil;
      if (isPlusOwnerLeaving) {
        graceUntil = DateTime.now().add(const Duration(hours: 24));
      }

      tx.update(_pairDoc(pairId), {
        'memberUids': memberUids,
        'plusOwnerUid': isPlusOwnerLeaving ? null : currentPlusOwner,
        'plusGraceUntil':
            graceUntil != null ? Timestamp.fromDate(graceUntil) : data['plusGraceUntil'],
        'plusActive': isPlusOwnerLeaving ? true : data['plusActive'],
      });

      tx.update(
        _db.collection(FirestorePaths.users).doc(uid),
        {
          'pairId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  @override
  Future<void> updatePlusState() async {
    final me = await _userRepository.getMe();
    final pairId = me.pairId;
    if (pairId == null) return;

    final pairDoc = await _pairDoc(pairId).get();
    if (!pairDoc.exists) return;

    final data = pairDoc.data() ?? {};
    final memberUids = List<String>.from(data['memberUids'] ?? const <String>[]);
    if (memberUids.isEmpty) return;

    final userDocs = await _db
        .collection(FirestorePaths.users)
        .where(FieldPath.documentId, whereIn: memberUids)
        .get();

    String? plusOwnerUid;
    bool plusActive = false;
    for (final doc in userDocs.docs) {
      final isPlus = (doc.data()['isPlus'] as bool?) ?? false;
      if (isPlus) {
        plusActive = true;
        plusOwnerUid ??= doc.id;
      }
    }

    await _pairDoc(pairId).update({
      'plusActive': plusActive,
      'plusOwnerUid': plusOwnerUid,
      'plusGraceUntil': null,
    });
  }
}
