import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:influencer_sim/game/data.dart';
import 'package:influencer_sim/game/game_state.dart';
import 'package:influencer_sim/game/sns.dart';

void main() {
  final s = GameState(name: '도트왕', look: const Look(hair: 0, shirt: 0), wallColor: 0xE9DCCB, trend: 'talk', followers: 20000);

  test('이벤트 선택마다 이슈 글과 댓글 토론이 만들어진다', () {
    final sns = Sns(Random(3));
    for (final ev in gameEvents) {
      for (final c in ev.choices.where((c) => c.sns != null)) {
        final t = sns.topicFeed(s, c.sns!);
        expect(t.tag, isNot(contains('{name}')));
        expect(t.tag, contains('도트왕'));
        final main = t.posts.first;
        expect(main.news, isTrue);
        expect(main.text, startsWith('[이슈]'));
        expect(main.replies.length, greaterThanOrEqualTo(4));
        expect(t.posts.length, greaterThanOrEqualTo(5));
        // 같은 토론 안에서 문구가 겹치지 않는다
        final texts = [for (final p in t.posts.skip(1)) p.text.split(' #').first, for (final p in t.posts) ...p.replies.map((r) => r.text)];
        expect(texts.toSet().length, texts.length, reason: '${ev.id}: $texts');
        expect(t.shield + t.hate, greaterThan(0));
      }
    }
  });

  test('쉴드 위주 주제는 쉴드가 더 많다', () {
    final sns = Sns(Random(5));
    var shield = 0, hate = 0;
    for (var i = 0; i < 40; i++) {
      final t = sns.topicFeed(s, const SnsTopic(tag: 't', headline: 'h', tone: 0.9, hate: ['a', 'b'], shield: ['c', 'd']));
      shield += t.shield;
      hate += t.hate;
    }
    expect(shield, greaterThan(hate * 2));
  });

  test('장비가 없으면 화질을 지적하는 글이 올라올 수 있다', () {
    final sns = Sns(Random(1));
    final all = [for (var i = 0; i < 30; i++) ...sns.streamPosts(s, contents.first)];
    expect(all.any((p) => p.text.contains('화질') || p.text.contains('캠')), isTrue);
  });
}
