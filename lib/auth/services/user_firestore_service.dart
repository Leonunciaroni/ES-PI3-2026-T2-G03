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
    final createdUser = credential.user;
    if (createdUser == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'Não foi possível concluir o cadastro no Firebase Auth.',
      );
    }
    final uid = createdUser.uid;

    try {
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

      // Mantém o fluxo atual da interface: após cadastro, volta para tela de login.
      await _auth.signOut();
    } catch (_) {
      // Evita usuário órfão no Auth caso o perfil em Firestore falhe.
      try {
        await createdUser.delete();
      } catch (_) {
        // Se não conseguir apagar, propagamos o erro original para a UI.
      }
      rethrow;
    }
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

  /// Encerra a sessão no Firebase Auth (ex.: botão Sair do Perfil).
  static Future<void> signOut() => _auth.signOut();

  /// Nome do cadastro em `users/{uid}`; `null` se não houver documento ou em erro
  /// (testes sem Firebase, rede, etc.).
  static Future<String?> fetchNameFromFirestore(String uid) async {
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) return null;
      final n = snap.data()?['name'];
      if (n is String && n.trim().isNotEmpty) {
        return n.trim();
      }
    } catch (_) {
      // Sem Firebase ou falha de rede: o ecrã Perfil usa fallback.
    }
    return null;
  }
}
