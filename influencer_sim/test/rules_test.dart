import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/rules.dart';

GameState fresh() => GameState(name: '테스트', look: const Look(hair: 0, shirt: 0), wallColor: 0xE9DCCB, trend: 'talk');

/// 웹 버전 밸런스 확인에 쓴 단순한 플레이 방식 (장비는 싼 것부터, 알바로 초반 자금)
int simulate(Random rng) {
  final s = fresh();
  for (var d = 1; d <= 60; d++) {
    s.day = d;
    if (d % 7 == 1) s.trend = contents[rng.nextInt(contents.length)].id;
    var bought = true;
    while (bought) {
      bought = false;
      final opts = [
        for (final g in gearTypes)
          if (s.gear[g.key]! + 1 < g.tiers.length) (g.tiers[s.gear[g.key]! + 1].price, g.key),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      if (opts.isNotEmpty && opts.first.$1 <= s.money) {
        s.money -= opts.first.$1;
        s.gear[opts.first.$2] = s.gear[opts.first.$2]! + 1;
        bought = true;
      }
      for (final dc in decos) {
        if (!s.deco.contains(dc.id) && dc.price <= s.money * 0.2) {
          s.money -= dc.price;
          s.deco.add(dc.id);
          break;
        }
      }
    }
    for (var slot = 0; slot < 3; slot++) {
      s.slot = slot;
      if (s.energy < 25) {
        s.energy += 25;
        continue;
      }
      final next = [for (final g in gearTypes) if (s.gear[g.key]! + 1 < g.tiers.length) g.tiers[s.gear[g.key]! + 1].price].fold<int>(1 << 40, min);
      if (slot == 0 && s.money < next && s.followers < 3000) {
        s.money += 60000;
        s.energy -= 22;
        continue;
      }
      if (slot == 1 && s.gear['pc']! >= 1 && rng.nextDouble() < 0.4) {
        final u = calcUpload(s, rng);
        s.followers += u.gain;
        s.money += u.ads;
        s.energy -= 15;
        continue;
      }
      Content? best;
      var bv = -1.0;
      for (final c in contents.where((c) => canStream(s, c))) {
        final v = quality(s, c) * c.base * (s.trend == c.id ? 1.5 : 1) * (s.lastContent == c.id ? 0.85 : 1);
        if (v > bv) {
          bv = v;
          best = c;
        }
      }
      final r = calcStream(s, best!, rng);
      s.followers += r.gain;
      s.money += r.donation + r.ads - best.cost;
      s.energy -= best.energy;
      s.skills[best.id] = (s.skills[best.id] ?? 0) + 1;
      s.lastContent = best.id;
      s.lastViewers = r.viewers;
      if (rng.nextDouble() < 0.35) s.followers += (s.followers * 0.04).round();
    }
    s.energy = min(100, s.energy + 45);
  }
  return s.followers;
}

void main() {
  test('장비가 좋을수록 품질 배율이 오른다', () {
    final s = fresh();
    final base = quality(s, contents.first);
    s.gear['camera'] = 3;
    expect(quality(s, contents.first), greaterThan(base));
  });

  test('게임 방송은 PC가 있어야 할 수 있다', () {
    final s = fresh();
    final game = contentOf('game');
    expect(canStream(s, game), isFalse);
    s.gear['pc'] = 1;
    expect(canStream(s, game), isTrue);
  });

  test('등급 이름', () {
    expect(rankOf(0).name, '방구석 방송인');
    expect(rankOf(12000).name, '중소 스트리머');
    expect(rankOf(2000000).name, '레전드 스트리머');
  });

  test('밸런스: 보통 플레이는 수십만, 100만은 잘해야 가능', () {
    final rng = Random(7);
    final results = [for (var i = 0; i < 120; i++) simulate(rng)]..sort();
    final median = results[results.length ~/ 2];
    final p90 = results[(results.length * 0.9).floor()];
    expect(median, inInclusiveRange(150000, 800000));
    expect(p90, lessThan(2000000));
    expect(results.first, greaterThan(10000));
  });

  test('수익화 전에는 광고 수익이 없다', () {
    final s = fresh();
    final r = calcStream(s, contents.first, Random(1));
    expect(r.ads, 0);
    s.followers = 5000;
    expect(calcStream(s, contents.first, Random(1)).ads, greaterThan(0));
  });
}
