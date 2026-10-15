import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mine_event_test.dart' show ScriptedRandom, rollFor;

void main() {
  late DateTime now;
  late ScriptedRandom random;
  late GameController game;
  late List<String> messages;

  final apprentice = GameConfig.workerGrades[0];
  final skilled = GameConfig.workerGrades[1];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1);
    random = ScriptedRandom();
    messages = [];
    final prefs = await SharedPreferences.getInstance();
    game = GameController(
      SaveRepository(prefs),
      clock: () => now,
      random: random,
    );
    game.onMessage = messages.add;
  });

  test('새 인부는 견습이고, 일한 시간만큼 경험치가 쌓인다', () {
    expect(game.gradeOf(0).name, '견습');
    game.tick(10);
    expect(game.xpOf(0), closeTo(10, 1e-9));
    expect(game.isPromotionReady(0), isFalse);
  });

  test('경험치는 다음 등급에 필요한 만큼까지만 차고, 반장에게 알린다', () {
    game.tick(apprentice.xpToPromote! + 1000);
    expect(game.xpOf(0), apprentice.xpToPromote);
    expect(game.isPromotionReady(0), isTrue);
    expect(game.promotionReadyCount, 1);
    expect(messages.single, contains('승급할 준비'));
  });

  test('골드를 내고 승급하면 생산량이 오르고 경험치는 처음부터', () {
    game.tick(apprentice.xpToPromote!);
    game.grantBonusGold(game.promotionCost(0));
    final before = game.steadyGoldPerSecond;
    final gold = game.gold;
    final cost = game.promotionCost(0);

    expect(game.promote(0), isTrue);
    expect(game.gold, closeTo(gold - cost, 1e-9));
    expect(game.gradeOf(0).name, '숙련');
    expect(game.xpOf(0), 0);
    expect(
      game.steadyGoldPerSecond,
      closeTo(before / apprentice.multiplier * skilled.multiplier, 1e-9),
    );
    expect(game.baseGoldPerSecond, closeTo(game.steadyGoldPerSecond, 1e-9));
  });

  test('경험치가 덜 찼거나 골드가 모자라면 승급할 수 없다', () {
    game.grantBonusGold(1e9);
    expect(game.promote(0), isFalse); // 경험치 부족

    SharedPreferences.setMockInitialValues({});
    game.tick(apprentice.xpToPromote!);
    // tick이 번 골드보다 비용이 크도록, 가진 골드를 다 써 버린다.
    while (game.hireWorker()) {}
    if (game.gold < game.promotionCost(0)) {
      expect(game.canPromote(0), isFalse);
      expect(game.promote(0), isFalse);
    }
  });

  test('마지막 등급은 더 오르지 않는다', () {
    for (var g = 0; g < GameConfig.workerGrades.length - 1; g++) {
      game.tick(game.xpNeeded(0)!);
      game.grantBonusGold(game.promotionCost(0));
      expect(game.promote(0), isTrue);
    }
    expect(game.gradeOf(0).name, '장인');
    expect(game.xpNeeded(0), isNull);
    game.tick(1e6);
    expect(game.isPromotionReady(0), isFalse);
  });

  test('지친 인부는 경험치가 천천히, 다친 인부는 안 쌓인다', () {
    game.grantBonusGold(GameConfig.eventsStartAfterEarned);
    random.doubles.add(0);
    random.ints.addAll([rollFor(MineEventType.fatigue), 0]);
    game.updateEvents(1);
    final xp0 = game.xpOf(0);
    game.tick(10);
    expect(game.xpOf(0) - xp0, closeTo(10 * GameConfig.fatigueSpeed, 1e-9));

    advanceToInjury() {
      now = now.add(GameConfig.fatigueToInjury);
      game.updateEvents(0);
    }

    advanceToInjury();
    expect(game.workerEvent(0, 0)!.type, MineEventType.injury);
    final xp1 = game.xpOf(0);
    game.tick(10);
    expect(game.xpOf(0), xp1);
  });

  test('오프라인 동안에도 효율만큼 경험치가 쌓인다', () async {
    await game.save(now);
    game.collectOfflineEarnings(now.add(const Duration(minutes: 2)));
    expect(game.xpOf(0), closeTo(120 * GameConfig.offlineEfficiency, 1e-6));
  });

  test('새로 고용한 인부는 견습부터, 등급과 경험치가 저장된다', () async {
    game.tick(apprentice.xpToPromote!);
    game.grantBonusGold(1e6);
    game.promote(0);
    game.hireWorker();
    expect(game.gradeOf(1).name, '견습');
    await game.save(now);

    final prefs = await SharedPreferences.getInstance();
    final loaded = GameController(SaveRepository(prefs), clock: () => now);
    expect(loaded.gradeOf(0).name, '숙련');
    expect(loaded.gradeOf(1).name, '견습');
  });

  test('등급이 없던 예전 저장은 모두 견습으로 불러온다', () async {
    SharedPreferences.setMockInitialValues({
      'gold_mine_save_v1': jsonEncode({'gold': 5, 'workers': 4}),
    });
    final prefs = await SharedPreferences.getInstance();
    final old = GameController(SaveRepository(prefs));
    expect(old.workers, 4);
    for (var s = 0; s < 4; s++) {
      expect(old.gradeOf(s).name, '견습');
      expect(old.xpOf(s), 0);
    }
  });

  test('인부 이름은 층과 순서로 정한다', () {
    expect(GameController.workerLabel(0), 'B1-1');
    expect(GameController.workerLabel(4), 'B2-2');
    expect(GameController.slotOf(1, 1), 4);
  });

  testWidgets('인부 관리 창에서 승급시킨다', (tester) async {
    game.tick(apprentice.xpToPromote!);
    game.grantBonusGold(1e6);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(GoldMineApp(controller: game, ads: NoAdService()));
    game.stop();

    await tester.tap(find.byTooltip('인부 관리'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('B1-1  견습'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.textContaining('승급 '),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.gradeOf(0).name, '숙련');
    expect(find.textContaining('B1-1  숙련'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
