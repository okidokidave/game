import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/ui/minigame.dart';

Future<double?> play(WidgetTester tester, String content, Future<void> Function() act) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  double? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(child: MinigameView(key: UniqueKey(), spec: miniFor(contentOf(content)), duration: const Duration(seconds: 3), rng: Random(1), onDone: (v) => result = v)),
    ),
  ));
  await act();
  for (var i = 0; i < 100 && result == null; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return result;
}

void main() {
  test('콘텐츠마다 다른 미니게임', () {
    expect(miniFor(contentOf('mukbang')).kind, MiniKind.mash);
    expect(miniFor(contentOf('sing')).kind, MiniKind.timing);
    expect(miniFor(contentOf('react')).kind, MiniKind.reaction);
    expect(miniFor(contentOf('asmr')).kind, MiniKind.hold);
    expect(miniFor(contentOf('talk')).kind, MiniKind.targets);
    expect(miniFor(contentOf('pet'), petIcon: '🐱').good, ['🐱']);
    expect([starsOf(0.1), starsOf(0.3), starsOf(0.6), starsOf(0.9)], [0, 1, 2, 3]);
  });

  testWidgets('먹방: 연타하면 별 3개, 가만히 있으면 0개', (tester) async {
    final full = await play(tester, 'mukbang', () async {
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.byKey(const ValueKey('mini-area')));
        await tester.pump(const Duration(milliseconds: 30));
      }
    });
    expect(starsOf(full!), 3);
    final idle = await play(tester, 'mukbang', () async {});
    expect(idle, 0);
  });

  testWidgets('노래: 박자를 맞히면 점수가 오른다', (tester) async {
    final r = await play(tester, 'sing', () async {
      // 음표가 초록 칸에 왔을 때만 누른다
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final s = tester.state(find.byType(MinigameView)) as dynamic;
        if (((s.markerPos as double) - (s.zone as double)).abs() < 0.03) {
          await tester.tap(find.byKey(const ValueKey('mini-area')));
        }
        if ((s.round as int) >= 5) break;
      }
    });
    expect(r, greaterThanOrEqualTo(0.6));
  });

  testWidgets('리액션: 미리 누르면 실패', (tester) async {
    final r = await play(tester, 'react', () async {
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const ValueKey('mini-area')));
        await tester.pump(const Duration(milliseconds: 40));
      }
    });
    expect(r, lessThan(0.25));
  });

  testWidgets('ASMR: 아무것도 안 하면 점수가 낮다', (tester) async {
    final r = await play(tester, 'asmr', () async {});
    expect(r, lessThan(0.5));
  });
}
