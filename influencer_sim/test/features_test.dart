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

Future<GameController> make([int seed = 1]) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController(SaveRepository(await SharedPreferences.getInstance()), rng: Random(seed));
  g.newGame('도트왕', const Look(hair: 0, shirt: 0));
  return g;
}

Trend trend(GameController g, {required int shield, required int hate}) {
  final t = g.sns.topicFeed(g.s, const SnsTopic(tag: '도트왕_테스트', headline: '테스트', tone: 0));
  t.shield = shield;
  t.hate = hate;
  g.pushTrend(t);
  return t;
}

void main() {
  group('이사', () {
    test('반지하에서 시작하고 생활비가 가장 싸다', () async {
      final g = await make();
      expect(g.s.house, 'banjiha');
      expect(g.rent, 7000);
    });

    test('구독자와 보증금이 있어야 한 단계씩 이사한다', () async {
      final g = await make();
      final oneroom = houseOf('oneroom'), officetel = houseOf('officetel');
      expect(g.moveBlock(officetel), '원룸부터');
      expect(g.moveBlock(oneroom), '구독자 1,000 필요');
      g.s.followers = 1500;
      expect(g.moveBlock(oneroom), '돈 부족');
      g.s.money = 600000;
      final q = quality(g.s, contents.first);
      expect(g.moveHouse(oneroom), isTrue);
      expect(g.s.house, 'oneroom');
      expect(g.s.money, 100000);
      expect(g.s.wallColor, oneroom.wall);
      expect(g.rent, 10000);
      expect(quality(g.s, contents.first), closeTo(q + 0.05, 1e-9));
      expect(g.moveBlock(houseOf('banjiha')), '이미 지나온 집');
      expect(g.s.ledger.first.label, contains('원룸'));
    });

    test('예전 저장 데이터는 원룸에 살고 있었던 것으로', () async {
      final g = await make();
      final json = g.s.toJson()..remove('house');
      expect(GameState.fromJson(json).house, 'oneroom');
    });
  });

  test('채팅 반응을 성공할수록 방송 결과가 커진다', () async {
    final g = await make();
    const r = StreamResult(viewers: 100, gain: 100, donation: 10000, ads: 0, viral: false, flop: false);
    final b = g.boostStream(r, 2);
    expect(b.viewers, 116);
    expect(b.gain, 120);
    expect(b.donation, 13000);
    expect(identical(g.boostStream(r, 0), r), isTrue);
  });

  group('SNS 대응', () {
    test('여론이 내 편이면 해명이 먹힌다', () async {
      final g = await make();
      g.s.heat = 30;
      final t = trend(g, shield: 9, hate: 1);
      final (summary, _) = g.respond(t, 'explain');
      expect(t.response, 'explain_ok');
      expect(summary, contains('먹혔다'));
      expect(g.s.heat, 24);
      expect(t.posts[1].side, 'me');
      expect(g.canRespond(t), isFalse);
    });

    test('고소하면 변호사비를 내고 안티가 절반으로', () async {
      final g = await make();
      g.s
        ..money = 1000000
        ..antis = 400
        ..heat = 30;
      final fee = g.lawyerFee;
      final t = trend(g, shield: 1, hate: 9);
      g.respond(t, 'sue');
      expect(g.s.money, 1000000 - fee);
      expect(g.s.antis, 200);
      expect(g.s.heat, 20);
    });

    test('팬 댓글 고정: 멘탈 회복, 고정 표시', () async {
      final g = await make();
      g.s.mental = 50;
      final t = trend(g, shield: 5, hate: 5);
      g.respond(t, 'pin');
      expect(g.s.mental, 58);
      expect(t.posts.any((p) => p.text.startsWith('📌')), isTrue);
    });

    test('지난 트렌드에는 대응할 수 없다', () async {
      final g = await make();
      final old = trend(g, shield: 1, hate: 1);
      trend(g, shield: 1, hate: 1);
      expect(g.canRespond(old), isFalse);
    });
  });

  group('인기 순위', () {
    test('처음에는 꼴찌, 하루가 지나면 라이벌도 성장한다', () async {
      final g = await make();
      expect(g.myRank, rivals.length + 1);
      g.endDay(0);
      expect(g.s.rivals['sua'], greaterThan(120));
    });

    test('누군가를 제치면 순위 상승 알림과 SNS 글', () async {
      final g = await make();
      g.toasts.clear();
      g.s.followers = 20000; // 수아·토리·곰돌이·민지를 한 번에 제침
      g.endDay(0);
      expect(g.myRank, lessThan(rivals.length + 1));
      expect(g.toasts.any((m) => m.startsWith('🏆 순위 상승')), isTrue);
      expect(g.s.feed.first.text, contains('도트왕'));
      expect(g.s.lastRanks['me'], g.myRank);
      expect(g.s.prevRanks['me'], rivals.length + 1); // ▲ 표시용: 하루 전 순위
    });
  });

  testWidgets('방송 중 반응 버튼을 누르면 보너스, 순위표와 이사 탭이 열린다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final g = await make(3);
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

    // 순위표
    await tester.tap(find.byKey(const ValueKey('rank-button')));
    await wait(500);
    expect(find.text('🏆 스트리머 인기 순위'), findsOneWidget);
    expect(find.text('레전드 김피디'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await wait(500);

    // 이사 탭
    await tester.tap(find.byKey(const ValueKey('act-shop')));
    await wait(500);
    await tester.tap(find.byKey(const ValueKey('shop-tab-2')));
    await wait(300);
    expect(find.text('거주 중'), findsOneWidget);
    expect(find.text('구독자 1,000 필요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await wait(500);

    // 방송 중 반응 버튼
    await tester.tap(find.byKey(const ValueKey('act-stream')));
    await wait(500);
    await tester.tap(find.byKey(const ValueKey('content-talk')));
    var tapped = false;
    for (var i = 0; i < 60 && !tapped; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final b = find.byKey(const ValueKey('react-button'));
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b);
        tapped = true;
      }
    }
    expect(tapped, isTrue);
    // 방송 끝까지 (사건이 나오면 첫 선택지)
    for (var i = 0; i < 80 && find.textContaining('채팅 반응').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final d = find.byKey(const ValueKey('dlg-0'));
      if (d.evaluate().isNotEmpty && find.textContaining('채팅 반응').evaluate().isEmpty) {
        await tester.tap(d);
        await wait(300);
        final close = find.byKey(const ValueKey('phone-close'));
        if (close.evaluate().isNotEmpty) {
          await tester.tap(close);
          await wait(400);
        }
      }
    }
    expect(find.textContaining('채팅 반응 1/'), findsOneWidget);
  });
}
