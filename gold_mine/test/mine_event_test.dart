import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 정해 둔 값을 차례로 돌려주는 가짜 운. 값이 떨어지면 0.
class ScriptedRandom implements Random {
  final List<double> doubles = [];
  final List<int> ints = [];

  @override
  double nextDouble() => doubles.isEmpty ? 0 : doubles.removeAt(0);

  @override
  int nextInt(int max) => ints.isEmpty ? 0 : ints.removeAt(0) % max;

  @override
  bool nextBool() => false;
}

/// 상황 종류를 고르는 주사위 값 (GameConfig 비율 순서: 피로, 부상, 다이아, 금맥).
int rollFor(MineEventType type) => switch (type) {
  MineEventType.fatigue => 0,
  MineEventType.injury => GameConfig.fatigueWeight,
  MineEventType.diamond => GameConfig.fatigueWeight + GameConfig.injuryWeight,
  _ =>
    GameConfig.fatigueWeight +
        GameConfig.injuryWeight +
        GameConfig.diamondWeight,
};

void main() {
  late DateTime now;
  late ScriptedRandom random;
  late GameController game;
  late List<String> notices;

  Future<GameController> create() async {
    final prefs = await SharedPreferences.getInstance();
    final c = GameController(
      SaveRepository(prefs),
      clock: () => now,
      random: random,
    );
    c.onEventNotice = (_, message) => notices.add(message);
    return c;
  }

  /// [type] 상황을 B1 첫 인부(또는 B1 층)에 일으킨다.
  MineEvent spawn(MineEventType type) {
    random.doubles.add(0);
    random.ints.addAll([rollFor(type), 0]);
    game.updateEvents(1);
    return game.events.last;
  }

  void advance(Duration d) {
    now = now.add(d);
    game.updateEvents(0);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1);
    random = ScriptedRandom();
    notices = [];
    game = await create();
    game.grantBonusGold(GameConfig.eventsStartAfterEarned);
  });

  test('처음 배우는 동안에는 상황이 생기지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = await create();
    random.doubles.add(0);
    fresh.updateEvents(1000);
    expect(fresh.events, isEmpty);
  });

  test('운이 따르지 않으면 상황이 생기지 않는다', () {
    random.doubles.add(0.99);
    game.updateEvents(1);
    expect(game.events, isEmpty);
  });

  group('지친 인부', () {
    test('절반 속도로 일하고 소장에게 보고된다', () {
      final e = spawn(MineEventType.fatigue);
      expect(e.type, MineEventType.fatigue);
      expect(e.type.needsManager, isTrue);
      expect(game.workerSpeed(0, 0), GameConfig.fatigueSpeed);
      expect(
        game.baseGoldPerSecond,
        closeTo(game.steadyGoldPerSecond * GameConfig.fatigueSpeed, 1e-9),
      );
      expect(notices.single, contains('지쳤어요'));
    });

    test('휴식을 주면 쉬었다가 한동안 빨리 일하고, 다시 보통으로 돌아온다', () {
      final e = spawn(MineEventType.fatigue);
      expect(game.restWorker(e.id), isTrue);
      expect(game.workerSpeed(0, 0), 0);

      advance(GameConfig.restDuration);
      expect(game.workerEvent(0, 0)!.type, MineEventType.energized);
      expect(game.workerSpeed(0, 0), GameConfig.energizedSpeed);

      advance(GameConfig.energizedDuration);
      expect(game.workerEvent(0, 0), isNull);
      expect(game.workerSpeed(0, 0), 1);
    });

    test('계속 무리시키면 다친다', () {
      spawn(MineEventType.fatigue);
      advance(GameConfig.fatigueToInjury);
      expect(game.workerEvent(0, 0)!.type, MineEventType.injury);
      expect(notices.last, contains('다쳤어요'));
    });
  });

  group('다친 인부', () {
    test('일을 못 하고, 치료비를 내면 바로 돌아온다', () {
      final e = spawn(MineEventType.injury);
      expect(game.workerSpeed(0, 0), 0);
      expect(game.baseGoldPerSecond, 0);

      game.grantBonusGold(game.treatCost);
      final before = game.gold;
      expect(game.treatInjury(e.id), isTrue);
      expect(game.gold, closeTo(before - game.treatCost, 1e-9));
      expect(game.workerSpeed(0, 0), 1);
    });

    test('골드가 모자라면 치료할 수 없지만 광고로는 치료된다', () {
      // 인부를 고용해서 골드를 쓰면 치료비(초당 생산량에 비례)가 모자라게 된다.
      expect(game.hireWorker(), isTrue);
      final e = spawn(MineEventType.injury);
      expect(game.canTreat, isFalse);
      expect(game.treatInjury(e.id), isFalse);
      expect(game.treatInjury(e.id, free: true), isTrue);
      expect(game.workerEvent(0, 0), isNull);
    });

    test('그냥 두면 시간이 지나 회복한다', () {
      spawn(MineEventType.injury);
      advance(GameConfig.injuryHealTime);
      expect(game.workerEvent(0, 0), isNull);
      expect(notices.last, contains('회복'));
    });
  });

  group('다이아몬드', () {
    test('받으면 보상만큼 골드가 들어온다 (광고 보면 2배)', () {
      final e = spawn(MineEventType.diamond);
      expect(e.reward, greaterThanOrEqualTo(GameConfig.minDiamondReward));
      final before = game.gold;
      expect(game.collectDiamond(e.id, multiplier: 2), e.reward * 2);
      expect(game.gold, closeTo(before + e.reward * 2, 1e-9));
      expect(game.events, isEmpty);
    });

    test('제때 받지 않으면 사라진다', () {
      final e = spawn(MineEventType.diamond);
      advance(GameConfig.diamondExpireTime);
      expect(game.eventById(e.id), isNull);
      expect(game.collectDiamond(e.id), 0);
      expect(notices.last, contains('놓쳤어요'));
    });
  });

  group('금맥', () {
    test('한동안 그 층 생산량이 늘었다가 끝난다', () {
      final e = spawn(MineEventType.goldVein);
      expect(e.type.isFloorWide, isTrue);
      expect(game.floorMultiplier(0), GameConfig.goldVeinMultiplier);
      expect(
        game.baseGoldPerSecond,
        closeTo(game.steadyGoldPerSecond * GameConfig.goldVeinMultiplier, 1e-9),
      );
      advance(GameConfig.goldVeinDuration);
      expect(game.floorMultiplier(0), 1);
    });
  });

  test('소장이 처리할 상황은 동시에 최대 개수까지만 생긴다', () {
    game.grantBonusGold(1e9);
    while (game.hireWorker()) {}
    for (var k = 0; k < GameConfig.maxManagerEvents + 3; k++) {
      random.doubles.add(0);
      random.ints.addAll([rollFor(MineEventType.injury), k]);
      game.updateEvents(1);
    }
    expect(game.managerEvents.length, GameConfig.maxManagerEvents);
  });

  test('오프라인 보상은 돌발상황과 상관없이 계산한다', () async {
    await game.save(now);
    spawn(MineEventType.injury);
    final earned = game.collectOfflineEarnings(
      now.add(const Duration(hours: 1)),
    );
    expect(
      earned,
      closeTo(
        game.steadyGoldPerSecond * 3600 * GameConfig.offlineEfficiency,
        1e-6,
      ),
    );
  });

  test('진행 중인 상황은 저장되고 다시 불러온다', () async {
    final e = spawn(MineEventType.diamond);
    await game.save(now);
    final loaded = await create();
    final again = loaded.eventById(e.id)!;
    expect(again.type, MineEventType.diamond);
    expect(again.reward, e.reward);
    expect(again.endsAt, e.endsAt);
  });

  test('처음부터 다시 시작하면 상황도 사라진다', () async {
    spawn(MineEventType.fatigue);
    await game.reset();
    expect(game.events, isEmpty);
  });
}
