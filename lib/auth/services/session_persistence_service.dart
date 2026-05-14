import 'package:shared_preferences/shared_preferences.dart';

import '../../navigation/mescla_tab_count.dart';

/// Persistência leve da sessão: prazo de validade (24h após login) e última aba do shell.
///
/// Regras de produto:
/// * Processo morto (cold start): o [AuthGateScreen] faz sign-out Firebase e remove só o
///   prazo, mantendo o índice da última aba para restaurar após o próximo login.
/// * Sair explicitamente: limpa tudo, incluindo a última aba.
/// * App em memória: o [DashboardScreen] verifica o prazo ao voltar do background.
class SessionPersistenceService {
  SessionPersistenceService._();

  static const String _deadlineKey = 'mescla_session_deadline_ms';
  static const String _lastNavKey = 'mescla_last_nav_index';

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
  }

  /// Remove prazo e última aba (logout explícito ou encerramento de sessão completo).
  static Future<void> clearSessionMetadata() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deadlineKey);
    await prefs.remove(_lastNavKey);
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

  static Future<void> setLastNavIndex(int index) async {
    if (index < 0 || index >= kMesclaMainTabCount) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastNavKey, index);
  }

  static Future<int> getLastNavIndex() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int raw = prefs.getInt(_lastNavKey) ?? 0;
    return raw.clamp(0, kMesclaMainTabCount - 1);
  }
}
