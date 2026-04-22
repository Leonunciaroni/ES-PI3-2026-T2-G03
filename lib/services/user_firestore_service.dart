import 'package:cloud_firestore/cloud_firestore.dart';

class UserFirestoreService {
  UserFirestoreService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _usersCollection =
      _firestore.collection('users');

  static Future<bool> emailAlreadyExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final query = await _usersCollection
        .where('emailLowercase', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  static Future<void> createUser({
    required String name,
    required String email,
    required String phone,
    required String cpf,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _usersCollection.add({
      'name': name.trim(),
      'email': email.trim(),
      'emailLowercase': normalizedEmail,
      'phone': phone.trim(),
      'cpf': cpf.trim(),
      'password': password,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> validateLogin({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final query = await _usersCollection
        .where('emailLowercase', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final user = query.docs.first.data();
    return user['password'] == password;
  }
}
