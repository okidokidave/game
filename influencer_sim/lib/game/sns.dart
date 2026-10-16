// 가상 SNS "버즈" — 플레이어의 행동마다 글과 댓글 토론을 만든다.
// tone(-1 ~ 1)과 플레이어의 이미지에 따라 악플과 쉴드의 비율이 달라진다.

import 'dart:math';

import 'data.dart';
import 'game_state.dart';

class SnsUser {
  const SnsUser(this.nick, this.handle, this.color);
  final String nick;
  final String handle;
  final int color;
}

class Sns {
  Sns(this.rng);
  final Random rng;

  static const _nickA = ['새벽', '치킨', '감자', '고양이', '월요일', '퇴근', '라면', '방구석', '분노의', '행복한', '졸린', '배고픈', '익명의', '눈팅', '프로', '야식', '민초', '출근', '주말', '솔직한', '지나가던', '댓글', '팝콘', '현실'];
  static const _nickB = ['러버', '요정', '장인', '집사', '중독자', '전문가', '1호팬', '고인물', '뉴비', '학생', '직장인', '탐정', '수집가', '관찰자', '백수', '토끼', '곰', '판사', '평론가', '참견러'];
  static const _handle = ['daily', 'real', 'just', 'im', 'the', 'mr', 'ms', 'lazy', 'night', 'pop', 'hot', 'cool', 'zz', 'yolo', 'nope', 'kkk'];
  static const _roman = ['potato', 'cat', 'ramen', 'chicken', 'bear', 'toki', 'mango', 'kimchi', 'sky', 'moon', 'pudding', 'mint', 'duck', 'star'];
  static const _colors = [0xFFFF8A65, 0xFFFFB74D, 0xFF81C784, 0xFF4FC3F7, 0xFF9575CD, 0xFFF06292, 0xFFA1887F, 0xFF4DB6AC, 0xFFE57373, 0xFF7986CB];

  T pick<T>(List<T> list) => list[rng.nextInt(list.length)];
  double _rand(double a, double b) => a + rng.nextDouble() * (b - a);

  SnsUser user() {
    final nick = pick(_nickA) + pick(_nickB) + (rng.nextDouble() < 0.3 ? '${_rand(1, 99).floor()}' : '');
    final handle = '${pick(_handle)}_${pick(_roman)}${rng.nextDouble() < 0.6 ? _rand(1, 999).floor() : ''}';
    return SnsUser(nick, handle, pick(_colors));
  }

  static String fill(String text, GameState s) => text.replaceAll('{name}', s.name);

  // 구독자에 비례한 반응 수
  int _reach(GameState s, double mult) => max(0, ((2 + pow(s.followers, 0.82) * 0.06) * mult * _rand(0.4, 1.6)).round());

  Post post(GameState s, String text, String side, {SnsUser? as, double boost = 1, bool news = false, String g = ''}) {
    final u = as ?? user();
    final likes = _reach(s, boost);
    return Post(
      id: rng.nextInt(1 << 32).toRadixString(36),
      nick: u.nick,
      handle: u.handle,
      color: u.color,
      text: fill(text, s),
      side: side,
      likes: likes,
      reposts: (likes * _rand(0.05, 0.4)).round(),
      day: s.day,
      slot: min(s.slot, 2),
      news: news,
      g: g,
    );
  }

  /// 팬 성비에 따라 글쓴이 성별을 고른다
  String fanGender(GameState s) => rng.nextDouble() < s.maleFans ? 'm' : 'f';

  /// 성별 말투 문구 (형/누나/오빠/언니). 쓸 문구가 없으면 null
  String? _genderedLine(String side, String g, GameState s, Set<String> used) {
    final pool = snsGendered[side]?[g]?.where((l) => !used.contains(l)).toList();
    if (pool == null || pool.isEmpty) return null;
    final line = pick(pool);
    used.add(line);
    return line.replaceAll('{sib}', sibling(g, s.look.gender));
  }

  /// 한 사람의 의견: 성별 → (이성 팬이면 tone 보정) → 진영 → 문구
  Post _voice(GameState s, SnsTopic topic, Set<String> used, {String? side, double boost = 1}) {
    final g = fanGender(s);
    final opposite = g != s.look.gender;
    final sd = side ?? _sideFor(topic.tone + (opposite ? topic.oppositeTone : 0), s);
    final line = (rng.nextDouble() < 0.35 ? _genderedLine(sd, g, s, used) : null) ?? _lineFor(sd, topic, used);
    return post(s, line, sd, boost: boost, g: g);
  }

  // tone과 이미지로 악플/쉴드 비율 결정
  String _sideFor(double tone, GameState s) {
    // 안티가 많을수록 악플이 늘어난다
    final antiShare = min(0.4, s.antis / (s.followers + 100));
    final t = (tone + s.image / 160 - antiShare).clamp(-1.0, 1.0);
    if (rng.nextDouble() < 0.18) return 'neutral';
    return rng.nextDouble() < (t + 1) / 2 ? 'shield' : 'hate';
  }

