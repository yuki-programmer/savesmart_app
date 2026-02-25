import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreClient {
  static final FirestoreClient _instance = FirestoreClient._internal();
  final FirebaseFirestore db;

  factory FirestoreClient() => _instance;

  FirestoreClient._internal() : db = FirebaseFirestore.instance;
}
