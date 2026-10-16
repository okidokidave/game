import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/ads/ad_service.dart';
import 'package:influencer_sim/game/game_controller.dart';
import 'package:influencer_sim/game/save_repository.dart';
import 'package:influencer_sim/main.dart';
import 'package:influencer_sim/ui/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameController> pumpApp(WidgetTester tester, {int seed = 1}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final game = GameController(SaveRepository(prefs), rng: Random(seed));
  await tester.pumpWidget(InfluencerApp(game: game, ads: NoAdService(), liveDuration: const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 500));
  return game;
}

/// 방 애니메이션이 계속 돌아서 pumpAndSettle 대신 시간을 조금씩 흘린다.
Future<void> wait(WidgetTester tester, [int ms = 300]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> startNewGame(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('name-field')), '도트왕');
  await tester.scrollUntilVisible(find.byKey(const ValueKey('new-game')), 200, scrollable: find.byType(Scrollable).first);
  // 버튼이 화면 끝에 걸쳐 있으면 조금 더 올린다
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const ValueKey('new-game')));
  await wait(tester, 800);
  expect(find.text('도트왕의 방송 데뷔'), findsOneWidget);
  await tester.tap(find.text('방송 시작!'));
  await wait(tester);
}

/// 키 이름이 [prefix]로 시작하는 버튼들 (누를 수 있는 것만)
List<Element> buttons(String prefix) => find
    .byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix) && (w is Pressable || w is GradientButton || w is GhostButton))
    .evaluate()
    .where((e) => switch (e.widget) {
          Pressable(:final onTap) || GradientButton(:final onTap) || GhostButton(:final onTap) => onTap != null,
          _ => false,
        })
    .toList();

/// 떠 있는 팝업을 하나 처리한다. 처리했으면 true.
Future<bool> handlePopup(WidgetTester tester, Random rng) async {
  final close = find.byKey(const ValueKey('phone-close'));
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close);
    await wait(tester, 500);
    return true;
  }
  Future<bool> tapOne(List<Element> list, {bool random = true}) async {
    if (list.isEmpty) return false;
    await tester.tap(find.byWidget(list[random ? rng.nextInt(list.length) : 0].widget));
    await wait(tester, 400);
    return true;
  }

  if (await tapOne(buttons('content-'))) return true;
  if (await tapOne(buttons('dlg-'))) return true;
  // 상점: 살 수 있는 게 있으면 사고, 아니면 닫기
  if (await tapOne(buttons('buy-'), random: false)) return true;
  if (await tapOne(buttons('sheet-close'))) return true;
  return false;
}

bool enabled(WidgetTester tester, String id) => buttons('act-$id').isNotEmpty;

void main() {
  testWidgets('시작 화면 → 새 게임 → 방송 한 번', (tester) async {
    final game = await pumpApp(tester);
    expect(find.text('스트리머 키우기'), findsOneWidget);
    await startNewGame(tester);
    expect(find.text('DAY 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('act-stream')));
    await wait(tester);
    await tester.tap(find.byKey(const ValueKey('content-talk')));
    await tester.pump(const Duration(milliseconds: 10));
    expect(game.s.mode, 'live');
    expect(find.textContaining('LIVE'), findsOneWidget);

    final rng = Random(2);
    for (var i = 0; i < 20 && game.s.slot == 0; i++) {
      await wait(tester, 200);
      await handlePopup(tester, rng);
    }
    expect(game.s.slot, 1);
    expect(game.s.streams, 1);
    expect(game.s.feed, isNotEmpty);
  });

  testWidgets('SNS 버튼을 누르면 버즈 타임라인이 열린다', (tester) async {
    final game = await pumpApp(tester);
    await startNewGame(tester);
    game.pushFeed([game.sns.post(game.s, '{name} 방송 재밌다', 'fan')]);
    await wait(tester, 100);
    await tester.tap(find.byKey(const ValueKey('phone-button')));
    await wait(tester, 500);
    expect(find.text('🐝 버즈'), findsOneWidget);
    expect(find.textContaining('도트왕 방송 재밌다'), findsOneWidget);
    expect(game.s.unread, 0);
    await tester.tap(find.text('트렌드'));
    await wait(tester, 100);
    expect(find.textContaining('트렌드에 오른 적이 없어요'), findsOneWidget);
  });

  testWidgets('60일을 버튼으로 끝까지 플레이하면 엔딩이 나온다', (tester) async {
    final game = await pumpApp(tester, seed: 11);
    await startNewGame(tester);
    final rng = Random(11);
    var ended = false;
    for (var step = 0; step < 6000; step++) {
      if (game.s.ended != null && find.text('ENDING').evaluate().isNotEmpty) {
        ended = true;
        break;
      }
      if (await handlePopup(tester, rng)) continue;
      final s = game.s;
      String? act;
      if (s.money > 50000 && rng.nextDouble() < 0.4) {
        act = 'shop';
      } else if (s.energy < 30 && enabled(tester, 'rest')) {
        act = 'rest';
      } else if (s.slot == 0 && s.money < 100000 && enabled(tester, 'work')) {
        act = 'work';
      } else if (s.slot == 1 && rng.nextDouble() < 0.3 && enabled(tester, 'upload')) {
        act = 'upload';
      } else if (enabled(tester, 'stream')) {
        act = 'stream';
      } else if (enabled(tester, 'sleep')) {
        act = 'sleep';
      }
      if (act != null) {
        await tester.ensureVisible(find.byKey(ValueKey('act-$act')));
        await tester.tap(find.byKey(ValueKey('act-$act')));
      }
      await wait(tester, 100);
    }
    expect(ended, isTrue, reason: 'day ${game.s.day}');
    expect(game.saved, isNull);
    expect(game.endingsSeen, isNotEmpty);
    // 새 게임을 누르면 시작 화면으로
    await tester.tap(find.text('새 게임').last);
    await wait(tester, 800);
    expect(find.text('스트리머 키우기'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('new-game')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('new-game')), findsOneWidget);
  });

  testWidgets('이어하기', (tester) async {
    final game = await pumpApp(tester);
    await startNewGame(tester);
    game.s.followers = 4321;
    game.save();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(InfluencerApp(game: game, ads: NoAdService()));
    await wait(tester, 500);
    expect(find.textContaining('도트왕 · DAY 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue')));
    await wait(tester, 800);
    expect(find.text('4,321'), findsOneWidget);
    expect(find.text('도트왕의 방송 데뷔'), findsNothing);
  });
}
