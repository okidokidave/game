import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/ads/ad_service.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/rules.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:influencer_sim/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> make([int seed = 1, Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final g = GameController(SaveRepository(await SharedPreferences.getInstance()), rng: Random(seed));
  g.newGame('도트왕', const Look(hair: 0, shirt: 0));
  return g;
}

GameEvent eventOf(String id) => gameEvents.firstWhere((e) => e.id == id);

const plain = StreamResult(viewers: 400, gain: 100, donation: 20000, ads: 10000, viral: false, flop: false);

void main() {
  group('새 이벤트', () {
    test('방송 안 꺼짐·가족 난입은 작은 방송인일 때만 나온다', () async {
      final g = await make();
      g.s.followers = 500;
      expect(eventOf('hot_mic').when(g.s), isTrue);
      expect(eventOf('family_intrude').when(g.s), isTrue);
      g.s.followers = 5000;
      expect(eventOf('hot_mic').when(g.s), isFalse);
      expect(eventOf('family_intrude').when(g.s), isFalse);
    });

    test('MCN에 들어가면 시청자 보너스와 수수료 30%, 나중에 노예계약 논란', () async {
      final g = await make();
      g.s.followers = 20000;
      final q = quality(g.s, contentOf('talk'));
      g.resolveEvent(eventOf('mcn_offer'), 0);
      expect(g.s.flags.contains('mcn'), isTrue);
      expect(quality(g.s, contentOf('talk')), closeTo(q + 0.15, 1e-9));
      g.finishStream(contentOf('talk'), plain);
      expect(g.s.ledger.any((l) => l.label.contains('MCN') && l.amount == -9000), isTrue);
      expect(eventOf('mcn_offer').when(g.s), isFalse);
      expect(eventOf('mcn_slave').when(g.s), isFalse);
      g.s.followers = 60000;
      expect(eventOf('mcn_slave').when(g.s), isTrue);
      g.resolveEvent(eventOf('mcn_slave'), 0);
      expect(g.s.flags.contains('mcn'), isFalse);
    });

    test('인간관계 위기 3종 (절친 저격, 전 연인 폭로, 렉카)', () async {
      final g = await make();
      g.s.followers = 30000;
      for (final id in ['friend_feud', 'ex_expose', 'wrecker']) {
        final ev = eventOf(id);
        expect(ev.where, 'crisis');
        expect(ev.when(g.s), isTrue, reason: id);
        expect(ev.choices.any((c) => c.chance != null), isTrue, reason: id);
      }
    });
  });

  group('시청자 질문·찐팬', () {
    test('질문에 대답하면 찐팬·분위기가 바뀌고 미션이 진행된다', () async {
      final g = await make();
      g.s.followers = 2000;
      g.s.day = 2; // 미션은 2일째부터 열린다
      g.s.missions = [Mission('question', 1, 5000)];
      final q = chatQuestions.firstWhere((q) => q.id == 'birthday');
      final (reactions, hype, changes) = g.answerQuestion(q, 0, 300);
      expect(reactions, isNotEmpty);
      expect(hype, 1);
      expect(g.s.coreFans, greaterThan(0));
      expect(changes.any((c) => c.label == '찐팬'), isTrue);
      expect(g.s.missions.first.done, isTrue);
      expect(g.rollQuestion(1), isNotNull);
    });

    test('찐팬이 많으면 논란이 덜 커지고 후원이 늘어난다', () async {
      final g = await make();
      g.s.followers = 10000;
      g.applyFx(const Fx(heat: 20));
      final plainHeat = g.s.heat;
      g.s.heat = 0;
      g.s.coreFans = 3000;
      expect(g.shieldPower, closeTo(0.3, 1e-9));
      g.applyFx(const Fx(heat: 20));
      expect(g.s.heat, lessThan(plainHeat));

      double avgDonation(int core) {
        g.s.coreFans = core;
        var sum = 0;
        final rng = Random(5);
        for (var i = 0; i < 200; i++) {
          sum += calcStream(g.s, contentOf('talk'), rng).donation;
        }
        return sum / 200;
      }

      expect(avgDonation(3000), greaterThan(avgDonation(0) * 1.3));
    });

    test('사과 없이 넘어간 말실수는 찐팬을 더 잃는다', () async {
      final g = await make();
      g.s.followers = 10000;
      g.s.coreFans = 1000;
      g.resolveGaffe(gaffes.first, plain, apologize: false);
      expect(g.s.coreFans, lessThan(900));
    });
  });

  group('방송 예고', () {
    test('예고한 방송을 지키면 보너스와 찐팬', () async {
      final g = await make();
      expect(g.scheduleSlots().first, (1, 1));
      g.setSchedule(1, 0, 'talk');
      final c = contentOf('talk');
      expect(g.isScheduled(c), isTrue);
      g.beginStream(c);
      expect(g.scheduleHit, isTrue);
      g.finishStream(c, plain);
      expect(g.s.schedKept, 1);
      expect(g.s.schedDay, 0);
      expect(g.s.coreFans, greaterThan(10));
    });

    test('예고를 어기면 밤에 찐팬과 이미지가 깎인다', () async {
      final g = await make();
      g.s.followers = 1000;
      g.s.coreFans = 100;
      g.setSchedule(1, 2, 'talk');
      g.endDay(0);
      expect(g.s.coreFans, lessThan(100));
      expect(g.s.image, -2);
      expect(g.s.schedDay, 0);
    });
  });

  group('미션·기록', () {
    test('매일 아침 미션 3개, 다 채우면 보상', () async {
      final g = await make();
      expect(g.s.missions.length, 3);
      g.s.day = 2;
      g.s.missions = [Mission('stream', 2, 7000)];
      final m = g.s.money;
      g.progress('stream', 1);
      expect(g.s.missions.first.done, isFalse);
      g.progress('stream', 1);
      expect(g.s.missions.first.done, isTrue);
      expect(g.s.money, m + 7000);
      expect(g.s.missionsDone, 1);
      g.endDay(0);
      expect(g.s.missions.length, 3);
      expect(g.s.missions.every((x) => !x.done), isTrue);
    });

    test('하루가 끝나면 그래프 기록이 쌓이고, 최고 방송 3개를 기억한다', () async {
      final g = await make();
      for (final v in [100, 500, 300, 800]) {
        g.finishStream(contentOf('talk'), StreamResult(viewers: v, gain: 1, donation: 0, ads: 0, viral: false, flop: false));
      }
      expect(g.s.best.map((b) => b.viewers), [800, 500, 300]);
      g.endDay(0);
      expect(g.s.history.length, 1);
      expect(g.s.history.first.peak, 800);
      expect(g.s.todayPeak, 0);
      final back = GameState.fromJson(g.s.toJson());
      expect(back.history.first.peak, 800);
      expect(back.best.length, 3);
    });
  });

  group('사업', () {
    test('구독자와 창업비가 있어야 열고, 매일 밤 수익이 들어온다', () async {
      final g = await make();
      final goods = businessOf('goods');
      expect(g.businessBlock(goods), contains('구독자'));
      g.s.followers = 20000;
      g.s.money = goods.cost;
      expect(g.openBusiness(goods), isTrue);
      expect(g.s.money, 0);
      final income = g.businessIncome(goods);
      expect(income, greaterThan(goods.base));
      g.endDay(0);
      expect(g.s.ledger.any((l) => l.label.contains('굿즈샵') && l.amount == income), isTrue);
      // 논란이 크면 불매로 반토막
      g.s.heat = 70;
      expect(g.businessIncome(goods), lessThan(income * 0.6));
    });
  });

  group('업적·다회차', () {
    test('업적은 판이 바뀌어도 남는다', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final g = GameController(SaveRepository(prefs), rng: Random(1))..newGame('도트왕', const Look(hair: 0, shirt: 0));
      g.finishStream(contentOf('talk'), plain);
      expect(g.achieved, contains('first'));
      expect(g.toasts.any((t) => t.contains('첫 방송')), isTrue);
      final g2 = GameController(SaveRepository(prefs), rng: Random(2));
      expect(g2.achieved, contains('first'));
    });

    test('엔딩과 업적이 쌓이면 새 게임에 혜택이 붙는다', () async {
      final g = await make(1, {
        'influencer_endings': ['a', 'b', 'c', 'd', 'e'],
        'influencer_achievements': [for (final a in achievements.take(15)) a.id],
      });
      expect(g.unlockedPerks.length, perks.length);
      expect(g.s.money, 30000 + 50000);
      expect(g.s.image, 10);
      expect(g.s.gear['camera'], 1);
      expect(g.s.gear['mic'], 1);
      expect(g.s.followers, 50);
      expect(g.s.house, 'oneroom');
    });
  });

  group('알바 → 부모님 가게 홍보', () {
    test('전업 방송인이 되면 알바를 못 하고, 부모님 가게가 생기면 홍보를 한다', () async {
      final g = await make();
      expect(g.actionBlock('work'), isNull);
      g.s.followers = proFollowers;
      expect(g.isPro, isTrue);
      expect(g.actionBlock('work'), '전업 방송인');
      final ev = eventOf('parent_shop');
      expect(ev.when(g.s), isTrue);
      g.resolveEvent(ev, 0);
      expect(g.actionBlock('work'), isNull);

      final f = g.s.followers;
      final out = g.promote(onAir: false);
      expect(g.s.followers, greaterThan(f));
      expect(out.backlash, isFalse);

      final results = <bool>{};
      for (var i = 0; i < 30 && results.length < 2; i++) {
        g.s.energy = 100;
        results.add(g.promote(onAir: true).backlash);
      }
      expect(results, {true, false});
    });
  });

  group('다듬기', () {
    test('기능은 성장에 맞춰 하나씩 열리고, 열릴 때 알림이 뜬다', () async {
      final g = await make();
      expect(g.unlocked('missions'), isFalse);
      expect(g.unlocked('schedule'), isFalse);
      expect(g.unlocked('business'), isFalse);
      g.s.followers = 120;
      g.save();
      expect(g.unlocked('schedule'), isTrue);
      expect(g.toasts.any((t) => t.contains('방송 예고')), isTrue);
      expect(g.isNew('schedule'), isTrue);
      g.seen('schedule');
      expect(g.isNew('schedule'), isFalse);
      // 미션은 열리기 전엔 진행되지 않는다
      g.s.missions = [Mission('stream', 1, 5000)];
      g.progress('stream', 1);
      expect(g.s.missions.first.done, isFalse);
    });

    test('사건은 하루에 하나만 일어난다', () async {
      final g = await make();
      g.s.followers = 2000;
      final ev = g.rollEvent('live', 1)!;
      g.resolveEvent(ev, 0);
      expect(g.rollEvent('live', 1), isNull);
      expect(g.gaffeChance(contentOf('react')), 0);
      g.s.day++;
      expect(g.rollEvent('live', 1), isNotNull);
    });

    test('광고주 후원은 하루 한 번', () async {
      final g = await make();
      expect(g.canAdDonate, isFalse); // 방송을 한 번은 해야 한다
      g.finishStream(contentOf('talk'), plain);
      expect(g.canAdDonate, isTrue);
      final m = g.s.money;
      final amount = g.claimAdDonation();
      expect(amount, greaterThan(0));
      expect(g.s.money, m + amount);
      expect(g.s.ledger.first.label, '광고주 후원');
      expect(g.canAdDonate, isFalse);
      g.s.day++;
      expect(g.canAdDonate, isTrue);
    });
  });

  testWidgets('미션·예고·기록·업적 버튼과 상점 사업 탭', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    late GameController g;
    await tester.runAsync(() async => g = await make(3));
    g.s.followers = 20000;
    g.s.money = 5000000;
    g.s.day = 3;
    g.save();
    await tester.pumpWidget(InfluencerApp(game: g, ads: NoAdService(), liveDuration: const Duration(milliseconds: 2000)));
    Future<void> wait(int ms) async {
      for (var i = 0; i < ms ~/ 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await wait(300);
    await tester.tap(find.byKey(const ValueKey('continue')));
    await wait(800);

    await tester.tap(find.byKey(const ValueKey('missions-button')));
    await wait(500);
    expect(find.text('🎯 오늘의 미션'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await wait(500);

    await tester.tap(find.byKey(const ValueKey('schedule-button')));
    await wait(500);
    await tester.tap(find.byKey(const ValueKey('sched-content-talk')));
    await wait(200);
    await tester.tap(find.byKey(const ValueKey('schedule-confirm')));
    await wait(500);
    expect(g.s.schedContent, 'talk');

    await tester.tap(find.byKey(const ValueKey('stats-button')));
    await wait(500);
    expect(find.text('📊 방송 기록'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stats-kind-1')));
    await wait(200);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await wait(500);

    await tester.tap(find.byKey(const ValueKey('achievements-button')));
    await wait(500);
    expect(find.text('🏅 업적 도감'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await wait(500);

    await tester.tap(find.byKey(const ValueKey('act-shop')));
    await wait(500);
    await tester.tap(find.byKey(const ValueKey('shop-tab-4')));
    await wait(300);
    await tester.tap(find.byKey(const ValueKey('open-goods')));
    await wait(500);
    expect(g.s.business, ['goods']);
  });
}
