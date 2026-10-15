import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/mine_event.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/game/shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late GameController game;
  late List<String> messages;
  late List<GameCue> cues;

  /// 체력이 [target]이 될 때까지 걸리는 시간 (보통 속도로 일할 때).
  double secondsTo(double target) =>
      (GameConfig.maxStamina - target) / GameConfig.staminaDrainPerSecond;

  /// 지친 뒤로는 절반 속도로 일해서 체력도 절반 속도로 준다.
  double secondsToCollapse() =>
      secondsTo(GameConfig.tiredStamina) +
      GameConfig.tiredStamina /
          (GameConfig.staminaDrainPerSecond * GameConfig.fatigueSpeed);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1);
    messages = [];
    cues = [];
    final prefs = await SharedPreferences.getInstance();
    game = GameController(SaveRepository(prefs), clock: () => now);
    game.onMessage = messages.add;
    game.onCue = cues.add;
  });

  test('새 인부는 체력이 가득하고, 일하면 줄어든다', () {
    expect(game.staminaOf(0), GameConfig.maxStamina);
    game.tick(60);
    expect(
      game.staminaOf(0),
      closeTo(
        GameConfig.maxStamina - 60 * GameConfig.staminaDrainPerSecond,
        1e-9,
      ),
    );
  });

  test('체력이 30 아래면 지쳐서 절반 속도로 일하고, 소장에게 알린다', () {
    game.tick(secondsTo(GameConfig.tiredStamina) + 1);
    expect(game.isTired(0), isTrue);
    expect(game.workerSpeed(0, 0), GameConfig.fatigueSpeed);
    expect(game.exhaustedCount, 1);
    expect(cues, contains(GameCue.workerTired));
    expect(messages.last, contains('지쳤어요'));
  });

  test('체력이 바닥나면 쓰러지고, 그냥 두면 천천히 회복해 일어난다', () {
    game.tick(secondsTo(GameConfig.tiredStamina) + 1);
    game.tick(secondsToCollapse());
    expect(game.isCollapsed(0), isTrue);
    expect(game.workerSpeed(0, 0), 0);
    expect(cues, contains(GameCue.workerCollapsed));
    expect(messages.last, contains('쓰러졌어요'));

    // 쓰러진 동안은 골드를 못 번다.
    final gold = game.gold;
    game.tick(10);
    expect(game.gold, gold);

    game.tick(GameConfig.tiredStamina / GameConfig.collapsedRegenPerSecond + 1);
    expect(game.isCollapsed(0), isFalse);
    expect(messages.last, contains('일어나'));
  });

  test('에너지 드링크를 사서 먹이면 체력이 차고, 쓰러진 인부도 일어난다', () {
    game.tick(secondsTo(0) * 3);
    expect(game.isCollapsed(0), isTrue);

    const drink = Shop.energyDrink;
    expect(game.feedWorker(drink, 0), isFalse); // 가진 게 없음
    game.grantBonusGold(game.itemCost(drink));
    expect(game.buyItem(drink), isTrue);
    expect(game.itemCount(drink), 1);

    final before = game.staminaOf(0);
    expect(game.feedWorker(drink, 0), isTrue);
    expect(game.itemCount(drink), 0);
    expect(game.isCollapsed(0), isFalse);
    expect(game.staminaOf(0), closeTo(before + drink.stamina, 1e-9));
  });

  test('골드가 모자라면 살 수 없다', () {
    expect(game.canBuy(Shop.stew), isFalse);
    expect(game.buyItem(Shop.stew), isFalse);
  });

  test('커피는 모두에게 +30, 보양식은 모두를 가득 채운다', () async {
    game.grantBonusGold(1e9);
    while (game.workers < 3) {
      game.hireWorker();
    }
    game.tick(secondsTo(50));
    game.buyItem(Shop.coffee);
    expect(game.useItem(Shop.coffee), isTrue);
    for (var s = 0; s < 3; s++) {
      expect(game.staminaOf(s), closeTo(50 + Shop.coffee.stamina, 1e-6));
    }
    game.buyItem(Shop.stew);
    game.useItem(Shop.stew);
    for (var s = 0; s < 3; s++) {
      expect(game.staminaOf(s), GameConfig.maxStamina);
    }
  });

  test('한 명용 물건은 모두에게 쓸 수 없고, 모두용은 한 명에게 먹일 수 없다', () {
    game.grantBonusGold(1e9);
    game.buyItem(Shop.energyDrink);
    game.buyItem(Shop.coffee);
    expect(game.useItem(Shop.energyDrink), isFalse);
    expect(game.feedWorker(Shop.coffee, 0), isFalse);
  });

  test('비타민을 먹으면 그동안 체력이 줄지 않고, 끝나면 다시 준다', () {
    game.grantBonusGold(1e9);
    game.buyItem(Shop.vitamin);
    expect(game.useItem(Shop.vitamin), isTrue);
    expect(game.isStaminaBuffActive, isTrue);
    game.tick(300);
    expect(game.staminaOf(0), GameConfig.maxStamina);

    now = now.add(Duration(minutes: Shop.vitamin.buffMinutes));
    expect(game.isStaminaBuffActive, isFalse);
    game.tick(60);
    expect(game.staminaOf(0), lessThan(GameConfig.maxStamina));
  });

  test('비타민을 또 먹으면 남은 시간에 더해진다', () {
    game.grantBonusGold(1e9);
    game.buyItem(Shop.vitamin);
    game.buyItem(Shop.vitamin);
    game.useItem(Shop.vitamin);
    game.useItem(Shop.vitamin);
    expect(
      game.staminaBuffRemaining,
      Duration(minutes: Shop.vitamin.buffMinutes * 2),
    );
  });

  test('가격은 생산량에 맞춰 오르지만 최소 가격보다 싸지 않다', () {
    expect(game.itemCost(Shop.energyDrink), Shop.energyDrink.minCost);
    game.grantBonusGold(1e15);
    while (game.upgradeMine()) {}
    while (game.hireWorker()) {}
    expect(
      game.itemCost(Shop.energyDrink),
      closeTo(game.steadyGoldPerSecond * Shop.energyDrink.costSeconds, 1e-6),
    );
  });

  test('쉬게 하면 쉬고 난 뒤 체력이 오른다', () {
    game.tick(secondsTo(50));
    game.restWorker(0);
    now = now.add(GameConfig.restDuration);
    game.updateEvents(0);
    expect(game.staminaOf(0), closeTo(50 + GameConfig.restStamina, 1e-6));
    expect(game.workerEvent(0, 0)!.type, MineEventType.energized);
  });

  test('게임을 꺼 둔 동안 인부들은 쉬면서 체력을 채운다', () async {
    game.tick(secondsTo(40));
    await game.save(now);
    game.collectOfflineEarnings(now.add(const Duration(minutes: 10)));
    expect(
      game.staminaOf(0),
      closeTo(40 + 600 * GameConfig.offlineStaminaPerSecond, 1e-6),
    );
  });

  test('체력, 쓰러짐, 가진 물건, 비타민이 저장된다', () async {
    game.grantBonusGold(1e9);
    game.buyItem(Shop.lunchBox);
    game.buyItem(Shop.vitamin);
    game.useItem(Shop.vitamin);
    await game.save(now);

    final prefs = await SharedPreferences.getInstance();
    final loaded = GameController(SaveRepository(prefs), clock: () => now);
    expect(loaded.itemCount(Shop.lunchBox), 1);
    expect(loaded.isStaminaBuffActive, isTrue);
    expect(loaded.staminaOf(0), game.staminaOf(0));
  });

  test('새로 고용한 인부는 체력이 가득하다', () {
    game.tick(secondsTo(50));
    game.grantBonusGold(1e6);
    game.hireWorker();
    expect(game.staminaOf(1), GameConfig.maxStamina);
  });
}
