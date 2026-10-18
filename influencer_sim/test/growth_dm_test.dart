import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/rules.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:influencer_sim/ui/sns_phone.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> make([int seed = 1]) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController(SaveRepository(await SharedPreferences.getInstance()), rng: Random(seed));
  g.newGame('도트왕', const Look(hair: 0, shirt: 0));
  return g;
}

const good = StreamResult(viewers: 500, gain: 200, donation: 10000, ads: 0, viral: false, flop: false);

/// 노래 방송을 끝낼 때까지 반복해서 제안 DM을 기다린다
DmOffer? streamUntilOffer(GameController g, String content, {int tries = 200, StreamResult r = good, String? want}) {
  final c = contentOf(content);
  for (var i = 0; i < tries; i++) {
    final out = g.finishStream(c, r);
    if (out.offer != null && (want == null || out.offer!.id == want)) return out.offer;
  }
  return null;
}

void main() {
  group('알바 브이로그', () {
    test('그냥 알바는 돈만 벌고 걸리지 않는다', () async {
      final g = await make();
      final m = g.s.money;
      final out = g.work();
      expect(out.pay, greaterThan(0));
      expect(out.caught, isFalse);
      expect(g.s.money, m + out.pay);
      expect(g.s.workStrikes, 0);
    });

    test('브이로그를 자주 찍으면 경고가 쌓이고 3번째에 잘린다', () async {
      final g = await make(3);
      final place = g.s.workplace;
      var fired = false;
      for (var i = 0; i < 60 && !fired; i++) {
        g.s.energy = 100;
        final f0 = g.s.followers;
        final out = g.work(vlog: true);
        expect(out.gain, greaterThan(0));
        expect(g.s.followers, greaterThanOrEqualTo(f0 + out.gain));
        fired = out.fired;
      }
      expect(fired, isTrue);
      expect(g.s.workplace, (place + 1) % workplaces.length);
      expect(g.s.workStrikes, 0);
      expect(g.actionBlock('work'), startsWith('잘림'));
      expect(g.s.trends.last.tag, contains('알바'));
    });
  });

  group('직원', () {
    test('구독자와 3일치 일당이 있어야 고용할 수 있다', () async {
      final g = await make();
      final editor = staffOf('editor');
      expect(g.hireBlock(editor), contains('구독자'));
      g.s.followers = editor.minFollowers;
      g.s.money = editor.wage * 3 - 1;
      expect(g.hireBlock(editor), '돈 부족');
      g.s.money = editor.wage * 3;
      expect(g.hire(editor), isTrue);
      expect(g.hireBlock(editor), '고용 중');
    });

    test('매니저가 있으면 방송 체력이 20% 덜 들고, 밤마다 일당이 나간다', () async {
      final g = await make();
      final sing = contentOf('sing');
      final before = g.energyCost(sing);
      g.s.followers = 50000;
      g.s.money = 10000000;
      g.hire(staffOf('manager'));
      expect(g.energyCost(sing), (sing.energy * 0.8).round());
      expect(g.energyCost(sing), lessThan(before));
      g.endDay(0);
      expect(g.s.ledger.any((l) => l.label.contains('매니저') && l.amount == -staffOf('manager').wage), isTrue);
      g.dismiss(staffOf('manager'));
      expect(g.hasStaff('manager'), isFalse);
    });

    test('편집자는 밤마다 영상을 올려 구독자를 늘린다', () async {
      final g = await make();
      g.s.followers = 6000;
      g.s.money = 1000000;
      g.s.gear['pc'] = 1;
      g.s.lastViewers = 300;
      g.hire(staffOf('editor'));
      final f = g.s.followers;
      g.endDay(0);
      expect(g.s.followers, greaterThan(f));
      expect(g.s.log.any((l) => l.text.contains('편집자')), isTrue);
    });
  });

  group('순위 이벤트', () {
    test('순위가 낮으면 순위 이벤트가 없다', () async {
      final g = await make();
      expect(g.rollEvent('rank', 1), isNull);
    });

    test('상위권이 되면 CF·뉴스·공중파·1위 이벤트가 열린다', () async {
      final g = await make();
      g.s.lastRanks = {'me': 10};
      expect(gameEvents.where((e) => e.where == 'rank' && e.when(g.s)).map((e) => e.id), ['cf_model']);
      g.s.lastRanks = {'me': 1};
      final ids = gameEvents.where((e) => e.where == 'rank' && e.when(g.s)).map((e) => e.id).toSet();
      expect(ids, {'cf_model', 'news_interview', 'idol_variety', 'rank1_crown'});
      final ev = g.rollEvent('rank', 1)!;
      g.resolveEvent(ev, 0);
      // 한 번 겪으면 다시 오지 않는다
      expect(gameEvents.firstWhere((e) => e.id == ev.id).when(g.s), isFalse);
    });

    test('1위가 되면 아침에 순위 이벤트가 찾아온다', () async {
      var seen = false;
      for (var seed = 0; seed < 10 && !seen; seed++) {
        final g = await make(seed);
        g.s.followers = 50000000;
        g.s.flags.addAll(['goal_mid', 'goal_big', 'goal_celeb', 'goal_top']);
        final report = g.endDay(0);
        expect(g.myRank, 1);
        seen = report.news?.where == 'rank';
      }
      expect(seen, isTrue);
    });
  });

  group('DM', () {
    test('노래 방송 뒤에 아이돌 소속사 콜라보 제안이 DM으로 온다', () async {
      final g = await make();
      g.s.followers = 5000;
      final offer = streamUntilOffer(g, 'sing', want: 'idol_collab');
      expect(offer?.id, 'idol_collab');
      final dm = g.s.dms.firstWhere((d) => d.kind == 'offer');
      expect(dm.nick, offer!.from);
      expect(g.dmUnread, greaterThan(0));
      // 같은 제안은 답장 전까지 또 오지 않는다
      expect(g.s.dms.where((d) => d.offer == 'idol_collab').length, 1);
    });

    test('구독자가 적으면 제안이 오지 않는다', () async {
      final g = await make();
      g.s.followers = 100;
      const none = StreamResult(viewers: 50, gain: 0, donation: 0, ads: 0, viral: false, flop: false);
      expect(streamUntilOffer(g, 'sing', tries: 80, r: none), isNull);
    });

    test('제안을 수락하면 돈과 구독자가 늘고 SNS가 들썩인다', () async {
      final g = await make();
      g.s.followers = 5000;
      streamUntilOffer(g, 'sing', want: 'idol_collab');
      final dm = g.s.dms.firstWhere((d) => d.offer == 'idol_collab');
      final m = g.s.money, f = g.s.followers, trends = g.s.trends.length;
      final (text, changes, trend) = g.answerOffer(dm, accept: true);
      expect(dm.status, 'accepted');
      expect(text, contains('아이돌'));
      expect(changes, isNotEmpty);
      expect(g.s.money, greaterThan(m));
      expect(g.s.followers, greaterThan(f));
      expect(trend, isNotNull);
      expect(g.s.trends.length, trends + 1);
      // 두 번 답장할 수는 없다
      final (_, again, _) = g.answerOffer(dm, accept: true);
      expect(again, isEmpty);
    });

    test('거절하면 아무것도 변하지 않고, 답장이 없으면 4일 뒤 만료된다', () async {
      final g = await make();
      g.s.followers = 5000;
      streamUntilOffer(g, 'sing', want: 'idol_collab');
      final dm = g.s.dms.firstWhere((d) => d.offer == 'idol_collab');
      final m = g.s.money;
      g.answerOffer(dm, accept: false);
      expect(dm.status, 'declined');
      expect(g.s.money, m);

      final g2 = await make(2);
      g2.s.followers = 5000;
      g2.s.money = 10000000;
      streamUntilOffer(g2, 'sing', want: 'idol_collab');
      final dm2 = g2.s.dms.firstWhere((d) => d.kind == 'offer');
      for (var i = 0; i < 4; i++) {
        g2.endDay(0);
      }
      expect(dm2.status, 'expired');
    });

    test('말실수를 하면 욕 DM이 오고, 읽으면 멘탈이 깎인다 (강행이 더 많다)', () async {
      final g = await make();
      g.s.followers = 2000;
      g.resolveGaffe(gaffes.first, good, apologize: false);
      final ignoreHate = g.s.dms.where((d) => d.kind == 'hate').length;
      final g2 = await make();
      g2.s.followers = 2000;
      g2.resolveGaffe(gaffes.first, good, apologize: true);
      final apologyHate = g2.s.dms.where((d) => d.kind == 'hate').length;
      expect(ignoreHate, greaterThan(apologyHate));
      expect(apologyHate, greaterThan(0));
      expect(g.toasts.any((t) => t.contains('DM')), isTrue);

      g.s.mental = 50;
      expect(g.readDms(), -8);
      expect(g.s.mental, 42);
      expect(g.dmUnread, 0);
      // 이미 읽은 DM은 다시 멘탈을 깎지 않는다
      expect(g.readDms(), 0);
    });

    test('DM은 저장된다', () async {
      final g = await make();
      g.s.followers = 5000;
      streamUntilOffer(g, 'sing', want: 'idol_collab');
      final back = GameState.fromJson(g.s.toJson());
      expect(back.dms.length, g.s.dms.length);
      expect(back.dms.first.offer, g.s.dms.first.offer);
      final old = g.s.toJson()..remove('dms');
      expect(GameState.fromJson(old).dms, isEmpty);
    });

    testWidgets('휴대폰 DM 탭에서 제안을 수락한다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late GameController g;
      await tester.runAsync(() async {
        g = await make();
      });
      g.s.followers = 5000;
      streamUntilOffer(g, 'sing', want: 'idol_collab');
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(child: TextButton(onPressed: () => showPhone(context, g), child: const Text('open'))),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dm-tab')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dm-tab')));
      await tester.pumpAndSettle();
      expect(g.dmUnread, 0);
      expect(find.textContaining('별무리'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('dm-accept-idol_collab')));
      await tester.pumpAndSettle();
      expect(find.textContaining('수락함'), findsOneWidget);
      expect(g.s.dms.firstWhere((d) => d.offer == 'idol_collab').status, 'accepted');
    });
  });
}
