import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> make({int seed = 1}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GameController(SaveRepository(prefs), rng: Random(seed));
}

void main() {
  test('새 게임: 스마트폰, 3만 원, 체력 100', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0x2A2230, shirt: 0xE85D5D));
    expect(g.s.money, 30000);
    expect(g.s.energy, 100);
    expect(g.s.gear.values, everyElement(0));
    expect(g.saved, isNotNull);
  });

  test('방송하면 체력이 줄고 구독자와 돈이 늘며 SNS 글이 올라온다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    final talk = contentOf('talk');
    final r = g.beginStream(talk);
    expect(g.s.mode, 'live');
    expect(g.s.energy, 100 - talk.energy);
    g.finishStream(talk, r);
    expect(g.s.followers, r.gain);
    expect(g.s.money, 30000 + r.donation + r.ads);
    expect(g.s.feed, isNotEmpty);
    expect(g.s.streams, 1);
    expect(g.s.mode, 'idle');
  });

  test('세 번 행동하면 하루가 끝나고 체력이 회복된다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.work();
    expect(g.advance(), isFalse);
    g.rest();
    expect(g.advance(), isFalse);
    g.work();
    expect(g.advance(), isTrue);
    final before = g.s.energy;
    g.endDay(0);
    expect(g.s.day, 2);
    expect(g.s.slot, 0);
    expect(g.s.energy, min(100, before + 45));
  });

  test('일찍 자면 체력을 더 회복한다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.energy = 10;
    final remaining = g.goSleep();
    expect(remaining, 2);
    g.endDay(remaining);
    expect(g.s.energy, 10 + 45 + 30);
  });

  test('이벤트 선택은 수치를 바꾸고 트렌드를 만든다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 5000;
    final ev = gameEvents.firstWhere((e) => e.id == 'wrong_donation');
    final out = g.resolveEvent(ev, 1);
    expect(g.s.heat, 25);
    expect(g.s.image, -18);
    expect(out.trend, isNotNull);
    expect(g.s.trends.single.tag, '도트왕_먹튀');
    expect(g.s.unread, greaterThan(0));
  });

  test('뒷광고를 하면 나중에 폭로 뉴스가 뜰 수 있다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 5000;
    g.resolveEvent(gameEvents.firstWhere((e) => e.id == 'diet_ad'), 1);
    expect(g.s.flags, contains('hiddenAd'));
    // 사건은 하루에 하나: 다음 날 아침부터 폭로될 수 있다
    g.s.day++;
    final news = [for (var i = 0; i < 200; i++) g.rollEvent('news', 1)].whereType<GameEvent>().map((e) => e.id).toSet();
    expect(news, contains('hidden_ad_exposed'));
  });

  test('논란이 100이 되면 자숙 엔딩', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.applyFx(const Fx(heat: 120));
    expect(g.overKey(), 'scandal');
    g.finish('scandal');
    expect(g.s.ended, 'scandal');
    expect(g.saved, isNull);
    expect(g.endingsSeen, ['scandal']);
  });

  test('은퇴 엔딩은 구독자와 이미지로 정해지고, 기간 제한은 없다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 1200000;
    g.s.image = 20;
    expect(g.retireEndingKey(), 'celeb_good');
    g.s.image = -20;
    expect(g.retireEndingKey(), 'celeb_bad');
    g.s.followers = 50;
    expect(g.retireEndingKey(), 'zero');
    g.s.day = 200;
    g.s.slot = 2;
    g.endDay(0);
    expect(g.s.day, 201);
    expect(g.s.ended, isNull);
  });

  test('목표를 달성하면 엔딩 도감에 오르고 계속 방송할 수 있다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 15000;
    expect(g.endDay(0).goal, 'mid');
    expect(g.endingsSeen, contains('mid'));
    expect(g.s.ended, isNull);
    // 같은 목표는 다시 뜨지 않는다
    expect(g.endDay(0).goal, isNull);
    g.s.followers = 1500000;
    expect(g.endDay(0).goal, 'big');
    expect(g.endDay(0).goal, 'celeb_good');
  });

  test('장비는 한 단계씩, 돈이 있어야 산다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    expect(g.buyGear('pc'), isFalse);
    expect(g.buyGear('camera'), isFalse); // 웹캠 8만 원 > 3만 원
    expect(g.buyGear('light'), isTrue); // LED 스탠드 3만 원
    expect(g.s.gear['light'], 1);
    expect(g.s.money, 0);
  });

  test('구독자 1천 명을 넘으면 마일스톤 알림', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 1500;
    g.checkMilestones();
    expect(g.s.milestones, [100, 1000]);
    expect(g.toasts, contains('🏆 수익화 달성!'));
  });

  test('저장하고 불러오면 그대로', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0x123456, shirt: 0x654321, long: true));
    g.s.followers = 777;
    g.resolveEvent(gameEvents.first, 0);
    g.save();
    final loaded = g.saved!;
    expect(loaded.name, '도트왕');
    expect(loaded.look.long, isTrue);
    expect(loaded.followers, g.s.followers);
    expect(loaded.trends.single.posts.first.replies, isNotEmpty);
    expect(loaded.toJson(), g.s.toJson());
  });

  test('성장 단계마다 다른 사건이 나온다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    Set<String> ids(int followers) {
      g.s.followers = followers;
      return gameEvents.where((e) => e.when(g.s)).map((e) => e.id).toSet();
    }

    expect(ids(50), contains('big_visit'));
    expect(ids(200), containsAll(['big_visit', 'big_collab']));
    expect(ids(50000), containsAll(['goods']));
    expect(ids(50000), isNot(contains('big_visit')));
    expect(ids(150000), contains('fanmeeting'));
    expect(ids(600000), containsAll(['fanmeeting', 'tv_show', 'award']));
  });

  test('팬미팅은 한 판에 한 번만', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 200000;
    final ev = gameEvents.firstWhere((e) => e.id == 'fanmeeting');
    expect(ev.when(g.s), isTrue);
    final out = g.resolveEvent(ev, 0);
    expect(out.trend!.tag, '도트왕_팬미팅');
    expect(g.s.mental, 95);
    expect(ev.when(g.s), isFalse);
  });

  test('대형 스트리머 깜짝 등장은 구독자가 크게 는다', () async {
    final g = await make();
    g.newGame('도트왕', const Look(hair: 0, shirt: 0));
    g.s.followers = 400;
    g.resolveEvent(gameEvents.firstWhere((e) => e.id == 'big_visit'), 0);
    expect(g.s.followers, 540);
  });
}
