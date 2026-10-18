import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/rules.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> make([int seed = 1]) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController(SaveRepository(await SharedPreferences.getInstance()), rng: Random(seed));
  g.newGame('도트왕', const Look(hair: 0, shirt: 0));
  return g;
}

void main() {
  group('주식·코인 방송', () {
    test('구독자 3천 명부터 열린다 (직접 사고파는 재테크는 없다)', () async {
      final g = await make();
      final stock = contentOf('stock');
      expect(canStream(g.s, stock), isFalse);
      expect(g.contentBlock(stock), contains('구독자'));
      g.s.followers = stockFollowers;
      expect(canStream(g.s, stock), isTrue);
      g.save();
      expect(g.toasts.any((t) => t.contains('주식·코인 방송')), isTrue);
    });

    test('종목 시세는 매일 밤 움직이고 코인이 주식보다 크게 흔들린다', () async {
      final g = await make();
      double spread(String id) {
        final h = g.s.priceHist[id]!;
        var t = 0.0;
        for (var i = 1; i < h.length; i++) {
          t += (h[i] / h[i - 1] - 1).abs();
        }
        return t / (h.length - 1);
      }

      final money = g.s.money;
      for (var i = 0; i < 19; i++) {
        g.endDay(0);
      }
      expect(g.s.priceHist['kinggod']!.length, 20);
      expect(spread('dotcoin'), greaterThan(spread('kinggod') * 2));
      // 시세가 움직여도 돈은 생활비만 나간다
      expect(g.s.money, lessThan(money));
      final back = GameState.fromJson(g.s.toJson());
      expect(back.prices['dotcoin'], g.s.prices['dotcoin']);
    });

    test('추천한 종목이 오르면 구독자, 떨어지면 내 돈 내놔 DM', () async {
      var wins = 0, losses = 0;
      for (var seed = 0; seed < 40 && (wins == 0 || losses == 0); seed++) {
        final g = await make(seed);
        g.s.followers = 5000;
        g.setPick(assetOf('dotcoin'), 2000);
        final f = g.s.followers;
        final m = g.s.money;
        g.endDay(0);
        expect(g.s.pickId, isNull);
        // 추천 결과로 돈이 생기지는 않는다
        expect(g.s.money, lessThanOrEqualTo(m));
        if (g.s.pickWins == 1) {
          wins++;
          expect(g.s.followers, greaterThan(f));
          expect(g.genreFansOf('stock'), greaterThan(0));
        }
        if (g.s.pickLosses == 1) {
          losses++;
          expect(g.s.dms.where((d) => d.kind == 'hate').length, greaterThanOrEqualTo(3));
          expect(g.s.flags, contains('pickFailed'));
          expect(gameEvents.firstWhere((e) => e.id == 'lead_probe').when(g.s), isTrue);
        }
      }
      expect(wins, greaterThan(0));
      expect(losses, greaterThan(0));
    });
  });
}
