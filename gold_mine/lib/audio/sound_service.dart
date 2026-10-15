import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 게임 효과음 (assets/sounds/*.wav, tool/generate_sounds.py 로 생성).
enum Sfx {
  pick('pick.wav', 0.5),
  coin('coin.wav', 0.25),
  blast('blast.wav', 0.6),
  buy('buy.wav', 0.5),
  fanfare('fanfare.wav', 0.6),
  alert('alert.wav', 0.5),
  sparkle('sparkle.wav', 0.5),
  rare('rare.wav', 0.7),
  pioneer('pioneer.wav', 0.7),
  click('click.wav', 0.4);

  const Sfx(this.file, this.volume);

  final String file;
  final double volume;

  /// 너무 자주 겹쳐 울리지 않게, 같은 소리는 이 간격(초) 안에 한 번만.
  double get minGap => switch (this) {
    Sfx.coin => 0.25,
    Sfx.blast => 0.5,
    Sfx.pick => 0.04,
    _ => 0.1,
  };
}

/// 진동 세기.
enum Buzz { light, medium, heavy }

/// 게임 화면이 쓰는 소리 기능. 테스트에서는 [SilentSoundService]를 쓴다.
abstract class SoundService extends ChangeNotifier {
  bool get sfxOn;
  bool get musicOn;

  void play(Sfx sfx);
  void vibrate(Buzz buzz);

  Future<void> setSfxOn(bool on);
  Future<void> setMusicOn(bool on);

  /// 앱이 백그라운드로 가면 음악을 멈추고, 돌아오면 다시 튼다.
  void pauseMusic();
  void resumeMusic();
}

/// 아무 소리도 내지 않는 구현 (테스트용).
class SilentSoundService extends SoundService {
  final List<Sfx> played = [];

  @override
  bool sfxOn = true;
  @override
  bool musicOn = true;

  @override
  void play(Sfx sfx) {
    if (sfxOn) played.add(sfx);
  }

  @override
  void vibrate(Buzz buzz) {}

  @override
  Future<void> setSfxOn(bool on) async {
    sfxOn = on;
    notifyListeners();
  }

  @override
  Future<void> setMusicOn(bool on) async {
    musicOn = on;
    notifyListeners();
  }

  @override
  void pauseMusic() {}
  @override
  void resumeMusic() {}
}

/// audioplayers 로 실제 소리를 내는 구현.
class GameSoundService extends SoundService {
  GameSoundService(this._prefs)
    : _sfxOn = _prefs.getBool(_sfxKey) ?? true,
      _musicOn = _prefs.getBool(_musicKey) ?? true;

  static const _sfxKey = 'sound_sfx_on';
  static const _musicKey = 'sound_music_on';
  static const _musicVolume = 0.35;

  final SharedPreferences _prefs;
  bool _sfxOn;
  bool _musicOn;
  bool _paused = false;

  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  final AudioPlayer _music = AudioPlayer(playerId: 'bgm');

  @override
  bool get sfxOn => _sfxOn;
  @override
  bool get musicOn => _musicOn;

  /// 효과음을 미리 불러 두고 배경음악을 튼다. 앱 시작 시 한 번 호출한다.
  Future<void> initialize() async {
    try {
      // 효과음이 배경음악을 끊지 않도록 소리를 섞어서 낸다.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      for (final sfx in Sfx.values) {
        _pools[sfx] = await AudioPool.create(
          source: AssetSource('sounds/${sfx.file}'),
          maxPlayers: sfx == Sfx.coin || sfx == Sfx.pick ? 4 : 2,
        );
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVolume);
      await _music.setSource(AssetSource('sounds/bgm_mine.wav'));
      if (_musicOn && !_paused) await _music.resume();
    } catch (e) {
      // 소리가 안 나도 게임은 계속되어야 한다.
      debugPrint('소리 준비 실패: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_sfxOn) return;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null &&
        now.difference(last).inMilliseconds < sfx.minGap * 1000) {
      return;
    }
    _lastPlayed[sfx] = now;
    _pools[sfx]?.start(volume: sfx.volume).catchError((Object e) {
      debugPrint('효과음 재생 실패: $e');
      return () async {};
    });
  }

  @override
  void vibrate(Buzz buzz) {
    if (!_sfxOn) return;
    switch (buzz) {
      case Buzz.light:
        HapticFeedback.selectionClick();
      case Buzz.medium:
        HapticFeedback.mediumImpact();
      case Buzz.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<void> setSfxOn(bool on) async {
    _sfxOn = on;
    await _prefs.setBool(_sfxKey, on);
    notifyListeners();
  }

  @override
  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    await _prefs.setBool(_musicKey, on);
    if (on && !_paused) {
      unawaited(_music.resume());
    } else {
      unawaited(_music.pause());
    }
    notifyListeners();
  }

  @override
  void pauseMusic() {
    _paused = true;
    unawaited(_music.pause());
  }

  @override
  void resumeMusic() {
    _paused = false;
    if (_musicOn) unawaited(_music.resume());
  }
}
