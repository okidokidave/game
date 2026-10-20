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
  g.newGame('도트왕', const Look(hair: 0, shirt: 0xE85D5D));
  return g;
}

void main() {
  group('뷰티샵', () {
    test('기본 아이템은 처음부터 있고, 사면 바로 입는다', () async {
      final g = await make();
      expect(g.owns(styleOf('hair_short')), isTrue);
      expect(g.owns(styleOf('outfit_tee')), isTrue);
      final suit = styleOf('outfit_suit');
      expect(g.owns(suit), isFalse);
      expect(g.buyStyle(suit), isFalse); // 돈 부족
      g.s.money = 1000000;
      final q = quality(g.s, contentOf('talk'));
      expect(g.buyStyle(suit), isTrue);
      expect(g.s.money, 500000);
      expect(g.s.look.outfit, 'suit');
      expect(outfitColor(g.s.look), suit.color);
      expect(quality(g.s, contentOf('talk')), closeTo(q + suit.bonus, 1e-9));
      // 기본 옷으로 갈아입으면 처음 고른 색
      g.wear(styleOf('outfit_tee'));
      expect(outfitColor(g.s.look), 0xE85D5D);
    });

    test('헤어·염색·소품을 입혀 볼 수 있고 저장된다', () async {
      final g = await make();
      final pony = tryOn(g.s.look, styleOf('hair_pony'));
      expect(pony.hairStyle, 'pony');
      expect(pony.long, isFalse);
      g.s.money = 10000000;
      g.buyStyle(styleOf('dye_pink'));
      g.buyStyle(styleOf('acc_catears'));
      g.buyStyle(styleOf('hair_bob'));
      expect(g.s.look.hair, 0xF58BB0);
      expect(g.s.look.acc, 'catears');
      final back = GameState.fromJson(g.s.toJson());
      expect(back.look.hairStyle, 'bob');
      expect(back.look.acc, 'catears');
      expect(back.owned, containsAll(['dye_pink', 'acc_catears', 'hair_bob']));
      // 예전 저장 데이터
      final old = Look.fromJson(const {'hair': 1, 'shirt': 2, 'long': true});
      expect(old.hairStyle, 'long');
      expect(old.outfit, 'tee');
    });
  });

  group('뷰티샵 확장', () {
    test('분장·날개는 소품과 따로 입고, 함께 저장된다', () async {
      final g = await make();
      g.s.money = 10000000;
      expect(g.owns(styleOf('face_none')), isTrue);
      expect(g.owns(styleOf('back_none')), isTrue);
      final q = quality(g.s, contentOf('talk'));
      g.buyStyle(styleOf('acc_halo'));
      g.buyStyle(styleOf('face_clown'));
      g.buyStyle(styleOf('back_angel'));
      g.buyStyle(styleOf('hair_twin'));
      expect(g.s.look.acc, 'halo');
      expect(g.s.look.face, 'clown');
      expect(g.s.look.back, 'angel');
      expect(g.s.look.hairStyle, 'twin');
      final bonus = ['acc_halo', 'face_clown', 'back_angel', 'hair_twin'].map((id) => styleOf(id).bonus).reduce((a, b) => a + b);
      expect(quality(g.s, contentOf('talk')), closeTo(q + bonus, 1e-9));
      final back = GameState.fromJson(g.s.toJson());
      expect(back.look.face, 'clown');
      expect(back.look.back, 'angel');
      // 벗기
      g.wear(styleOf('back_none'));
      g.wear(styleOf('face_none'));
      expect(g.s.look.back, 'none');
      expect(g.s.look.face, 'none');
      expect(g.s.look.acc, 'halo');
      // 예전 저장 데이터에는 분장·날개가 없다
      final old = Look.fromJson(const {'hair': 1, 'shirt': 2});
      expect(old.face, 'none');
      expect(old.back, 'none');
    });

    test('새 아이템은 모두 탭에 들어가고 이름이 겹치지 않는다', () {
      for (final id in ['hair_afro', 'outfit_tux', 'outfit_dino', 'outfit_bear', 'outfit_kinder', 'acc_kinderhat', 'acc_helmet', 'face_oni', 'back_devil']) {
        final it = styleOf(id);
        expect(['hair', 'outfit', 'acc', 'face', 'back'], contains(it.kind));
        expect(it.price, greaterThan(0));
        expect(wearing(tryOn(const Look(hair: 0, shirt: 0), it), it), isTrue);
      }
      expect(styleItems.map((x) => x.id).toSet().length, styleItems.length);
    });
  });

  group('펫샵', () {
    test('분양하면 펫 방송이 열리고 매일 사료값이 나간다', () async {
      final g = await make();
      final pet = contentOf('pet');
      expect(canStream(g.s, pet), isFalse);
      expect(g.contentBlock(pet), contains('반려동물'));
      final cat = petOf('cat');
      expect(g.petBlock(cat), '돈 부족');
      g.s.money = 2000000;
      expect(g.adoptPet(cat), isTrue);
      expect(g.s.pet, 'cat');
      expect(canStream(g.s, pet), isTrue);
      expect(g.petBlock(petOf('dog')), '반려동물은 한 마리');
      g.endDay(0);
      expect(g.s.ledger.any((l) => l.label.contains('사료') && l.amount == -cat.food), isTrue);
      // 펫이 있어야 펫 사건이 열린다
      expect(gameEvents.firstWhere((e) => e.id == 'pet_keyboard').when(g.s), isTrue);
    });

    test('펫이 없으면 이번 주 대세가 펫 방송이 되지 않는다', () async {
      final g = await make();
      for (var i = 0; i < 70; i++) {
        g.endDay(0);
        expect(g.s.trend, isNot('pet'));
      }
    });
  });

  group('발자취', () {
    test('게임이 끝나면 회차 기록이 남고, 다음 판에서도 볼 수 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final g = GameController(SaveRepository(prefs), rng: Random(1))..newGame('첫판', const Look(hair: 0, shirt: 0));
      g.s.followers = 12000;
      g.finish(g.retireEndingKey());
      expect(g.lastRun!.followers, 12000);
      expect(g.lastRun!.ending, 'mid');
      final g2 = GameController(SaveRepository(prefs), rng: Random(2))..newGame('둘째판', const Look(hair: 0, shirt: 0));
      g2.s.followers = 500;
      g2.finish(g2.retireEndingKey());
      expect(g2.runs.map((r) => r.name), ['첫판', '둘째판']);
    });
  });

  testWidgets('프로필 → 뷰티샵에서 사고, 펫을 분양하고, 은퇴하면 발자취가 보인다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    late GameController g;
    await tester.runAsync(() async => g = await make(3));
    g.s.followers = 2000;
    g.s.money = 3000000;
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
    await tester.tap(find.byKey(const ValueKey('profile-button')));
    await wait(600);
    await tester.tap(find.byKey(const ValueKey('beauty-button')));
    await wait(600);
    await tester.tap(find.byKey(const ValueKey('beauty-tab-acc')));
    await wait(300);
    await tester.tap(find.byKey(const ValueKey('style-acc_glasses')));
    await wait(200);
    await tester.tap(find.byKey(const ValueKey('buy-acc_glasses')));
    await wait(300);
    expect(g.s.look.acc, 'glasses');
    await tester.tap(find.byKey(const ValueKey('beauty-tab-pet')));
    await wait(300);
    await tester.tap(find.byKey(const ValueKey('adopt-hamster')));
    await wait(300);
    expect(g.s.pet, 'hamster');
    await tester.tap(find.byKey(const ValueKey('sheet-close')).last);
    await wait(600);
    await tester.ensureVisible(find.byKey(const ValueKey('retire')));
    await tester.tap(find.byKey(const ValueKey('retire')));
    await wait(600);
    await tester.tap(find.byKey(const ValueKey('dlg-0')));
    await wait(800);
    expect(find.text('ENDING'), findsOneWidget);
    await tester.tap(find.text('📜 발자취 보기'));
    await wait(800);
    expect(find.text('📜 도트왕의 발자취'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('🔁 회차 기록'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('🔁 회차 기록'), findsOneWidget);
  });
}
