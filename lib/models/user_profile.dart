import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? displayName;
  final String? pairId;
  final bool isPlus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.pairId,
    required this.isPlus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      pairId: data['pairId'] as String?,
      isPlus: (data['isPlus'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeServerTimestamps = false}) {
    return {
      'displayName': displayName,
      'pairId': pairId,
      'isPlus': isPlus,
      if (includeServerTimestamps) 'createdAt': FieldValue.serverTimestamp(),
      if (includeServerTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'displayName': displayName,
      'pairId': pairId,
      'isPlus': isPlus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
