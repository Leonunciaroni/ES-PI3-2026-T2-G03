// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Controla o [ThemeMode] do [MaterialApp] e persiste a escolha com [shared_preferences]
// para não relembrar o utilizador a cada abertura do app.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_preference_keys.dart';

/// Única instância usada em todo o app: importe este identificador onde precisar
/// de ler ou alterar o tema (ex.: ecrã "Modo de Aparência", sublinha no Perfil).
final ThemeModeController themeModeController = ThemeModeController();

/// Texto curto em português para mostrar na lista de configurações (Conforme [ThemeMode]).
String mesclaThemeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Claro';
    case ThemeMode.dark:
      return 'Escuro';
    case ThemeMode.system:
      return 'Padrão do sistema';
  }
}

/// Converte a string lida do disco para o enum do Flutter; `null` se for inválido.
ThemeMode? _modeFromStorage(String? value) {
  if (value == null) {
    return null;
  }
  switch (value) {
    case ThemePreferenceKeys.valueLight:
      return ThemeMode.light;
    case ThemePreferenceKeys.valueDark:
      return ThemeMode.dark;
    case ThemePreferenceKeys.valueSystem:
      return ThemeMode.system;
    default:
      return null;
  }
}

/// Serializa [ThemeMode] para gravar no [SharedPreferences].
String _storageStringFor(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return ThemePreferenceKeys.valueLight;
    case ThemeMode.dark:
      return ThemePreferenceKeys.valueDark;
    case ThemeMode.system:
      return ThemePreferenceKeys.valueSystem;
  }
}

/// Notifica os ouvintes ([ListenableBuilder]) quando o modo muda; grava em cache.
class ThemeModeController extends ChangeNotifier {
  /// Valor actual até [load] completar: [ThemeMode.system] alinha com o SO por defeito.
  ThemeMode _mode = ThemeMode.system;

  /// Modo de tema actualmente em vigor no [MaterialApp].
  ThemeMode get themeMode => _mode;

  /// Lê o disco na arranque do app; se não houver valor, mantém [ThemeMode.system].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(ThemePreferenceKeys.storageKey);
    final parsed = _modeFromStorage(stored) ?? ThemeMode.system;
    _mode = parsed;
    notifyListeners();
  }

  /// Aplica o modo, atualiza a UI e grava a string no armazenamento local.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ThemePreferenceKeys.storageKey,
      _storageStringFor(mode),
    );
  }
}
