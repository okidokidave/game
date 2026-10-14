import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:gold_mine/scene/mine_layout.dart';
import 'package:gold_mine/scene/mine_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final before = game.gold;
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byType(MineScene));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.gold - before, closeTo(10, 1e-9));

    final hireButton = find.widgetWithText(FilledButton, '10');
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
    expect(find.textContaining('연장'), findsOneWidget);

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
    // 광산 장면은 스크롤되지만, 한눈에 한 층 이상은 보여야 한다.
    final mine = tester.getSize(find.byType(MineScene));
    expect(mine.height, greaterThanOrEqualTo(150));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('보통 크기 폰에서는 지상과 첫 층이 함께 보인다', (tester) async {
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
        (MineLayout.surfaceHeight + MineLayout.floorHeight) * scale,
      ),
    );
    await tester.binding.setSurfaceSize(null);
  });
}
