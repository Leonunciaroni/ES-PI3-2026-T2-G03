import 'package:shared_preferences/shared_preferences.dart';

/// Persistência leve da sessão: prazo de validade (24h após login).
///
/// Regras de produto:
/// * Cold start: o [AuthGateScreen] faz sign-out Firebase e remove o prazo.
/// * Sair explicitamente: limpa o prazo (`clearSessionMetadata`).
/// * App em memória: o [DashboardScreen] verifica o prazo ao voltar do background.
///
/// Abertura pós-login: sempre na aba inicial (Dashboard / Início), sem restaurar
/// última tab do shell.
class SessionPersistenceService {
  SessionPersistenceService._();

  static const String _deadlineKey = 'mescla_session_deadline_ms';

  /// Chave antiga (restauração de tab); removida em cold start / logout.
  static const String _legacyLastNavKey = 'mescla_last_nav_index';

  /// Duração da sessão “quente” após autenticação bem sucedida.
  static const Duration sessionDuration = Duration(hours: 24);

  static Future<void> recordSessionAfterLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int deadline = DateTime.now()
        .add(sessionDuration)
        .millisecondsSinceEpoch;
    await prefs.setInt(_deadlineKey, deadline);
  }

  /// Remove só o prazo (usado no cold start após sign-out Firebase).
  static Future<void> clearSessionDeadline() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deadlineKey);
    await prefs.remove(_legacyLastNavKey);
  }

  /// Remove prazo (logout explícito ou encerramento de sessão completo).
  static Future<void> clearSessionMetadata() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deadlineKey);
    await prefs.remove(_legacyLastNavKey);
  }

  static Future<bool> hasSessionDeadline() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_deadlineKey);
  }

  static Future<bool> isRecordedSessionValid() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? d = prefs.getInt(_deadlineKey);
    if (d == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch < d;
  }
}
