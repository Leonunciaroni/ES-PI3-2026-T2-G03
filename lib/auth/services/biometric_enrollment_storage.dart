// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Guardamos **só** o UID para o qual o usuário ativou o desbloqueio biométrico
// neste aparelho. Não são credenciais: a chave biométrica real fica no SO (Keystore / Keychain).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chave usada no armazenamento encriptado local (Android Keystore / iOS Keychain).
class BiometricEnrollmentStorage {
  BiometricEnrollmentStorage._();

  static const String _keyEnrolledUid = 'mescla_biometric_enrolled_uid';

  /// Instância única: `encryptedSharedPreferences` no Android ajuda a persistir com segurança.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Grava que [uid] está autorizado a usar o fluxo biométrico neste dispositivo.
  static Future<void> setEnrolledForUser(String uid) async {
    final t = uid.trim();
    if (t.isEmpty) return;
    await _storage.write(key: _keyEnrolledUid, value: t);
  }

  /// Apaga a marca local (logout, usuário desliga biometria nas configurações, etc.).
  static Future<void> clearEnrollment() async {
    await _storage.delete(key: _keyEnrolledUid);
  }

  /// Lê o UID guardado, se existir.
  static Future<String?> readEnrolledUid() async {
    final v = await _storage.read(key: _keyEnrolledUid);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  /// `true` quando o armazenamento contém exatamente o [uid] da sessão atual.
  static Future<bool> isEnrolledForUser(String uid) async {
    final stored = await readEnrolledUid();
    return stored != null && stored == uid.trim();
  }
}
