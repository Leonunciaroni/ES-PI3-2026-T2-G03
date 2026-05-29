// Autor: Pedro Henrique Contardi Soler
// RA: 25005592
// Descrição: Envia, remove e resolve URL da foto de perfil no Firebase Storage.
//
// Estrutura no Storage (pastas virtuais — criadas automaticamente no 1.º upload):
//   profilePhoto / users / {uid} / avatar.jpg
//
// Não é preciso criar pastas manualmente no Console: o Firebase cria o “caminho”
// quando fazemos upload para esse endereço.

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Operações de foto de perfil no Firebase Storage.
abstract final class ProfilePhotoStorageService {
  ProfilePhotoStorageService._();

  /// Pasta raiz pedida no projeto.
  static const String pastaRaiz = 'profilePhoto';

  /// Subpasta onde ficam os usuários.
  static const String pastaUsuarios = 'users';

  /// Nome fixo do arquivo (sempre sobrescrevemos o anterior).
  static const String nomeArquivo = 'avatar.jpg';

  /// Monta o caminho completo no Storage para um [uid].
  ///
  /// Exemplo: `profilePhoto/users/abc123/avatar.jpg`
  static String caminhoCompleto(String uid) {
    final id = uid.trim();
    return '$pastaRaiz/$pastaUsuarios/$id/$nomeArquivo';
  }

  /// Referência do Firebase Storage apontando para a foto do usuário.
  static Reference referenciaDaFoto(String uid) {
    return _storage().ref().child(caminhoCompleto(uid));
  }

  /// Envia [arquivoLocal] para o Storage e devolve a **URL de download** (https).
  ///
  /// Passos:
  /// 1. `putFile` grava bytes em `profilePhoto/users/{uid}/avatar.jpg`
  /// 2. `getDownloadURL` gera link público (respeitando as regras de leitura)
  static Future<String> enviarFoto({
    required File arquivoLocal,
    required String uid,
  }) async {
    final ref = referenciaDaFoto(uid);

    // Metadados ajudam o browser/app a tratar o arquivo como imagem JPEG.
    await ref.putFile(
      arquivoLocal,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  /// Apaga a foto do Storage (se existir).
  ///
  /// Se o arquivo já foi removido antes, ignoramos `object-not-found`.
  static Future<void> removerFoto(String uid) async {
    try {
      await referenciaDaFoto(uid).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        return;
      }
      rethrow;
    }
  }

  /// Obtém instância do Storage com o bucket configurado em [firebase_options.dart].
  static FirebaseStorage _storage() {
    try {
      final app = Firebase.app();
      final bucketRaw = app.options.storageBucket;
      if (bucketRaw == null || bucketRaw.isEmpty) {
        return FirebaseStorage.instance;
      }
      final bucket =
          bucketRaw.startsWith('gs://') ? bucketRaw : 'gs://$bucketRaw';
      return FirebaseStorage.instanceFor(app: app, bucket: bucket);
    } catch (_) {
      return FirebaseStorage.instance;
    }
  }
}
