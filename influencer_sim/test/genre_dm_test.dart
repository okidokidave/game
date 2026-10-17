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
import 'package:influencer_sim/ui/sns_phone.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> make([int seed = 1]) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController(SaveRepository(await SharedPreferences.getInstance()), rng: Random(seed));
  g.newGame('도트왕', const Look(hair: 0, shirt: 0));
  return g;
}

StreamResult gain(int n) => StreamResult(viewers: 100, gain: n, donation: 0, ads: 0, viral: false, flop: false);

void main() {
  group('장르별 순위', () {
    test('장르마다 라이벌이 3명씩, 모든 콘텐츠에 장르가 있다', () {
      expect(rivals.length, 27);
      for (final c in contents) {
        expect(rivals.where((r) => r.genre == c.id).length, 3, reason: c.id);
        expect(genreTitles[c.id], isNotNull);
      }
      expect(rivals.map((r) => r.id).toSet().length, rivals.length);
    });

    test('그 장르로 방송해서 얻은 구독자로 장르 순위가 정해진다', () async {
      final g = await make();
      g.finishStream(contentOf('asmr'), gain(800));
      expect(g.genreFansOf('asmr'), 800);
      expect(g.genreFansOf('talk'), 0);
      expect(g.genreRank('asmr'), 3); // 슬라임 공장(500)만 제쳤다
      expect(g.bestGenre, ('asmr', 3));
      final back = GameState.fromJson(g.s.toJson());
      expect(back.genreFans['asmr'], 800);
    });

    test('장르 1위를 하면 칭호와 그 장르 특별 제안 DM이 온다', () async {
      final g = await make();
      g.finishStream(contentOf('study'), gain(60000));
      g.endDay(0);
      expect(g.genreRank('study'), 1);
      expect(g.s.flags, contains('crown_study'));
      expect(g.toasts.any((t) => t.contains('공부왕')), isTrue);
      final dm = g.s.dms.firstWhere((d) => d.offer == 'genre_study');
      expect(dm.kind, 'offer');
      final m = g.s.money;
      g.answerOffer(dm, accept: true);
      expect(g.s.money, greaterThan(m));
      // 한 번만
      final n = g.s.dms.length;
      g.endDay(0);
      expect(g.s.dms.where((d) => d.offer == 'genre_study').length, 1);
      expect(g.s.dms.length, greaterThanOrEqualTo(n));
      expect(g.achieved, contains('genreKing'));
    });

    test('라이벌은 성장 한계에 가까워지면 거의 크지 않는다 (기간 제한이 없어도)', () async {
      final g = await make();
      for (var i = 0; i < 400; i++) {
        g.endDay(0);
      }
      for (final r in rivals) {
        expect(g.rivalFollowers(r), lessThanOrEqualTo((r.peak * 1.05).round()), reason: r.id);
      }
    });
  });

  group('생뚱맞은 DM', () {
    test('아침마다 가끔 오고, 답장하면 결과가 정해진다', () async {
      final g = await make();
      g.s.followers = 5000;
      for (var i = 0; i < 40; i++) {
        g.endDay(0);
      }
      final weird = g.s.dms.where((d) => d.kind == 'weird').toList();
      expect(weird, isNotEmpty);
      final d = weird.first;
      final w = weirdOf(d.offer!.substring(6));
      final (note, _) = g.answerWeird(d, 0);
      expect(note, contains(w.replies[0].label));
      expect(d.status, 'answered');
      // 두 번 답장할 수는 없다
      final (_, again) = g.answerWeird(d, 1);
      expect(again, isEmpty);
    });

    test('돈 빌려 달라는 DM에 돈을 보내면 돈을 잃는다', () async {
      final g = await make();
      g.s.dms.insert(0, Dm(id: 'x', nick: '급전', color: 0, text: '돈 좀', day: 1, kind: 'weird', offer: 'weird_loan'));
      final m = g.s.money;
      g.answerWeird(g.s.dms.first, 0);
      expect(g.s.money, lessThan(m));
    });

    testWidgets('휴대폰 DM 탭에서 생뚱맞은 DM에 답장한다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late GameController g;
      await tester.runAsync(() async => g = await make());
      g.s.dms.insert(0, Dm(id: 'w1', nick: '사주왕', color: 0xFF6366F1, text: '사주 봐 드릴게요!', day: 1, kind: 'weird', offer: 'weird_fortune'));
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => showPhone(c, g, dmTab: true), child: const Text('open'))))),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dm-reply-w1-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('운이 아까워요'), findsOneWidget);
    });
  });

  group('SNS 반응', () {
    test('펫 방송 뒤에도 글이 올라오고, 다양한 종류의 글이 섞인다', () async {
      final g = await make();
      g.s.money = 2000000;
      g.adoptPet(petOf('cat'));
      final texts = <String>{};
      for (var i = 0; i < 40; i++) {
        g.finishStream(contentOf('pet'), gain(5));
        texts.addAll(g.s.feed.take(3).map((p) => p.text));
      }
      expect(texts.length, greaterThan(15));
      expect(texts.any((t) => snsExtra.values.expand((l) => l).any((l) => t.startsWith(l.split('{name}').first) && l.contains('팬아트') && t.contains('팬아트'))), isTrue);
    });
  });

  testWidgets('순위표에서 장르 탭을 고르면 장르 순위가 나온다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    late GameController g;
    await tester.runAsync(() async => g = await make(3));
    g.s.followers = 2000;
    g.s.genreFans['asmr'] = 2000;
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
    expect(find.textContaining('🎧3위'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rank-button')));
    await wait(500);
    await tester.ensureVisible(find.byKey(const ValueKey('rank-tab-asmr')));
    await tester.tap(find.byKey(const ValueKey('rank-tab-asmr')));
    await wait(300);
    expect(find.text('속삭임 유리'), findsOneWidget);
    expect(find.text('레전드 김피디'), findsNothing);
  });
}
