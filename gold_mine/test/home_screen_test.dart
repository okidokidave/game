import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:gold_mine/scene/mine_layout.dart';
import 'package:gold_mine/scene/mine_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mine_event_test.dart' show ScriptedRandom, rollFor;

/// 광고를 항상 끝까지 본 것으로 처리하는 가짜 광고.
class FakeAdService implements AdService {
  int shown = 0;

  @override
  final ValueListenable<bool> rewardedReady = ValueNotifier(true);

  @override
  Future<bool> showRewarded() async {
    shown++;
    return true;
  }

  @override
  Widget buildBanner() => const SizedBox(height: 50, child: Text('배너'));
}

Future<GameController> newGame() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GameController(SaveRepository(prefs));
}

void main() {
  testWidgets('광산을 터치하면 골드가 오르고 고용 버튼이 켜진다', (tester) async {
    final game = await newGame();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    // 실시간 진행을 멈추고 터치만으로 확인한다.
    game.stop();

    expect(find.byType(MineScene), findsOneWidget);
    expect(find.text('인부 고용'), findsOneWidget);

    // 첫 인부 값만큼 직접 캔다.
    final taps = GameConfig.workerBaseCost.toInt();
    final before = game.gold;
    for (var i = 0; i < taps; i++) {
      await tester.tap(find.byType(MineScene));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gold - before, closeTo(taps, 1e-9));

    final hireButton = find.widgetWithText(FilledButton, '$taps');
    expect(tester.widget<FilledButton>(hireButton).onPressed, isNotNull);
    await tester.tap(hireButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.workers, 2);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('광고를 보면 채굴 부스트가 켜진다', (tester) async {
    final game = await newGame();
    final ads = FakeAdService();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: ads));
    game.stop();

    expect(find.text('배너'), findsOneWidget);
    await tester.tap(find.textContaining('광고 보고'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(ads.shown, 1);
    expect(game.isBoostActive, isTrue);
    expect(find.textContaining('분 연장'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('소장이 알림을 눌러 다이아몬드를 받는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final random = ScriptedRandom();
    final game = GameController(SaveRepository(prefs), random: random);
    game.grantBonusGold(GameConfig.eventsStartAfterEarned);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    game.stop();

    random.doubles.add(0);
    random.ints.addAll([rollFor(MineEventType.diamond), 0]);
    game.updateEvents(1);
    final diamond = game.managerEvents.single;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('다이아 발견'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('💎 다이아몬드 발견!'), findsOneWidget);

    final before = game.gold;
    await tester.tap(find.widgetWithText(FilledButton, '받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.gold, closeTo(before + diamond.reward, 1e-9));
    expect(game.managerEvents, isEmpty);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('설정에서 처음부터 다시 시작할 수 있다', (tester) async {
    final game = await newGame();
    game.tick(10000);
    game.upgradeMine();

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    game.stop();

    // 화면이 계속 움직여서 pumpAndSettle 대신 시작 프레임과 애니메이션 시간을 따로 진행한다.
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('처음부터 다시 시작'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, '다시 시작'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(game.gold, 0);
    expect(game.mineLevel, 1);
    expect(game.workers, 1);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('작은 화면에서도 넘치지 않고 광산을 터치할 수 있다', (tester) async {
    final game = await newGame();

    // 아주 작은 폰(320x640)에서 상태 표시줄을 뺀 크기.
    await tester.binding.setSurfaceSize(const Size(320, 616));
    await tester.pumpWidget(
      GoldMineApp(controller: game, ads: FakeAdService()),
    );
    game.stop();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // 광산 장면은 스크롤되지만, 작은 폰에서도 지상과 첫 층은 한눈에 보여야 한다.
    final mine = tester.getSize(find.byType(MineScene));
    final scale = 320 / MineLayout.sceneWidth;
    expect(
      mine.height,
      greaterThanOrEqualTo(
        (MineLayout.surfaceHeight + MineLayout.floorHeight) * scale,
      ),
    );
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('보통 크기 폰에서는 지상과 두 층이 함께 보인다', (tester) async {
    final game = await newGame();

    await tester.binding.setSurfaceSize(const Size(360, 740));
    await tester.pumpWidget(
      GoldMineApp(controller: game, ads: FakeAdService()),
    );
    game.stop();
    await tester.pump();

    final mine = tester.getSize(find.byType(MineScene));
    final scale = 360 / MineLayout.sceneWidth;
    expect(
      mine.height,
      greaterThanOrEqualTo(
        (MineLayout.surfaceHeight + MineLayout.floorHeight * 2) * scale,
      ),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
