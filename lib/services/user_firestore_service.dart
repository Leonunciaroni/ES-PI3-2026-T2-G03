import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFirestoreService {
  UserFirestoreService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _usersCollection =
      _firestore.collection('users');

  static Future<void> _removeLegacyPasswordFieldForEmail(
    String normalizedEmail,
  ) async {
    final query = await _usersCollection
        .where('emailLowercase', isEqualTo: normalizedEmail)
        .get();

    for (final doc in query.docs) {
      if (doc.data().containsKey('password')) {
        await doc.reference.update({'password': FieldValue.delete()});
      }
    }
  }

  static Future<void> createUserWithEmailAndPassword({
    required String name,
    required String email,
    required String phone,
    required String cpf,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final uid = credential.user!.uid;

    await _usersCollection.doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim(),
      'emailLowercase': normalizedEmail,
      'phone': phone.trim(),
      'cpf': cpf.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _removeLegacyPasswordFieldForEmail(normalizedEmail);

    // Mantem o fluxo atual da interface: após cadastro, volta para tela de login.
    await _auth.signOut();
  }

  static Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await _removeLegacyPasswordFieldForEmail(normalizedEmail);
  }
}
