import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  Admin({
    required this.uid,
    this.email,
    this.createdAt,
    this.permissions = const [],
  });

  final String uid;
  final String? email;
  final DateTime? createdAt;
  final List<String> permissions; // List of permission strings (e.g., ['manage_reports', 'manage_bans'])

  factory Admin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final permissionsData = data['permissions'] as List<dynamic>? ?? [];
    return Admin(
      uid: doc.id,
      email: data['email'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      permissions: permissionsData.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'permissions': permissions,
    };
  }
}

