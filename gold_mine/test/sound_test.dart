import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/audio/sound_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:gold_mine/scene/mine_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GameController game;
  late SilentSoundService sound;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    game = GameController(SaveRepository(prefs));
    sound = SilentSoundService();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      GoldMineApp(
        showTitle: false,
        dailyPopup: false,
        controller: game,
        ads: NoAdService(),
        sound: sound,
      ),
    );
    game.stop();
    await tester.pump();
  }

  test('모든 효과음과 배경음악 파일이 있다', () {
    for (final sfx in Sfx.values) {
      expect(
        File('assets/sounds/${sfx.file}').existsSync(),
        isTrue,
        reason: sfx.file,
      );
    }
    expect(File('assets/sounds/bgm_mine.wav').existsSync(), isTrue);
  });

  testWidgets('광산을 터치하면 곡괭이 소리가 난다', (tester) async {
    await open(tester);
    await tester.tap(find.byType(MineScene));
    await tester.pump(const Duration(milliseconds: 50));
    expect(sound.played, contains(Sfx.pick));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('인부를 고용하면 구매 소리가 난다', (tester) async {
    game.grantBonusGold(GameConfig.workerBaseCost);
    await open(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, '${GameConfig.workerBaseCost.toInt()}'),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.workers, 2);
    expect(sound.played, contains(Sfx.buy));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('설정에서 효과음을 끄면 소리가 나지 않는다', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('효과음 · 진동'));
    await tester.pump();
    expect(sound.sfxOn, isFalse);

    await tester.tap(find.text('배경음악'));
    await tester.pump();
    expect(sound.musicOn, isFalse);

    Navigator.of(tester.element(find.text('배경음악'))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    sound.played.clear();
    await tester.tap(find.byType(MineScene));
    await tester.pump(const Duration(milliseconds: 50));
    expect(sound.played, isEmpty);
    await tester.binding.setSurfaceSize(null);
  });
}
