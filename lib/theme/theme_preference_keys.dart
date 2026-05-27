// Autor principal: Pedro Henrique Contardi Soler
// RA: 25005592
//
// Chaves e valores usados com [shared_preferences] para guardar a preferência
// de tema entre sessões (cache local no dispositivo).

/// Nome da chave no armazenamento local (string serializada: light / dark / system).
abstract final class ThemePreferenceKeys {
  /// Chave única no [SharedPreferences] — não alterar após publicar (perde-se a preferência antiga).
  static const String storageKey = 'mescla_theme_mode';

  /// Valor guardado quando o usuário escolhe tema claro (Material [Brightness.light]).
  static const String valueLight = 'light';

  /// Valor guardado para tema escuro ([Brightness.dark]).
  static const String valueDark = 'dark';

  /// Valor guardado para seguir o [MediaQuery.platformBrightness] do SO.
  static const String valueSystem = 'system';
}
