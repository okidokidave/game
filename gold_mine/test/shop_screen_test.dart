import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/audio/sound_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/game/shop.dart';
import 'package:gold_mine/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GameController game;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    game = GameController(SaveRepository(prefs));
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 740),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      GoldMineApp(
        showTitle: false,
        dailyPopup: false,
        controller: game,
        ads: NoAdService(),
        sound: SilentSoundService(),
      ),
    );
    game.stop();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('매점에서 물건을 사고, 모두용 물건은 바로 쓴다', (tester) async {
    game.grantBonusGold(1e6);
    await open(tester);
    await tester.tap(find.byTooltip('매점'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('🏪 광산 매점'), findsOneWidget);

    await tester.tap(find.textContaining('사기').at(2)); // 커피
    await tester.pump();
    expect(game.itemCount(Shop.coffee), 1);

    await tester.tap(find.text('사용'));
    await tester.pump();
    expect(game.itemCount(Shop.coffee), 0);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('작은 화면에서도 매점이 넘치지 않는다', (tester) async {
    await open(tester, size: const Size(320, 616));
    await tester.tap(find.byTooltip('매점'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('지친 인부를 눌러 가진 에너지 드링크를 먹인다', (tester) async {
    game.tick((GameConfig.maxStamina - 20) / GameConfig.staminaDrainPerSecond);
    expect(game.isTired(0), isTrue);
    game.grantBonusGold(1e6);
    game.buyItem(Shop.energyDrink);

    await open(tester);
    await tester.tap(find.byTooltip('인부 관리'));
    await settle(tester);
    await tester.tap(find.textContaining('B1-1'));
    await settle(tester);
    expect(find.textContaining('에너지 드링크 먹이기'), findsOneWidget);

    await tester.tap(find.textContaining('에너지 드링크 먹이기'));
    await settle(tester);
    expect(game.isTired(0), isFalse);
    expect(game.itemCount(Shop.energyDrink), 0);
    await tester.binding.setSurfaceSize(null);
  });
}
