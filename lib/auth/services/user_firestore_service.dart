import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../carteira/models/pix_chave_ui.dart';
import 'biometric_enrollment_storage.dart';
import 'session_persistence_service.dart';

class UserFirestoreService {
  UserFirestoreService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Em `flutter test` sem [Firebase.initializeApp], [FirebaseAuth.instance] falha.
  static FirebaseAuth? _tryAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static final CollectionReference<Map<String, dynamic>> _usersCollection =
      _firestore.collection('users');

  /// Se `true`, o login exige o passo de OTP (2FA). Persistido em `users/{uid}`.
  static const String fieldTwoFactorEnabled = 'twoFactorEnabled';

  /// `true` = novo registo ainda não concluiu a verificação inicial de e-mail + telefone.
  /// Após o primeiro onboarding, deve ficar `false`. Documentos antigos sem este campo
  /// tratam-se como já concluídos ([isFirstAccessPending] é false).
  static const String fieldFirstAccess = 'firstAccess';

  /// Canal do segundo fator: [mfaDeliveryEmail] (callable + e-mail) ou [mfaDeliverySms] (Firebase Phone).
  static const String fieldMfaDeliveryMethod = 'mfaDeliveryMethod';

  /// Valores gravados em [fieldMfaDeliveryMethod] (strings estáveis para Firestore).
  static const String mfaDeliveryEmail = 'email';
  static const String mfaDeliverySms = 'sms';

  static const String fieldFavoriteStartupIds = 'favoriteStartupIds';
  static const String fieldInvestorStartupIds = 'investorStartupIds';

  /// Lista de chaves PIX (`tipo`, `valor`, `apelido`, `id`) em `users/{uid}`.
  static const String fieldChavesPix = 'chavesPix';

  /// Preferência: utilizador quer desbloquear o app com biometria (Face ID / digital).
  static const String fieldBiometricEnabled = 'biometricEnabled';

  /// Última vez que entrou com biometria (metadado; auditoria simples).
  static const String fieldLastBiometricLoginAt = 'lastBiometricLoginAt';

  /// Marca o aparelho como confiável quando o utilizador activa a biometria aqui.
  static const String fieldTrustedDevice = 'trustedDevice';

