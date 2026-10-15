import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/regions.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mine_event_test.dart' show ScriptedRandom, rollFor;

void main() {
  late DateTime now;
  late ScriptedRandom random;
  late GameController game;
  late List<String> notices;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1);
    random = ScriptedRandom();
    notices = [];
    final prefs = await SharedPreferences.getInstance();
    game = GameController(
      SaveRepository(prefs),
      clock: () => now,
      random: random,
    );
    game.onEventNotice = (_, message) => notices.add(message);
  });

  /// [index]번 지역까지 개척한다.
  void moveTo(int index) {
    for (var i = 0; i < index; i++) {
      game.grantBonusGold(1e15);
      while (game.upgradeMine()) {}
      while (game.hireWorker()) {}
      expect(game.pioneer(), isTrue);
    }
    game.grantBonusGold(1e9);
  }

  MineEvent spawn(MineEventType type) {
    random.ints.add(rollFor(type));
    game.updateEvents(1);
    final e = game.floorEvent(0);
    expect(e?.type, type);
    return e!;
  }

  void wait(Duration d) {
    now = now.add(d);
    random.doubles.add(0.99); // 새 상황은 생기지 않게
    game.updateEvents(0.001);
  }

  test('첫 지역에는 침수도 귀신도 없다', () {
    expect(Regions.all[0].floods, isFalse);
    expect(Regions.all[0].haunted, isFalse);
    game.grantBonusGold(1e9);
    for (var roll = 0; roll < 200; roll += 7) {
      random.ints.add(roll);
      game.updateEvents(1);
      for (final e in game.events) {
        expect(e.type, isNot(MineEventType.flood));
        expect(e.type, isNot(MineEventType.ghost));
      }
    }
  });

  test('유황 골짜기는 침수되고, 물에 잠긴 층은 느리게 일한다', () {
    moveTo(1);
    expect(game.region.floods, isTrue);
    final before = game.baseGoldPerSecond - game.caretakerIncome;
    spawn(MineEventType.flood);
    expect(notices.last, contains('지하수'));
    expect(game.workerSpeed(0, 0), GameConfig.floodSpeed);
    expect(
      game.baseGoldPerSecond - game.caretakerIncome,
      closeTo(before * GameConfig.floodSpeed, 1e-9),
    );
    // 저절로 빠지지 않는다.
    wait(const Duration(hours: 1));
    expect(game.floorEvent(0)?.type, MineEventType.flood);
  });

  test('양수기를 빌리면 돈을 내고 바로 물이 빠진다', () {
    moveTo(1);
    final e = spawn(MineEventType.flood);
    final gold = game.gold;
    final cost = game.pumpCost;
    expect(game.pumpWater(e.id), isTrue);
    expect(game.gold, closeTo(gold - cost, 1e-6));
    expect(game.floorEvent(0), isNull);
    expect(game.workerSpeed(0, 0), 1);
  });

  test('직접 퍼내면 공짜지만 그동안 그 층은 채굴을 멈춘다', () {
    moveTo(1);
    final e = spawn(MineEventType.flood);
    final gold = game.gold;
    expect(game.bailWater(e.id), isTrue);
    expect(game.gold, gold);
    expect(game.floorEvent(0)?.type, MineEventType.bailing);
    expect(game.workerSpeed(0, 0), 0);
    wait(GameConfig.bailDuration);
    expect(game.floorEvent(0), isNull);
    expect(game.workerSpeed(0, 0), 1);
    expect(notices.last, contains('퍼냈어요'));
  });

  test('버려진 폐광에는 귀신이 나오고, 인부들이 겁에 질려 일을 못 한다', () {
    moveTo(2);
    expect(game.region.name, '버려진 폐광');
    expect(game.region.haunted, isTrue);
    spawn(MineEventType.ghost);
    expect(notices.last, contains('귀신'));
    expect(game.workerSpeed(0, 0), 0);
    expect(game.baseGoldPerSecond, closeTo(game.caretakerIncome, 1e-9));
    // 그냥 두면 떠난다.
    wait(GameConfig.ghostDuration);
    expect(game.floorEvent(0), isNull);
    expect(game.workerSpeed(0, 0), 1);
  });

  test('무당을 부르면 굿을 하고, 끝나면 축복으로 생산이 늘어난다', () {
    moveTo(2);
    final normal = game.baseGoldPerSecond - game.caretakerIncome;
    final e = spawn(MineEventType.ghost);
    final gold = game.gold;
    final cost = game.shamanCost;
    expect(game.callShaman(e.id), isTrue);
    expect(game.gold, closeTo(gold - cost, 1e-6));
    expect(game.floorEvent(0)?.type, MineEventType.exorcism);
    expect(game.workerSpeed(0, 0), 0);

    wait(GameConfig.exorcismDuration);
    expect(game.floorEvent(0)?.type, MineEventType.blessing);
    expect(notices.last, contains('축복'));
    expect(
      game.baseGoldPerSecond - game.caretakerIncome,
      closeTo(normal * GameConfig.blessingMultiplier, 1e-6),
    );

    wait(GameConfig.blessingDuration);
    expect(game.floorEvent(0), isNull);
  });

  test('광고를 보면 양수기도 무당도 공짜', () {
    moveTo(2);
    final ghost = spawn(MineEventType.ghost);
    final gold = game.gold;
    expect(game.callShaman(ghost.id, free: true), isTrue);
    wait(GameConfig.exorcismDuration);
    wait(GameConfig.blessingDuration);
    final flood = spawn(MineEventType.flood);
    expect(game.pumpWater(flood.id, free: true), isTrue);
    expect(game.gold, gold);
  });

  test('침수와 귀신은 저장된다', () async {
    moveTo(1);
    spawn(MineEventType.flood);
    game.save();
    final prefs = await SharedPreferences.getInstance();
    final loaded = GameController(SaveRepository(prefs), clock: () => now);
    expect(loaded.floorEvent(0)?.type, MineEventType.flood);
  });

  test('화면을 한동안 안 만지면 귀찮은 상황 대신 금맥만 생긴다', () {
    moveTo(2);
    random.doubles.add(0.99);
    game.updateEvents(GameConfig.idleAfter.inSeconds.toDouble());
    expect(game.isIdle, isTrue);
    random.ints.addAll([rollFor(MineEventType.ghost), 0]);
    game.updateEvents(1);
    expect(game.floorEvent(0)?.type, MineEventType.goldVein);

    // 다시 만지면 직접 플레이 중
    game.markActive();
    expect(game.isIdle, isFalse);
  });

  test('게임을 꺼 둔 동안 침수와 귀신은 알아서 해결된다', () {
    moveTo(1);
    spawn(MineEventType.flood);
    game.save();
    now = now.add(const Duration(minutes: 30));
    game.collectOfflineEarnings(now);
    expect(game.floorEvent(0), isNull);
  });
}
