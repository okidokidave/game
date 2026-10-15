import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:gold_mine/scene/mine_scene.dart';
import 'package:gold_mine/ui/title_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<GameController> newGame() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return GameController(SaveRepository(prefs));
  }

  testWidgets('메인 화면에서 출발하면 게임 화면으로 넘어간다', (tester) async {
    final game = await newGame();
    await tester.binding.setSurfaceSize(const Size(360, 740));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    await tester.pump();

    expect(find.byType(TitleScreen), findsOneWidget);
    expect(find.text('골드 광산'), findsWidgets);
    expect(find.byType(MineScene), findsNothing);

    await tester.tap(find.text('⛏ 광산으로 출발!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    game.stop();

    expect(find.byType(TitleScreen), findsNothing);
    expect(find.byType(MineScene), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('진행 중인 게임이 있으면 이어하기로 보인다', (tester) async {
    final game = await newGame();
    game.grantBonusGold(1234);
    await tester.binding.setSurfaceSize(const Size(320, 616));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    await tester.pump();

    expect(find.text('⛏ 이어서 채굴하기'), findsOneWidget);
    expect(find.textContaining('1.23K'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