  /// Remove o campo legado `password` do documento `users/{uid}`.
  ///
  /// **Problema resolvido (login):** após `signInWithEmailAndPassword` bem-sucedido
  /// no Firebase Auth, o código antigo fazia uma **consulta** à coleção
  /// `users` com `where('emailLowercase', …)`. Com regras Firestore típicas
  /// (acesso só a `users/{uid}` quando `request.auth.uid == uid`), essa query
  /// gerava `PERMISSION_DENIED` nos logs. O erro era um [FirebaseException],
  /// não [FirebaseAuthException], pelo que o [AuthService.messageForError] na
  /// [LoginScreen] mostrava apenas *«Não foi possível concluir a operação agora.»*
  /// mesmo com sessão Auth válida.
  ///
  /// **Correção:** usar só leitura/escrita em `users/{uid}` após autenticação e
  /// envolver em `try/catch` para a migração legada nunca bloquear o fluxo.
  static Future<void> _removeLegacyPasswordFieldForUid(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data != null && data.containsKey('password')) {
        await doc.reference.update({'password': FieldValue.delete()});
      }
    } on FirebaseException {
      // Rede / permissões — não impedir cadastro ou sessão Auth.
    } catch (_) {
      // Idem.
    }
  }

  static Future<void> createUserWithEmailAndPassword({
    required String name,
    required String email,
    required String phone,
    required String cpf,
    required String password,

    /// [mfaDeliveryEmail] ou [mfaDeliverySms] — define o canal de OTP quando o 2FA está ligado.
    required String mfaDeliveryMethod,
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
        fieldMfaDeliveryMethod: mfaDeliveryMethod == mfaDeliverySms
            ? mfaDeliverySms
            : mfaDeliveryEmail,
        fieldFavoriteStartupIds: <String>[],
        fieldInvestorStartupIds: <String>[],
        fieldChavesPix: <Map<String, dynamic>>[],
        fieldFirstAccess: true,
        fieldBiometricEnabled: false,
      }, SetOptions(merge: true));

      await _removeLegacyPasswordFieldForUid(uid);

      // Mantém a sessão Firebase Auth: o fluxo continua no app (OTP e-mail → telefone).
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

  /// Indica se o utilizador autenticado ainda deve passar pelo ecrã de primeiro acesso
  /// (validar e-mail no Auth e telefone com SMS).
  static Future<bool> isFirstAccessPending() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return false;
    }
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) {
        return false;
      }
      final v = snap.data()?[fieldFirstAccess];
      return v is bool && v;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Marca o onboarding inicial como concluído (`firstAccess: false`).
  static Future<void> markFirstAccessCompleted() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    await _usersCollection.doc(uid).set({
      fieldFirstAccess: false,
    }, SetOptions(merge: true));
  }

  /// Login com e-mail/senha; em seguida remove eventual campo legado `password`
  /// só em `users/{uid}` (nunca por query na coleção — ver
  /// [_removeLegacyPasswordFieldForUid]).
  static Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    // Limpeza legado só no doc do utilizador (evita query à coleção — ver doc de
    // [_removeLegacyPasswordFieldForUid]).
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _removeLegacyPasswordFieldForUid(uid);
    }
  }

  /// Encerra a sessão no Firebase Auth (ex.: botão Sair do Perfil).
  static Future<void> signOut() async {
    await BiometricEnrollmentStorage.clearEnrollment();
    await SessionPersistenceService.clearSessionMetadata();
    await _auth.signOut();
  }

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
    await _usersCollection.doc(uid).set({
      fieldTwoFactorEnabled: enabled,
    }, SetOptions(merge: true));
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

  /// Lê [fieldBiometricEnabled]; documento antigo sem campo ⇒ `false`.
  static Future<bool> fetchBiometricEnabled() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) return false;
      final v = snap.data()?[fieldBiometricEnabled];
      return v is bool && v;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Emite alterações a [fieldBiometricEnabled] em tempo real (default `false`).
  static Stream<bool> watchBiometricEnabled() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<bool>.value(false);
    }
    return _usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return false;
      final v = snap.data()?[fieldBiometricEnabled];
      return v is bool && v;
    });
  }

  /// Grava a preferência de biometria e, se activa, marca dispositivo confiável.
  static Future<void> setBiometricEnabled(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    await _usersCollection.doc(uid).set({
      fieldBiometricEnabled: enabled,
      fieldTrustedDevice: enabled,
    }, SetOptions(merge: true));
  }

  /// Actualiza só o horário do último login por biometria (servidor).
  static Future<void> recordLastBiometricLoginNow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _usersCollection.doc(uid).set({
        fieldLastBiometricLoginAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Falha de rede: não bloqueia o fluxo de UI.
    } catch (_) {}
  }

  /// Lê o campo [fieldMfaDeliveryMethod] uma vez (por omissão [mfaDeliveryEmail]).
  static Future<String> fetchMfaDeliveryMethod() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return mfaDeliveryEmail;
    }
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) {
        return mfaDeliveryEmail;
      }
      return _parseMfaDeliveryMethod(snap.data()?[fieldMfaDeliveryMethod]);
    } on FirebaseException {
      return mfaDeliveryEmail;
    } catch (_) {
      return mfaDeliveryEmail;
    }
  }

  /// Normaliza o valor bruto do Firestore para [mfaDeliveryEmail] ou [mfaDeliverySms].
  static String _parseMfaDeliveryMethod(Object? raw) {
    if (raw is! String) {
      return mfaDeliveryEmail;
    }
    final v = raw.trim().toLowerCase();
    if (v == mfaDeliverySms) {
      return mfaDeliverySms;
    }
    return mfaDeliveryEmail;
  }

  /// Emite alterações ao método MFA (default [mfaDeliveryEmail]).
  static Stream<String> watchMfaDeliveryMethod() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream<String>.value(mfaDeliveryEmail);
    }
    return _usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        return mfaDeliveryEmail;
      }
      return _parseMfaDeliveryMethod(snap.data()?[fieldMfaDeliveryMethod]);
    });
  }

  /// Grava o canal MFA em `users/{uid}` (apenas `email` ou `sms`).
  static Future<void> setMfaDeliveryMethod(String method) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    final normalized = method.trim().toLowerCase() == mfaDeliverySms
        ? mfaDeliverySms
        : mfaDeliveryEmail;
    await _usersCollection.doc(uid).set({
      fieldMfaDeliveryMethod: normalized,
    }, SetOptions(merge: true));
  }

  /// Dígitos do telefone gravados em `users/{uid}.phone` (cadastro), só números; `null` se ausente.
  static Future<String?> fetchProfilePhoneDigits() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    try {
      final snap = await _usersCollection.doc(uid).get();
      if (!snap.exists) {
        return null;
      }
      final raw = snap.data()?['phone'];
      if (raw is! String || raw.trim().isEmpty) {
        return null;
      }
      return raw.replaceAll(RegExp(r'\D'), '');
    } catch (_) {
      return null;
    }
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
    final auth = _tryAuth();
    final uid = auth?.currentUser?.uid;
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
    final auth = _tryAuth();
    final uid = auth?.currentUser?.uid;
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

  // --- Chaves PIX em `users/{uid}.chavesPix` ----------------------------------
  //
  // O cliente substitui o **array inteiro** (sem Cloud Function): regras já
  // permitem update ao dono do documento.

  static List<PixChaveUi> _parseChavesPixList(Object? raw) {
    if (raw is! List) return const <PixChaveUi>[];
    final out = <PixChaveUi>[];
    for (final e in raw) {
      final c = PixChaveUi.tryFromFirestore(e);
      if (c != null) out.add(c);
    }
    return out;
  }

  /// Emite a lista atual de chaves PIX do utilizador autenticado.
  static Stream<List<PixChaveUi>> watchChavesPix() {
    final auth = _tryAuth();
    final uid = auth?.currentUser?.uid;
    if (uid == null) {
      return Stream<List<PixChaveUi>>.value(const <PixChaveUi>[]);
    }
    return _usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return const <PixChaveUi>[];
      return _parseChavesPixList(snap.data()?[fieldChavesPix]);
    });
  }

  /// Grava a lista completa (substitui o campo [fieldChavesPix]).
  static Future<void> saveChavesPix(List<PixChaveUi> chaves) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão não encontrada.',
      );
    }
    final maps = chaves.map((c) => c.toFirestoreMap()).toList(growable: false);
    await _usersCollection.doc(uid).set({
      fieldChavesPix: maps,
    }, SetOptions(merge: true));
  }
}
