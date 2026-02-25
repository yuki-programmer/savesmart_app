import 'package:cloud_firestore/cloud_firestore.dart';

class PairInvite {
  final String code;
  final String pairId;
  final String createdBy;
  final DateTime expiresAt;
  final String? usedBy;
  final DateTime? usedAt;

  const PairInvite({
    required this.code,
    required this.pairId,
    required this.createdBy,
    required this.expiresAt,
    required this.usedBy,
    required this.usedAt,
  });

  factory PairInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PairInvite(
      code: doc.id,
      pairId: data['pairId'] as String,
      createdBy: data['createdBy'] as String,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      usedBy: data['usedBy'] as String?,
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pairId': pairId,
      'createdBy': createdBy,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
    };
  }
}
