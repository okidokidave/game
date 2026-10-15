import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

/// 게임 데이터를 기기에 저장하고 불러온다.
class SaveRepository {
  SaveRepository(this._prefs);

  static const _key = 'influencer_save_v1';
  static const _endingsKey = 'influencer_endings';

  final SharedPreferences _prefs;

  /// 저장된 데이터가 없거나 손상됐으면 null.
  GameState? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GameState state) => _prefs.setString(_key, jsonEncode(state.toJson()));

  Future<void> clear() => _prefs.remove(_key);

  /// 지금까지 본 엔딩 (엔딩 도감)
  List<String> endings() => _prefs.getStringList(_endingsKey) ?? const [];

  Future<void> addEnding(String key) async {
    final seen = endings();
    if (!seen.contains(key)) await _prefs.setStringList(_endingsKey, [...seen, key]);
  }
}
