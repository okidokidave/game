import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/game_state.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/ui/number_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> newController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GameController(SaveRepository(prefs));
}

void main() {
  group('GameController', () {
    test('작은 광산 하나와 인부 한 명으로 시작한다', () async {
      final game = await newController();
      expect(game.gold, 0);
      expect(game.mineLevel, 1);
      expect(game.workers, 1);
      expect(game.goldPerSecond, GameConfig.goldPerWorkerPerSecond);
    });

    test('인부들이 시간에 비례해 골드를 캔다', () async {
      final game = await newController();
      game.tick(10);
      expect(game.gold, closeTo(10, 1e-9));
    });

    test('터치하면 곡괭이 레벨만큼 골드를 얻는다', () async {
      final game = await newController();
      expect(game.tap(), 1);
      expect(game.gold, 1);
    });

    test('골드가 부족하면 인부를 고용할 수 없다', () async {
      final game = await newController();
      expect(game.hireWorker(), isFalse);
      expect(game.workers, 1);
    });

    test('인부를 고용하면 골드가 줄고 생산량이 오른다', () async {
      final game = await newController();
      game.tick(GameConfig.workerBaseCost);
      expect(game.hireWorker(), isTrue);
      expect(game.workers, 2);
      expect(game.gold, closeTo(0, 1e-9));
      expect(game.goldPerSecond, 2 * GameConfig.goldPerWorkerPerSecond);
    });

    test('광산 칸이 가득 차면 더 고용할 수 없다', () async {
      final game = await newController();
      game.tick(1e6);
      while (game.hireWorker()) {}
      expect(game.workers, game.maxWorkers);
      expect(game.isWorkerFull, isTrue);

      expect(game.upgradeMine(), isTrue);
      expect(game.isWorkerFull, isFalse);
      expect(game.hireWorker(), isTrue);
    });

    test('광산을 확장하면 생산 배수가 오른다', () async {
      final game = await newController();
      game.tick(GameConfig.mineBaseCost);
      expect(game.upgradeMine(), isTrue);
      expect(
        game.goldPerSecond,
        closeTo(GameConfig.mineMultiplierGrowth, 1e-9),
      );
    });

    test('업그레이드 비용은 레벨마다 오른다', () {
      expect(GameConfig.workerCost(2), greaterThan(GameConfig.workerCost(1)));
      expect(
        GameConfig.mineUpgradeCost(2),
        greaterThan(GameConfig.mineUpgradeCost(1)),
      );
      expect(
        GameConfig.pickaxeUpgradeCost(2),
        greaterThan(GameConfig.pickaxeUpgradeCost(1)),
      );
    });
  });

  group('채굴 장비', () {
    test('장비 레벨에 따라 곡괭이 → 드릴 → 다이너마이트 → 굴착 기계로 바뀐다', () {
      final names = [for (final t in GameConfig.equipmentTiers) t.name];
      expect(names, ['곡괭이', '착암 드릴', '다이너마이트', '굴착 기계']);
      for (var i = 0; i < GameConfig.equipmentTiers.length; i++) {
        final tier = GameConfig.equipmentTiers[i];
        expect(GameConfig.equipmentTier(tier.startLevel), i);
        if (i > 0) expect(GameConfig.equipmentTier(tier.startLevel - 1), i - 1);
      }
    });

    test('새 장비는 광산이 충분히 깊어야 들일 수 있다', () async {
      final game = await newController();
      game.grantBonusGold(1e12);
      final drill = GameConfig.equipmentTiers[1];
      while (game.pickaxeLevel < drill.startLevel - 1) {
        expect(game.upgradePickaxe(), isTrue);
      }
      expect(game.nextEquipment!.name, drill.name);
      expect(game.equipmentLockedUntilMine, drill.requiredMineLevel);
      expect(game.upgradePickaxe(), isFalse);

      while (game.mineLevel < drill.requiredMineLevel) {
        game.upgradeMine();
      }
      expect(game.equipmentLockedUntilMine, isNull);
      expect(game.upgradePickaxe(), isTrue);
      expect(game.equipmentTier, 1);
    });

    test('장비 배수가 인부 생산량과 터치 채굴에 곱해진다', () async {
      final game = await newController();
      game.grantBonusGold(1e12);
      final drill = GameConfig.equipmentTiers[1];
      while (game.mineLevel < drill.requiredMineLevel) {
        game.upgradeMine();
      }
      final before = game.steadyGoldPerSecond;
      while (game.equipmentTier < 1) {
        game.upgradePickaxe();
      }
      expect(
        game.steadyGoldPerSecond,
        closeTo(before * drill.multiplier, 1e-9),
      );
      expect(game.baseGoldPerSecond, closeTo(game.steadyGoldPerSecond, 1e-9));
      expect(
        game.goldPerTap,
        closeTo(
          game.pickaxeLevel *
              GameConfig.mineMultiplier(game.mineLevel) *
              drill.multiplier,
          1e-9,
        ),
      );
    });
  });

  group('오프라인 보상', () {
    test('꺼 둔 시간만큼 효율을 적용해 지급한다', () async {
      final game = await newController();
      final start = DateTime(2026, 1, 1);
      await game.save(start);
      final earned = game.collectOfflineEarnings(
        start.add(const Duration(hours: 1)),
      );
      expect(earned, closeTo(3600 * GameConfig.offlineEfficiency, 1e-6));
      expect(game.gold, closeTo(earned, 1e-6));
    });

    test('최대 시간까지만 보상한다', () async {
      final game = await newController();
      final start = DateTime(2026, 1, 1);
      await game.save(start);
      final earned = game.collectOfflineEarnings(
        start.add(const Duration(days: 3)),
      );
      final maxSeconds = GameConfig.maxOfflineTime.inSeconds;
      expect(earned, closeTo(maxSeconds * GameConfig.offlineEfficiency, 1e-6));
    });

    test('기기 시간을 과거로 돌리면 보상하지 않는다', () async {
      final game = await newController();
      final start = DateTime(2026, 1, 1);
      await game.save(start);
      expect(
        game.collectOfflineEarnings(start.subtract(const Duration(hours: 1))),
        0,
      );
    });

    test('같은 시간에 두 번 받을 수 없다', () async {
      final game = await newController();
      final start = DateTime(2026, 1, 1);
      await game.save(start);
      final later = start.add(const Duration(hours: 1));
      game.collectOfflineEarnings(later);
      expect(game.collectOfflineEarnings(later), 0);
    });
  });

  group('광고 부스트', () {
    late DateTime now;
    late GameController game;

    setUp(() async {
      now = DateTime(2026, 1, 1);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      game = GameController(SaveRepository(prefs), clock: () => now);
    });

    test('부스트 중에는 생산량이 배수만큼 오른다', () {
      expect(game.activateBoost(), isTrue);
      expect(
        game.goldPerSecond,
        game.baseGoldPerSecond * GameConfig.boostMultiplier,
      );
      game.tick(10);
      expect(game.gold, closeTo(10 * GameConfig.boostMultiplier, 1e-9));
    });

    test('시간이 지나면 부스트가 끝난다', () {
      game.activateBoost();
      now = now.add(GameConfig.boostDuration);
      expect(game.isBoostActive, isFalse);
      expect(game.goldPerSecond, game.baseGoldPerSecond);
    });

    test('부스트는 최대 시간까지만 쌓인다', () {
      while (game.activateBoost()) {}
      expect(game.boostRemaining, lessThanOrEqualTo(GameConfig.maxBoostTime));
      expect(game.canActivateBoost, isFalse);
    });

    test('오프라인 보상에는 부스트가 적용되지 않는다', () async {
      await game.save(now);
      game.activateBoost();
      final earned = game.collectOfflineEarnings(
        now.add(const Duration(hours: 1)),
      );
      expect(earned, closeTo(3600 * GameConfig.offlineEfficiency, 1e-6));
    });

    test('광고 보너스 골드를 지급한다', () {
      game.grantBonusGold(500);
      expect(game.gold, 500);
      expect(game.totalEarned, 500);
    });

    test('부스트 종료 시각이 저장된다', () async {
      game.activateBoost();
      await game.save(now);
      final prefs = await SharedPreferences.getInstance();
      final loaded = GameController(SaveRepository(prefs), clock: () => now);
      expect(loaded.boostRemaining, GameConfig.boostDuration);
    });
  });

  group('저장', () {
    test('저장한 진행 상황을 다시 불러온다', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final game = GameController(SaveRepository(prefs));
      game.tick(1e6);
      game.hireWorker();
      game.upgradeMine();
      game.upgradePickaxe();
      await game.save();

      final loaded = GameController(SaveRepository(prefs));
      expect(loaded.gold, closeTo(game.gold, 1e-6));
      expect(loaded.workers, 2);
      expect(loaded.mineLevel, 2);
      expect(loaded.pickaxeLevel, 2);
    });

    test('손상된 저장 데이터는 새 게임으로 시작한다', () async {
      SharedPreferences.setMockInitialValues({'gold_mine_save_v1': 'not json'});
      final prefs = await SharedPreferences.getInstance();
      expect(SaveRepository(prefs).load(), isNull);
    });

    test('GameState JSON 왕복', () {
      final state = GameState(
        gold: 12.5,
        totalEarned: 100,
        mineLevel: 3,
        workers: 7,
        pickaxeLevel: 4,
        lastSavedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final copy = GameState.fromJson(state.toJson());
      expect(copy.toJson(), state.toJson());
    });
  });

  group('formatGold', () {
    test('큰 숫자를 줄여서 표시한다', () {
      expect(formatGold(0), '0');
      expect(formatGold(999.9), '999');
      expect(formatGold(1000), '1.00K');
      expect(formatGold(12345), '12.3K');
      expect(formatGold(123456), '123K');
      expect(formatGold(1.5e6), '1.50M');
      expect(formatGold(2e9), '2.00B');
    });
  });
}
