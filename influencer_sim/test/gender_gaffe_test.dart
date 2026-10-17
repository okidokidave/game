import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/ads/ad_service.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/rules.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:influencer_sim/game/sns.dart';
import 'package:influencer_sim/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 방송할 때마다 말실수가 일어나는 컨트롤러 (테스트용)
class AlwaysGaffe extends GameController {
  AlwaysGaffe(super.repo, {super.rng});
  @override
  Gaffe? rollGaffe(Content c) => gaffes.first;
}

Future<SaveRepository> repo() async {
  SharedPreferences.setMockInitialValues({});
  return SaveRepository(await SharedPreferences.getInstance());
}

GameState state(String gender, {int followers = 20000}) =>
    GameState(name: '도트왕', look: Look(hair: 0, shirt: 0, gender: gender), wallColor: 0xE9DCCB, trend: 'talk', followers: followers);

const r0 = StreamResult(viewers: 1000, gain: 200, donation: 100000, ads: 30000, viral: false, flop: false);

void main() {
  test('여자 방송인은 남자 팬이, 남자 방송인은 여자 팬이 많게 시작한다', () {
    expect(state('f').maleFans, greaterThan(0.6));
    expect(state('m').maleFans, lessThan(0.4));
  });

  test('게임 방송을 하면 남자 팬 비율이 조금씩 오른다', () async {
    final g = GameController(await repo(), rng: Random(1));
    g.newGame('도트왕', const Look(hair: 0, shirt: 0, gender: 'm'));
    final before = g.s.maleFans;
    for (var i = 0; i < 5; i++) {
      g.finishStream(contentOf('game'), const StreamResult(viewers: 100, gain: 50, donation: 0, ads: 0, viral: false, flop: false));
    }
    expect(g.s.maleFans, greaterThan(before));
  });

  test('팬은 성별에 맞게 부른다 (형/누나/오빠/언니)', () {
    expect(sibling('m', 'm'), '형');
    expect(sibling('m', 'f'), '누나');
    expect(sibling('f', 'm'), '오빠');
    expect(sibling('f', 'f'), '언니');
    final sns = Sns(Random(2));
    final s = state('m')..maleFans = 0.1; // 거의 여자 팬
    final texts = [for (var i = 0; i < 30; i++) ...sns.topicFeed(s, snsGaffeApology).posts.expand((p) => [p, ...p.replies])];
    expect(texts.any((p) => p.text.contains('오빠')), isTrue);
    expect(texts.any((p) => p.text.contains('누나') || p.text.contains('언니')), isFalse);
    expect(texts.where((p) => !p.news).every((p) => p.g == 'm' || p.g == 'f'), isTrue);
  });

  test('열애설은 이성 팬의 반응이 더 나쁘다', () {
    final sns = Sns(Random(3));
    final s = state('f')..maleFans = 0.5;
    final topic = gameEvents.firstWhere((e) => e.id == 'dating').choices.first.sns!;
    var maleHate = 0, maleAll = 0, femaleHate = 0, femaleAll = 0;
    for (var i = 0; i < 80; i++) {
      for (final p in sns.topicFeed(s, topic).posts.skip(1)) {
        if (p.g == 'm') {
          maleAll++;
          if (p.side == 'hate') maleHate++;
        } else {
          femaleAll++;
          if (p.side == 'hate') femaleHate++;
        }
      }
    }
    expect(maleHate / maleAll, greaterThan(femaleHate / femaleAll + 0.1));
  });

  test('말실수 후 사과 없이 강행하면 팬이 떠나고 안티가 생긴다', () async {
    final g = GameController(await repo(), rng: Random(4));
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 10000;
    final out = g.resolveGaffe(gaffes.first, r0, apologize: false);
    expect(g.s.followers, 9400);
    expect(g.s.antis, greaterThan(0));
    expect(g.s.heat, 16);
    expect(out.result.viewers, lessThan(r0.viewers * 0.6));
    expect(out.trend.tag, '도트왕_사과해');
    expect(out.trend.headline, contains(gaffes.first.quote));
    expect(out.changes.map((c) => c.label), containsAll(['팬 이탈', '안티']));
  });

  test('사과하면 그 방송 수입은 없고, 3주 자숙 동안 수입 없이 생활비만 나간다', () async {
    final g = GameController(await repo(), rng: Random(4));
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 10000;
    g.s.day = 10;
    final out = g.resolveGaffe(gaffes.first, r0, apologize: true);
    expect(out.result.donation + out.result.ads + out.result.gain, 0);
    expect(g.s.antis, 0);
    expect(out.trend.tag, '도트왕_사과방송');

    final money = g.s.money;
    final h = g.startHiatus();
    expect(h.days, 21);
    expect(g.s.day, 31);
    expect(g.s.slot, 0);
    expect(g.s.money, money - 21 * g.rent);
    expect(g.s.heat, 0);
    expect(h.trend!.tag, '도트왕_복귀');
    // 강행(6% 즉시 이탈 + 안티)보다 팬이 덜 떠난다
    expect(h.lostFans, inInclusiveRange(150, 400));
  });

  test('통장 내역: 생활비가 매일 나가고, 수입·지출이 기록된다', () async {
    final g = GameController(await repo(), rng: Random(4));
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.work();
    g.endDay(0);
    expect(g.s.money, 30000 + 60000 - g.rent);
    expect(g.s.ledger.map((l) => l.label), containsAll(['편의점 알바', '생활비 (반지하)']));
    g.s.money = 0;
    final mental = g.s.mental;
    g.endDay(0);
    expect(g.s.money, -g.rent);
    expect(g.s.mental, lessThan(mental + 5)); // 마이너스 통장이면 멘탈이 깎인다
  });

  test('안티가 많으면 새 팬이 덜 생기고 악플이 늘어난다', () {
    final clean = state('f', followers: 5000);
    final hated = state('f', followers: 5000)..antis = 5000;
    final c = contentOf('talk');
    expect(calcStream(hated, c, Random(9)).gain, lessThan(calcStream(clean, c, Random(9)).gain));
    var cleanHate = 0, hatedHate = 0;
    for (var i = 0; i < 40; i++) {
      cleanHate += Sns(Random(i)).topicFeed(clean, snsGaffeApology).hate;
      hatedHate += Sns(Random(i)).topicFeed(hated, snsGaffeApology).hate;
    }
    expect(hatedHate, greaterThan(cleanHate));
  });

  testWidgets('말실수 → 사과 방송: 크로마키 자막이 뜨고 SNS 반응으로 이어진다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final game = AlwaysGaffe(await repo(), rng: Random(5));
    game.newGame('도트왕', const Look(hair: 0, shirt: 0, gender: 'm'));
    game.s.followers = 3000;
    await tester.pumpWidget(InfluencerApp(game: game, ads: NoAdService(), liveDuration: const Duration(milliseconds: 400)));
    Future<void> wait(int ms) async {
      for (var i = 0; i < ms ~/ 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await wait(400);
    await tester.tap(find.byKey(const ValueKey('continue')));
    await wait(800);
    await tester.tap(find.byKey(const ValueKey('act-stream')));
    await wait(500);
    await tester.tap(find.byKey(const ValueKey('content-talk')));
    await wait(500);
    expect(find.text('방송 사고! 말실수'), findsOneWidget);
    await tester.tap(find.text('사과하고 3주간 자숙한다'));
    await wait(150);
    expect(game.s.mode, 'apology');
    expect(find.text('죄송합니다'), findsOneWidget);
    await wait(600);
    expect(find.text('사과 방송을 마쳤다'), findsOneWidget);
    await tester.tap(find.text('📱 SNS 반응 보기'));
    await wait(600);
    expect(find.text('#도트왕_사과방송'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('phone-close')));
    await wait(300);
    // 검은 화면에서 3주가 흐른다
    expect(find.text('자숙 기간'), findsOneWidget);
    await wait(1500);
    expect(find.text('3주 후…'), findsWidgets);
    expect(game.s.day, 22);
    await tester.tap(find.text('📱 SNS 반응 보기'));
    await wait(600);
    expect(find.text('#도트왕_복귀'), findsOneWidget);
    expect(game.s.antis, 0);
  });
}