  // 같은 토론 안에서 같은 문구가 반복되지 않게 used에 기록
  String _lineFor(String side, SnsTopic topic, Set<String> used) {
    final own = topic.lines(side);
    final common = snsPool[side]!;
    final ownLeft = own.where((l) => !used.contains(l)).toList();
    final commonLeft = common.where((l) => !used.contains(l)).toList();
    var pool = ownLeft.isNotEmpty && (rng.nextDouble() < 0.7 || commonLeft.isEmpty) ? ownLeft : commonLeft;
    if (pool.isEmpty) pool = own.isNotEmpty ? own : common;
    final line = pick(pool);
    used.add(line);
    return line;
  }

  /// 주제(이벤트 선택)에 대한 토론 피드
  Trend topicFeed(GameState s, SnsTopic topic) {
    final tag = fill(topic.tag, s);
    final posts = <Post>[];
    final used = <String>{};

    // 이슈 정리 글 + 댓글 토론
    final main = post(
      s,
      topic.headline,
      'neutral',
      news: true,
      boost: 3,
      as: SnsUser(pick(['이슈정리봇', '실시간 이슈', '방송계 소식통', '커뮤 요약러']), pick(['issue_bot', 'live_issue', 'stream_news', 'comm_digest']), 0xFF546E7A),
    );
    main.text = '[이슈] ${main.text} #$tag';
    final nReplies = 4 + rng.nextInt(3);
    String? prev;
    for (var i = 0; i < nReplies; i++) {
      // 앞 댓글과 반대 진영이 답하는 경우가 많게 → 토론처럼 보이게
      final forced = prev != null && prev != 'neutral' && rng.nextDouble() < 0.55 ? (prev == 'hate' ? 'shield' : 'hate') : null;
      final reply = _voice(s, topic, used, side: forced, boost: 0.4);
      final side = reply.side;
      if (prev != null && side != 'neutral' && prev != side && prev != 'neutral' && rng.nextDouble() < 0.6) {
        reply.replyTo = main.replies.last.nick;
      }
      main.replies.add(reply);
      prev = side;
    }
    posts.add(main);

    final n = 4 + rng.nextInt(3);
    for (var i = 0; i < n; i++) {
      final p = _voice(s, topic, used);
      final side = p.side;
      if (rng.nextDouble() < 0.6) p.text += ' #$tag';
      if (rng.nextDouble() < 0.35) {
        final opp = side == 'hate'
            ? 'shield'
            : side == 'shield'
                ? 'hate'
                : _sideFor(topic.tone, s);
        p.replies.add(_voice(s, topic, used, side: opp, boost: 0.3));
      }
      posts.add(p);
    }

    final all = [...posts, for (final p in posts) ...p.replies];
    return Trend(
      tag: tag,
      headline: fill(topic.headline, s),
      shield: all.where((p) => p.side == 'shield').length,
      hate: all.where((p) => p.side == 'hate').length,
      day: s.day,
      posts: posts,
    );
  }

  /// 내 공식 계정 글 (side: 'me')
  Post myPost(GameState s, String text) => post(s, text, 'me', boost: 3, as: SnsUser(s.name, 'official_${s.name.hashCode.abs() % 1000}', 0xFFFF4D8D));

  /// 어떤 글에 달리는 반응 [n]개
  List<Post> reactions(GameState s, SnsTopic topic, int n) {
    final used = <String>{};
    return [for (var i = 0; i < n; i++) _voice(s, topic, used, boost: 0.5)];
  }

  /// 평범한 방송 후 올라오는 글 몇 개
  List<Post> streamPosts(GameState s, Content c, {bool viral = false, bool flop = false}) {
    final out = <Post>[];
    final n = viral ? 4 : 1 + rng.nextInt(2);
    for (var i = 0; i < n; i++) {
      final pool = viral && i < 2
          ? snsStream['viral']!
          : flop && i == 0
              ? snsStream['flop']!
              : snsStream[c.id]!;
      final side = flop && i == 0 ? 'hate' : 'fan';
      final g = fanGender(s);
      final line = (side == 'fan' && rng.nextDouble() < 0.35 ? _genderedLine('fan', g, s, {}) : null) ?? pick<String>(pool);
      out.add(post(s, line, side, boost: viral ? 4 : 1, g: g));
    }
    // 장비가 부족하면 지적하는 글
    final g = s.gear;
    if (g['camera'] == 0 && rng.nextDouble() < 0.45) {
      out.add(post(s, pick(snsStream['lowcam']!), 'neutral', g: fanGender(s)));
    } else if (g['mic'] == 0 && rng.nextDouble() < 0.45) {
      out.add(post(s, pick(snsStream['lowmic']!), 'neutral', g: fanGender(s)));
    } else if (g['light'] == 0 && rng.nextDouble() < 0.35) {
      out.add(post(s, pick(snsStream['dark']!), 'neutral', g: fanGender(s)));
    }
    return out;
  }

  List<Post> milestonePosts(GameState s, int at) => (snsMilestone[at] ?? const []).map((t) => post(s, t, 'fan', boost: 2, g: fanGender(s))).toList();
}
