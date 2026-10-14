// ============================================================
// ARQUIVO: auth_gate_screen.dart
// AUTOR PRINCIPAL: Miguel Costacurta - 25003110
// ============================================================
//
// ┌─────────────────────────────────────────────────────────┐
// │ MIGUEL, O QUE VOCÊ FEZ AQUI?                            │
// │                                                         │
// │ Este é o "porteiro" do app. É a primeira tela que roda  │
// │ após o splash. Você escreveu a lógica que decide:       │
// │   - Se o usuário vai direto pro desbloqueio biométrico  │
// │   - Ou se vai para o login normal                       │
// │                                                         │
// │ PARA ESTUDAR:                                           │
// │   1. Dart: StatefulWidget e initState()                 │
// │      → Por que usar StatefulWidget aqui?                │
// │      → O que faz initState()?                           │
// │   2. Flutter: async/await em initState (via _bootstrap) │
// │      → Como funciona Future<void> com async/await?      │
// │   3. Firebase: FirebaseAuth.instance.currentUser        │
// │      → Como o Firebase sabe se há usuário logado?       │
// │   4. Arquitetura: por que separar esse "gate" em tela?  │
// └─────────────────────────────────────────────────────────┘

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/biometric_enrollment_storage.dart';
import '../services/session_persistence_service.dart';
import '../services/user_firestore_service.dart';
import 'biometric_unlock_screen.dart';
import 'login_screen.dart';

/// Primeira rota após o splash: na inicialização a frio, por padrão fecha a sessão Firebase
/// para voltar ao login. Se a biometria estiver activa, a sessão de 24h ainda válida
/// e o aparelho inscrito, mantemos o usuário autenticado e mostramos o desbloqueio
/// biométrico.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  // [MIGUEL - ESTUDE] _ready controla se o "check de porteiro" já terminou.
  // Enquanto false, mostra um loading. Isso é um padrão comum em Flutter
  // chamado "splash gate" ou "auth guard".
  // → ESTUDE: setState() e como ele reconstrói o Widget.
  bool _ready = false;

  // [MIGUEL - ESTUDE] Se true, o app pula o login e vai direto para
  // BiometricUnlockScreen. Isso só acontece quando TODAS as condições
  // do _bootstrap() são verdadeiras.
  /// Se `true`, o [BiometricUnlockScreen] substitui o login até ao desbloqueio.
  bool _startWithBiometricUnlock = false;

  static bool _firebaseAvailable() {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _mobileNativeBiometrics() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    // [MIGUEL - ESTUDE] initState() é chamado uma única vez quando o Widget
    // é inserido na árvore. É o lugar certo para iniciar operações assíncronas
    // de setup. Chamar _bootstrap() aqui inicia a verificação de porteiro.
    // → ESTUDE: por que não podemos usar async diretamente no initState?
    // → ESTUDE: o padrão de chamar uma função auxiliar async (aqui: _bootstrap)
    _bootstrap();
  }

  // [MIGUEL - ESTUDE] _bootstrap() é a lógica central do porteiro.
  // Ela responde à pergunta: "O usuário pode entrar pelo atalho biométrico?"
  //
  // CONDIÇÕES para o atalho biométrico (todas precisam ser verdadeiras):
  //   1. Há um usuário logado no Firebase Auth (user != null)
  //   2. É um celular Android ou iOS
  //   3. A sessão de 24h ainda está válida (sessaoQuente)
  //   4. O usuário ativou biometria no Firestore (fetchBiometricEnabled)
  //   5. Esse aparelho específico está inscrito (isEnrolledForUser)
  //
  // → ESTUDE: Future<void> e async/await em Dart
  // → ESTUDE: o operador && (AND) encadenado
  // → ESTUDE: try/catch para tratar erros de Firebase
  Future<void> _bootstrap() async {
    await Future<void>.delayed(Duration.zero);
    if (!_firebaseAvailable()) {
      if (mounted) {
        setState(() => _ready = true);
      }
      return;
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        // [MIGUEL - ESTUDE] FirebaseAuth.instance.currentUser retorna o usuário
        // atualmente logado, ou null se não houver sessão ativa.
        // → Estude: como o Firebase persiste a sessão no dispositivo?
        final User? user = FirebaseAuth.instance.currentUser;

        // [MIGUEL - ESTUDE] isRecordedSessionValid() lê o SharedPreferences local
        // para ver se o login ocorreu nas últimas 24h. Isso é um controle extra
        // porque o Firebase por si só pode manter a sessão indefinidamente.
        final bool sessaoQuente =
            await SessionPersistenceService.isRecordedSessionValid();

        // [MIGUEL - ESTUDE] Este if encadeia 5 condições com &&.
        // Se TODAS forem verdadeiras → atalho biométrico.
        // Se qualquer uma falhar → vai para o login normal.
        if (user != null &&
            _mobileNativeBiometrics() &&
            sessaoQuente &&
            await UserFirestoreService.fetchBiometricEnabled() &&
            await BiometricEnrollmentStorage.isEnrolledForUser(user.uid)) {
          if (mounted) {
            setState(() {
              _ready = true;
              _startWithBiometricUnlock = true;
            });
          }
          return;
        }

        // [MIGUEL - ESTUDE] Esse bloco trata uma inconsistência:
        // O Firestore diz que biometria está ativa, mas o aparelho não tem
        // o enrollment local (ex.: app reinstalado, dados apagados).
        // Solução: desativa a biometria no Firestore automaticamente.
        if (user != null &&
            _mobileNativeBiometrics() &&
            sessaoQuente &&
            await UserFirestoreService.fetchBiometricEnabled() &&
            !await BiometricEnrollmentStorage.isEnrolledForUser(user.uid)) {
          try {
            await UserFirestoreService.setBiometricEnabled(false);
          } catch (_) {
            // Ignorado: usuário seguirá para login; na próxima inicialização pode reconciliar.
          }
        }

        // [MIGUEL - ESTUDE] Se chegou aqui, o atalho biométrico não é possível.
        // signOut() encerra a sessão Firebase para forçar o login normal.
        // → Estude: por que não basta não navegar para o Dashboard?
        // → Por que é importante chamar signOut() ao invés de só ir pro login?
        if (user != null) {
          await FirebaseAuth.instance.signOut();
        }
        await SessionPersistenceService.clearSessionDeadline();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGateScreen] bootstrap: $e');
      }
    }
    if (mounted) {
      setState(() {
        _ready = true;
        _startWithBiometricUnlock = false;
      });
    }
  }

  // [MIGUEL - ESTUDE] build() retorna o Widget visual.
  // Enquanto _ready = false → mostra loading (CircularProgressIndicator).
  // Quando _ready = true:
  //   - _startWithBiometricUnlock = true  → BiometricUnlockScreen
  //   - _startWithBiometricUnlock = false → LoginScreen
  //
  // → ESTUDE: como o Flutter decide quando chamar build() novamente?
  //   R: toda vez que setState() é chamado.
  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_startWithBiometricUnlock) {
      return const BiometricUnlockScreen();
    }
    return const LoginScreen();
  }
}
