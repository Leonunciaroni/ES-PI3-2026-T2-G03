import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFirestoreService {
  UserFirestoreService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference<Map<String, dynamic>> _usersCollection =
      _firestore.collection('users');

  /// Se `true`, o login exige o passo de OTP (2FA). Persistido em `users/{uid}`.
  static const String fieldTwoFactorEnabled = 'twoFactorEnabled';
  static const String fieldFavoriteStartupIds = 'favoriteStartupIds';

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
        fieldTwoFactorEnabled: true,
        fieldFavoriteStartupIds: <String>[],
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

  /// Preferência de 2FA no login: `true` = envia OTP; `false` = entra direto.
  ///
  /// Documento inexistente ou campo ausente [fieldTwoFactorEnabled]: `true` (comportamento atual).
  /// Em falha de rede ou permissões Firestore, devolve `true` para não saltar 2FA por engano.
  static Future<bool> isTwoFactorLoginEnabled() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return true;
    }
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) {
        return true;
      }
      final v = snap.data()?[fieldTwoFactorEnabled];
      if (v is bool) {
        return v;
      }
    } on FirebaseException {
      // Rede / permissões: manter 2FA ativo por defeito (mais seguro que entrar sem OTP).
      return true;
    } catch (_) {
      // Estado inesperado: mesmo default conservador que o fluxo histórico.
      return true;
    }
    // Campo presente mas não é bool: tratar como ausente (default seguro).
    return true;
  }

  /// Atualiza preferência de 2FA do utilizador autenticado em `users/{uid}`.
  static Future<void> setTwoFactorLoginEnabled(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    await _usersCollection.doc(uid).set(
      {fieldTwoFactorEnabled: enabled},
      SetOptions(merge: true),
    );
  }

  /// Emite o valor atualizado de [fieldTwoFactorEnabled] (default `true`).
  static Stream<bool> watchTwoFactorLoginEnabled() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<bool>.value(true);
    }
    return _usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return true;
      }
      final v = snap.data()?[fieldTwoFactorEnabled];
      if (v is bool) {
        return v;
      }
      return true;
    });
  }

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

  /// IDs Firestore das startups favoritas do utilizador autenticado.
  static Future<List<String>> fetchFavoriteStartupIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const <String>[];
    }
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) {
        return const <String>[];
      }
      final raw = snap.data()?[fieldFavoriteStartupIds];
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  /// Stream de favoritos para atualizar UI em tempo real.
  static Stream<List<String>> watchFavoriteStartupIds() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<List<String>>.value(const <String>[]);
    }
    return _usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return const <String>[];
      }
      final raw = snap.data()?[fieldFavoriteStartupIds];
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    });
  }

  static Future<bool> isStartupFavorited(String startupId) async {
    final id = startupId.trim();
    if (id.isEmpty) {
      return false;
    }
    final ids = await fetchFavoriteStartupIds();
    return ids.contains(id);
  }

  /// Adiciona/remove favorito no documento do utilizador.
  static Future<void> setStartupFavorite({
    required String startupId,
    required bool favorite,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    final id = startupId.trim();
    if (id.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'startupId inválido.',
      );
    }
    await _usersCollection.doc(uid).set({
      fieldFavoriteStartupIds: favorite
          ? FieldValue.arrayUnion(<String>[id])
          : FieldValue.arrayRemove(<String>[id]),
    }, SetOptions(merge: true));
  }
}
