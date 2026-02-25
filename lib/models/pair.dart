import 'package:cloud_firestore/cloud_firestore.dart';

class Pair {
  final String id;
  final List<String> memberUids;
  final bool plusActive;
  final String? plusOwnerUid;
  final DateTime? plusGraceUntil;
  final DateTime? createdAt;

  const Pair({
    required this.id,
    required this.memberUids,
    required this.plusActive,
    required this.plusOwnerUid,
    required this.plusGraceUntil,
    required this.createdAt,
  });

  factory Pair.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Pair(
      id: doc.id,
      memberUids: List<String>.from(data['memberUids'] ?? const <String>[]),
      plusActive: (data['plusActive'] as bool?) ?? false,
      plusOwnerUid: data['plusOwnerUid'] as String?,
      plusGraceUntil: (data['plusGraceUntil'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeServerTimestamps = false}) {
    return {
      'memberUids': memberUids,
      'plusActive': plusActive,
      'plusOwnerUid': plusOwnerUid,
      'plusGraceUntil': plusGraceUntil != null ? Timestamp.fromDate(plusGraceUntil!) : null,
      if (includeServerTimestamps) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
