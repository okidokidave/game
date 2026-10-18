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

void main() {
  group('주식·코인', () {
    test('사면 주식 방송이 열리고, 팔면 손익이 통장에 들어온다', () async {
      final g = await make();
      final stock = contentOf('stock');
      expect(canStream(g.s, stock), isFalse);
      expect(g.contentBlock(stock), contains('재테크'));
      g.s.money = 1000000;
      final a = assetOf('kinggod');
      expect(g.buyAsset(a, 300000), isTrue);
      expect(g.s.holdings['kinggod'], 4); // 72,000원 × 4주
      expect(g.s.flags, contains('investor'));
      expect(canStream(g.s, stock), isTrue);
      g.s.prices['kinggod'] = 90000;
      final m = g.s.money;
      final profit = g.sellAsset(a);
      expect(profit, greaterThan(0));
      expect(g.s.money, greaterThan(m));
      expect(g.s.holdings['kinggod'], isNull);
    });

    test('시세는 매일 밤 움직이고 코인이 주식보다 크게 흔들린다', () async {
      final g = await make();
      double spread(String id) {
        final h = g.s.priceHist[id]!;
        var t = 0.0;
        for (var i = 1; i < h.length; i++) {
          t += (h[i] / h[i - 1] - 1).abs();
        }
        return t / (h.length - 1);
      }

      for (var i = 0; i < 19; i++) {
        g.endDay(0);
      }
      expect(g.s.priceHist['kinggod']!.length, 20);
      expect(spread('dotcoin'), greaterThan(spread('kinggod') * 2));
      expect(g.priceOf(assetOf('mungcoin')), greaterThan(0));
      final back = GameState.fromJson(g.s.toJson());
      expect(back.prices['dotcoin'], g.s.prices['dotcoin']);
    });
  });

  group('추천 종목', () {
    test('추천한 종목이 오르면 구독자, 떨어지면 내 돈 내놔 DM', () async {
      var wins = 0, losses = 0;
      for (var seed = 0; seed < 40 && (wins == 0 || losses == 0); seed++) {
        final g = await make(seed);
        g.s.followers = 5000;
        g.s.flags.add('investor');
        g.setPick(assetOf('dotcoin'), 2000);
        final f = g.s.followers;
        g.endDay(0);
        expect(g.s.pickId, isNull);
        if (g.s.pickWins == 1) {
          wins++;
          expect(g.s.followers, greaterThan(f));
          expect(g.genreFansOf('stock'), greaterThan(0));
        }
        if (g.s.pickLosses == 1) {
          losses++;
          expect(g.s.dms.where((d) => d.kind == 'hate' && (d.text.contains('돈') || d.text.contains('물렸') || d.text.contains('책임') || d.text.contains('추천') || d.text.contains('리딩'))).length, greaterThanOrEqualTo(3));
          expect(g.s.flags, contains('pickFailed'));
          expect(gameEvents.firstWhere((e) => e.id == 'lead_probe').when(g.s), isTrue);
        }
      }
      expect(wins, greaterThan(0));
      expect(losses, greaterThan(0));
    });
  });

  group('부동산·복권', () {
    test('부동산을 사면 매일 임대 수익이 들어온다', () async {
      final g = await make();
      final e = estateOf('store');
      expect(g.estateBlock(e), contains('구독자'));
      g.s.followers = 6000;
      g.s.money = e.price;
      expect(g.buyEstate(e), isTrue);
      g.endDay(0);
      expect(g.s.ledger.any((l) => l.label.contains('임대 수익') && l.amount == e.rent), isTrue);
      final got = g.sellEstate(e);
      expect(got, greaterThan(e.price * 0.9));
    });

    test('복권은 하루 5장까지, 꽝이거나 당첨', () async {
      final g = await make();
      g.s.money = 1000000;
      var spent = 0;
      for (var i = 0; i < 5; i++) {
        final (_, prize) = g.buyLotto();
        expect(prize, greaterThanOrEqualTo(0));
        spent++;
      }
      expect(spent, 5);
      expect(g.lottoLeft, 0);
      expect(g.buyLotto().$2, -1);
      g.endDay(0);
      expect(g.lottoLeft, lottoPerDay);
    });
  });

  testWidgets('재테크 화면에서 주식을 사고 복권을 긁는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    late GameController g;
    await tester.runAsync(() async => g = await make(3));
    g.s.followers = 500;
    g.s.money = 2000000;
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
    await tester.tap(find.byKey(const ValueKey('act-invest')));
    await wait(600);
    await tester.tap(find.byKey(const ValueKey('buy-kinggod-100000')));
    await wait(300);
    expect(g.s.holdings['kinggod'], 1);
    await tester.tap(find.byKey(const ValueKey('invest-tab-lotto')));
    await wait(300);
    await tester.tap(find.byKey(const ValueKey('lotto-buy')));
    await wait(400);
    expect(find.textContaining(RegExp('꽝|당첨')), findsOneWidget);
  });
}
