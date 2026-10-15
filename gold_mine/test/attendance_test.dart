import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/ads/ad_service.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/game/game_controller.dart';
import 'package:gold_mine/game/save_repository.dart';
import 'package:gold_mine/game/shop.dart';
import 'package:gold_mine/main.dart';
import 'package:gold_mine/ui/attendance_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late GameController game;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 1, 1, 9);
    prefs = await SharedPreferences.getInstance();
    game = GameController(SaveRepository(prefs), clock: () => now);
  });

  /// 하루씩 지나며 [days]번 출석한다.
  void attend(int days) {
    for (var i = 0; i < days; i++) {
      expect(game.checkIn(), isNotNull);
      now = now.add(const Duration(days: 1));
    }
  }

  test('출석은 하루에 한 번, 날짜가 바뀌면 다시 받을 수 있다', () {
    expect(game.canCheckIn, isTrue);
    final gold = game.gold;
    final amount = game.rewardGold(game.todaysReward);
    expect(amount, greaterThanOrEqualTo(game.todaysReward.minGold));
    final reward = game.checkIn();
    expect(reward, GameConfig.attendanceRewards[0]);
    expect(game.gold, closeTo(gold + amount, 1e-6));
    expect(game.canCheckIn, isFalse);
    expect(game.checkIn(), isNull);

    // 같은 날 밤늦게도 안 되고, 자정이 지나면 된다.
    now = DateTime(2026, 1, 1, 23, 59);
    expect(game.canCheckIn, isFalse);
    now = DateTime(2026, 1, 2, 0, 1);
    expect(game.canCheckIn, isTrue);
    expect(game.attendanceSlot, 1);
  });

  test('물건 보상은 매점 가방에 들어간다', () {
    attend(1);
    final drinks = game.itemCount(Shop.energyDrink);
    final reward = game.checkIn()!;
    expect(reward.itemId, Shop.energyDrink.id);
    expect(game.itemCount(Shop.energyDrink), drinks + reward.count);
  });

  test('7일째에 사이보그 인부가 오고, 보상판은 처음부터 다시 돈다', () {
    attend(6);
    expect(game.cyborgs, 0);
    expect(game.todaysReward.isCyborg, isTrue);
    attend(1);
    expect(game.cyborgs, 1);
    expect(game.attendanceSlot, 0);
    attend(7);
    expect(game.cyborgs, 2);
  });

  test('사이보그 인부는 일반 인부의 10배를 캐고 지치지 않는다', () {
    final one = game.steadyGoldPerSecond;
    attend(7);
    expect(
      game.steadyGoldPerSecond,
      closeTo(one * (1 + GameConfig.cyborgMultiplier), 1e-9),
    );
    expect(game.cyborgGoldPerSecond, closeTo(one * 10, 1e-9));
    // 오래 일해도 사이보그 몫은 그대로 남는다.
    game.tick(60 * 60 * 3);
    expect(game.isCollapsed(0), isTrue);
    expect(game.baseGoldPerSecond, closeTo(game.cyborgGoldPerSecond, 1e-9));
  });

  test('사이보그는 개척해도 따라오고, 관리인 몫에는 들어가지 않는다', () {
    attend(7);
    game.grantBonusGold(1e15);
    while (game.upgradeMine()) {}
    while (game.hireWorker()) {}
    final own = game.steadyGoldPerSecond - game.cyborgGoldPerSecond;
    expect(game.pioneer(), isTrue);
    expect(game.cyborgs, 1);
    expect(
      game.caretakerIncome,
      closeTo(own * GameConfig.caretakerShare, 1e-6),
    );
  });

  test('출석 기록과 사이보그는 저장된다', () {
    attend(7);
    game.checkIn();
    game.save();
    final loaded = GameController(SaveRepository(prefs), clock: () => now);
    expect(loaded.cyborgs, 1);
    expect(loaded.attendanceCount, 8);
    expect(loaded.canCheckIn, isFalse);
  });

  testWidgets('게임을 켜면 출석 보상판이 뜨고, 받으면 배지가 사라진다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      GoldMineApp(showTitle: false, controller: game, ads: NoAdService()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AttendanceDialog), findsOneWidget);

    await tester.tap(find.text('1일째 보상 받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AttendanceDialog), findsNothing);
    expect(game.canCheckIn, isFalse);
    expect(tester.takeException(), isNull);

    // 헤더 버튼으로 다시 열면 받은 칸이 표시되고 받기 버튼은 없다.
    await tester.tap(find.byTooltip('출석 보상'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('내일 또 올게요'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    game.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
