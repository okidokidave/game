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

GameEvent eventOf(String id) => gameEvents.firstWhere((e) => e.id == id);

void main() {
  group('말실수', () {
    test('확률이 낮아졌고, 사고 뒤 열흘은 다시 일어나지 않는다', () async {
      final g = await make();
      final talk = contentOf('talk');
      expect(g.gaffeChance(talk), lessThanOrEqualTo(0.03));
      expect(g.gaffeChance(contentOf('react')), lessThanOrEqualTo(0.05));
      g.resolveGaffe(gaffes.first, const StreamResult(viewers: 300, gain: 50, donation: 5000, ads: 0, viral: false, flop: false), apologize: false);
      expect(g.gaffeChance(talk), 0);
      g.s.day += 9;
      expect(g.gaffeChance(talk), 0);
      g.s.day += 1;
      expect(g.gaffeChance(talk), greaterThan(0));
      expect(GameState.fromJson(g.s.toJson()).lastGaffe, g.s.lastGaffe);
    });
  });

  group('위기', () {
    test('유명해질수록 위기가 자주 온다', () async {
      final g = await make();
      g.s.followers = 1000;
      expect(g.crisisChance, 0);
      g.s.followers = 5000;
      final low = g.crisisChance;
      g.s.followers = 500000;
      final high = g.crisisChance;
      expect(low, greaterThan(0));
      expect(high, greaterThan(low));
      expect(high, lessThanOrEqualTo(0.15));
    });

    test('직원이 있어야 갑질 고소가 오고, 고소한 직원은 그만둔다', () async {
      final g = await make();
      g.s.followers = 10000;
      final ev = eventOf('staff_gapjil');
      expect(ev.when(g.s), isFalse);
      g.s.staff.add('editor');
      expect(ev.when(g.s), isTrue);
      expect(g.eventText(ev), contains('편집자'));
      expect(ev.choices.map((c) => c.label).join(), allOf(contains('합의금'), contains('변호사'), contains('사과')));
      final out = g.resolveEvent(ev, 0);
      expect(g.s.staff, isEmpty);
      expect(out.changes.any((c) => c.text == '퇴사'), isTrue);
      expect(ev.when(g.s), isFalse);
    });

    test('변호사를 선임하면 이길 수도, 질 수도 있다 (평판이 좋을수록 유리)', () async {
      final results = <bool>{};
      for (var seed = 0; seed < 30 && results.length < 2; seed++) {
        final g = await make(seed);
        g.s.followers = 10000;
        g.s.money = 10000000;
        g.s.staff.add('manager');
        final out = g.resolveEvent(eventOf('staff_gapjil'), 1);
        results.add(out.won!);
        expect(out.choice.result, out.won! ? contains('무혐의') : contains('패소'));
      }
      expect(results, {true, false});
      final g = await make();
      final lawyer = eventOf('staff_gapjil').choices[1];
      g.s.image = 60;
      final good = lawyer.chance!(g.s);
      g.s.image = -60;
      expect(lawyer.chance!(g.s), lessThan(good));
    });

    test('학폭 논란은 구독자 2만부터, 사과하면 인정한 셈이 된다', () async {
      final g = await make();
      final ev = eventOf('school_violence');
      g.s.followers = 10000;
      expect(ev.when(g.s), isFalse);
      g.s.followers = 20000;
      expect(ev.when(g.s), isTrue);
      final heat = g.s.heat;
      final out = g.resolveEvent(ev, 2);
      expect(out.won, isNull);
      expect(g.s.heat, greaterThan(heat));
      expect(out.trend!.tag, contains('학폭'));
      // 비난 여론이 크면 욕 DM도 온다
      expect(g.s.dms.where((d) => d.kind == 'hate'), isNotEmpty);
    });

    test('아침에 위기 이벤트가 찾아온다', () async {
      var seen = false;
      for (var seed = 0; seed < 60 && !seen; seed++) {
        final g = await make(seed);
        g.s.followers = 300000;
        // 순위 이벤트는 이미 겪은 것으로
        g.s.flags.addAll(['cfDone', 'newsDone', 'varietyDone', 'crownDone']);
        seen = g.endDay(0).news?.where == 'crisis';
      }
      expect(seen, isTrue);
    });
  });
}
