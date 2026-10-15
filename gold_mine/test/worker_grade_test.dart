import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/game/shop.dart';
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

  /// 체력이 줄지 않게 비타민을 먹인다 (테스트 시계가 멈춰 있어 효과가 계속된다).
  void noFatigue() {
    game.grantBonusGold(game.itemCost(Shop.vitamin));
    expect(game.buyItem(Shop.vitamin), isTrue);
    expect(game.useItem(Shop.vitamin), isTrue);
    messages.clear();
  }

  test('새 인부는 견습이고, 일한 시간만큼 경험치가 쌓인다', () {
    noFatigue();
    expect(game.gradeOf(0).name, '견습');
    game.tick(10);
    expect(game.xpOf(0), closeTo(10, 1e-9));
    expect(game.isPromotionReady(0), isFalse);
  });

  test('경험치는 다음 등급에 필요한 만큼까지만 차고, 소장에게 알린다', () {
    noFatigue();
    game.tick(apprentice.xpToPromote! + 1000);
    expect(game.xpOf(0), apprentice.xpToPromote);
    expect(game.isPromotionReady(0), isTrue);
    expect(game.promotionReadyCount, 1);
    expect(messages.single, contains('승급할 준비'));
  });

  test('골드를 내고 승급하면 생산량이 오르고 경험치는 처음부터', () {
    noFatigue();
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
    noFatigue();
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
    noFatigue();
    for (var g = 0; g < GameConfig.workerGrades.length - 1; g++) {
      game.tick(game.xpNeeded(0)!);
      game.grantBonusGold(game.promotionCost(0));
      expect(game.promote(0), isTrue);
    }
    expect(game.gradeOf(0).name, '반장');
    expect(game.xpNeeded(0), isNull);
    game.tick(1e6);
    expect(game.isPromotionReady(0), isFalse);
  });

  /// [slot] 인부를 [grade] 등급까지 올린다 (다른 인부도 경험치는 같이 받음).
  void raise(int slot, int grade) {
    while (game.gradeIndexOf(slot) < grade) {
      game.tick(game.xpNeeded(slot)!);
      game.grantBonusGold(1e9);
      expect(game.promote(slot), isTrue);
    }
  }

  test('반장은 층마다 한 명만 둘 수 있다', () {
    noFatigue();
    game.grantBonusGold(1e9);
    while (game.workers < 6) {
      game.upgradeMine();
      game.hireWorker();
    }
    final foreman = GameConfig.foremanGrade;
    raise(0, foreman); // B1-1 반장
    expect(game.foremanOnFloor(0), 0);

    raise(1, foreman - 1); // B1-2 베테랑
    game.tick(game.xpNeeded(1)!);
    expect(game.isBlockedByForeman(1), isTrue);
    expect(game.isPromotionReady(1), isFalse);
    expect(game.promote(1), isFalse);

    raise(3, foreman); // B2에는 따로 반장을 둘 수 있다
    expect(game.foremanOnFloor(1), 3);
  });

  test('반장이 있는 층의 인부들은 경험치가 빨리 쌓인다', () {
    noFatigue();
    game.grantBonusGold(1e9);
    raise(0, GameConfig.foremanGrade);
    // 반장을 세운 뒤에 새로 고용한 인부들 (경험치 0부터)
    game.grantBonusGold(1e12);
    game.upgradeMine();
    while (game.workers < 4) {
      expect(game.hireWorker(), isTrue);
    }
    final b1 = game.xpOf(1);
    final b2 = game.xpOf(3);
    game.tick(10);
    expect(game.xpOf(1) - b1, closeTo(10 * GameConfig.foremanXpBoost, 1e-9));
    expect(game.xpOf(3) - b2, closeTo(10, 1e-9));
  });

  test('다친 인부는 경험치가 쌓이지 않는다', () {
    noFatigue();
    game.grantBonusGold(GameConfig.eventsStartAfterEarned);
    random.doubles.add(0);
    random.ints.addAll([rollFor(MineEventType.injury), 0]);
    game.updateEvents(1);
    expect(game.workerEvent(0, 0)!.type, MineEventType.injury);
    final xp = game.xpOf(0);
    game.tick(10);
    expect(game.xpOf(0), xp);
  });

  test('지친 인부는 경험치가 절반 속도로 쌓인다', () {
    // 경험치가 다 차기 전에 지치도록, 체력을 미리 깎아 둔 새 인부로 확인한다.
    game.grantBonusGold(1e6);
    game.hireWorker();
    game.tick(
      (GameConfig.maxStamina - GameConfig.tiredStamina) /
              GameConfig.staminaDrainPerSecond +
          1,
    );
    expect(game.isTired(0), isTrue);
    // 견습 경험치(300)는 이미 다 찼으니 승급시킨 뒤 잰다.
    game.grantBonusGold(1e9);
    expect(game.promote(0), isTrue);
    final xp = game.xpOf(0);
    game.tick(10);
    expect(game.xpOf(0) - xp, closeTo(10 * GameConfig.fatigueSpeed, 1e-6));
  });

  test('오프라인 동안에도 효율만큼 경험치가 쌓인다', () async {
    noFatigue();
    await game.save(now);
    game.collectOfflineEarnings(now.add(const Duration(minutes: 2)));
    expect(game.xpOf(0), closeTo(120 * GameConfig.offlineEfficiency, 1e-6));
  });

  test('새로 고용한 인부는 견습부터, 등급과 경험치가 저장된다', () async {
    noFatigue();
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
    noFatigue();
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
    noFatigue();
    game.tick(apprentice.xpToPromote!);
    game.grantBonusGold(1e6);

    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      GoldMineApp(showTitle: false, controller: game, ads: NoAdService()),
    );
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
