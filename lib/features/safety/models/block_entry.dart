import 'package:cloud_firestore/cloud_firestore.dart';

class BlockEntry {
  BlockEntry({
    required this.blockerUid,
    required this.blockedUid,
    this.reason,
    this.createdAt,
  });

  final String blockerUid;
  final String blockedUid;
  final String? reason;
  final DateTime? createdAt;

  factory BlockEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final blockerUid = doc.reference.parent.parent?.id ?? '';
    return BlockEntry(
      blockerUid: blockerUid,
      blockedUid: doc.id,
      reason: data['reason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

