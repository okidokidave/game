import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/regions.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mine_event_test.dart' show ScriptedRandom;

void main() {
  late DateTime now;
  late ScriptedRandom random;
  late GameController game;
  late List<String> messages;

  final hill = Regions.all[0];
  final sulfur = Regions.all[1];

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

  /// 막장까지 파 내려가고 막장 층에 인부를 채운다.
  void digToBottom() {
    game.grantBonusGold(1e15);
    while (game.upgradeMine()) {}
    while (game.hireWorker()) {}
  }

  /// 막장 인부들이 [ore]를 하나 찾게 한다.
  void find(Ore ore, {required Region region}) {
    final ores = region.ores;
    var roll = 0;
    for (final o in ores) {
      if (o.id == ore.id) break;
      roll += o.rarity.weight;
    }
    // 이벤트는 안 나오고, 막장 첫 인부만 광석을 찾는다 (나머지 둘은 못 찾음).
    random.doubles.addAll([0.99, 0, 0.99, 0.99]);
    random.ints.add(roll);
    game.updateEvents(1);
  }

  test('첫 지역은 금빛 언덕 광산이고 막장은 B5', () {
    expect(game.region.name, '금빛 언덕 광산');
    expect(game.mineName, '금빛 언덕 광산');
    expect(hill.bottomFloor, 5);
  });

  test('막장보다 깊이 확장할 수 없다', () {
    digToBottom();
    expect(game.mineLevel, hill.bottomFloor);
    expect(game.isAtBottom, isTrue);
    expect(game.canUpgradeMine, isFalse);
    expect(game.upgradeMine(), isFalse);
  });

  test('막장에 닿기 전에는 희귀 광석이 나오지 않는다', () {
    game.grantBonusGold(1e9);
    game.updateEvents(1e6);
    expect(Regions.allOres.where(game.isDiscovered), isEmpty);
  });

  test('막장 인부가 희귀 광석을 찾으면 도감에 등록된다', () {
    digToBottom();
    find(hill.ores[2], region: hill);
    expect(game.oreCount(hill.ores[2]), 1);
    expect(game.isUnseen(hill.ores[2]), isTrue);
    expect(game.unseenOreCount, 1);
    expect(messages.last, contains('도감 등록'));

    find(hill.ores[2], region: hill);
    expect(game.oreCount(hill.ores[2]), 2);
    expect(messages.last, contains('보관 2개'));

    game.markCodexSeen();
    expect(game.unseenOreCount, 0);
  });

  test('한 지역을 모두 모으면 생산량 보너스가 붙는다', () {
    digToBottom();
    final before = game.steadyGoldPerSecond;
    for (final ore in hill.ores) {
      find(ore, region: hill);
    }
    expect(game.isRegionComplete(hill), isTrue);
    expect(game.completedSets, 1);
    expect(
      game.steadyGoldPerSecond,
      closeTo(before * (1 + GameConfig.regionSetBonus), 1e-6),
    );
    expect(messages.last, contains('도감 완성'));
  });

  test('지역을 개척하면 새 지역 B1부터, 원래 광산은 관리인이 맡는다', () {
    digToBottom();
    final own = game.steadyGoldPerSecond;
    expect(game.nextRegion!.name, sulfur.name);
    expect(game.canPioneer, isTrue);
    final gold = game.gold;
    final cost = game.pioneerCost;
    expect(game.pioneer(), isTrue);

    expect(game.region.name, sulfur.name);
    expect(game.mineLevel, 1);
    expect(game.workers, 1);
    expect(game.pickaxeLevel, 1);
    expect(game.gold, closeTo(gold - cost, 1e-3));
    expect(
      game.caretakerIncome,
      closeTo(own * GameConfig.caretakerShare, 1e-6),
    );
    // 새 지역 인부 한 명 (×1.5) + 관리인 수입
    expect(
      game.steadyGoldPerSecond,
      closeTo(
        GameConfig.goldPerWorkerPerSecond * sulfur.productionMultiplier +
            game.caretakerIncome,
        1e-6,
      ),
    );
  });

  test('도감은 지역을 옮겨도 남는다', () {
    digToBottom();
    find(hill.ores[0], region: hill);
    game.pioneer();
    expect(game.oreCount(hill.ores[0]), 1);
  });

  test('막장에 닿지 않았거나 마지막 지역이면 개척할 수 없다', () {
    game.grantBonusGold(1e15);
    expect(game.canPioneer, isFalse);
    digToBottom();
    game.pioneer();
    digToBottom();
    expect(game.nextRegion, isNull);
    expect(game.pioneer(), isFalse);
  });

  test('관리인 수입은 광고 부스트를 받지 않는다', () {
    digToBottom();
    game.pioneer();
    game.activateBoost();
    final own = game.baseGoldPerSecond - game.caretakerIncome;
    expect(
      game.goldPerSecond,
      closeTo(own * GameConfig.boostMultiplier + game.caretakerIncome, 1e-6),
    );
  });

  test('유황 골짜기에서 다이너마이트를 쓰면 부상 사고가 잦다', () {
    digToBottom();
    game.pioneer();
    game.grantBonusGold(1e15);
    while (game.equipmentTier < GameConfig.dynamiteTier) {
      if (!game.upgradePickaxe()) game.upgradeMine();
    }
    // 보통 비율로는 다이아가 나올 주사위 값이 유황 지역에서는 부상이 된다.
    final fatigueAndInjury = GameConfig.fatigueWeight + GameConfig.injuryWeight;
    random.doubles.add(0);
    random.ints.addAll([fatigueAndInjury, 0]);
    game.updateEvents(1);
    final e = game.events.last;
    expect(e.type, MineEventType.injury);
    expect(messages, isEmpty); // 사고 알림은 onEventNotice로 간다
  });

  test('지역과 도감, 관리인 수입이 저장된다', () async {
    digToBottom();
    find(hill.ores[1], region: hill);
    game.pioneer();
    await game.save(now);

    final prefs = await SharedPreferences.getInstance();
    final loaded = GameController(SaveRepository(prefs), clock: () => now);
    expect(loaded.region.name, sulfur.name);
    expect(loaded.oreCount(hill.ores[1]), 1);
    expect(loaded.caretakerIncome, closeTo(game.caretakerIncome, 1e-9));
  });

  test('지역마다 층 그림이 다르다', () {
    expect(hill.themeOf(0), RockTheme.dirt);
    expect(sulfur.themeOf(0), RockTheme.sulfur);
    expect(sulfur.themeOf(99), sulfur.floorThemes.last);
  });
}
