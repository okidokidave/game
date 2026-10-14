import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('광산을 터치하면 골드가 오르고 고용 버튼이 켜진다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final game = GameController(SaveRepository(prefs));

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game));
    // 실시간 진행을 멈추고 터치만으로 확인한다.
    game.stop();

    expect(find.text('작은 광산  Lv.1'), findsOneWidget);
    expect(find.text('인부 고용'), findsOneWidget);

    final before = game.gold;
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('⛏️'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.gold - before, closeTo(10, 1e-9));

    final hireButton = find.widgetWithText(FilledButton, '10');
    expect(tester.widget<FilledButton>(hireButton).onPressed, isNotNull);
    await tester.tap(hireButton);
    await tester.pumpAndSettle();
    expect(game.workers, 2);

    await tester.binding.setSurfaceSize(null);
  });
}
