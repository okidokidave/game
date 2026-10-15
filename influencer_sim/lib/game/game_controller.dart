// 게임 진행 규칙. 화면(ui/)은 이 클래스의 메서드를 부르고, 결과를 받아 팝업으로 보여 준다.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'game_state.dart';
import 'rules.dart';
import 'save_repository.dart';
import 'sns.dart';

/// 수치 변화 한 줄 (결과 팝업의 칩)
class Change {
  const Change(this.label, this.text, this.good);
  final String label;
  final String text;

  /// true 좋음(초록) / false 나쁨(빨강) / null 변화 없음
  final bool? good;
}

class EventOutcome {
  const EventOutcome(this.choice, this.changes, this.trend);
  final EventChoice choice;
  final List<Change> changes;
  final Trend? trend;
}

class StreamOutcome {
  const StreamOutcome(this.result, this.trend);
  final StreamResult result;
  final Trend? trend;
}

class UploadOutcome {
  const UploadOutcome(this.result, this.trend);
  final UploadResult result;
  final Trend? trend;
}

/// 하루가 끝났을 때 결과
class DayReport {
  const DayReport({this.seasonOver = false, this.news});
  final bool seasonOver;

  /// 아침에 터진 뉴스 이벤트 (없으면 null)
  final GameEvent? news;
}

/// 방 화면 효과 (하트, 동전 등)
class RoomEffect {
  const RoomEffect(this.kind, this.count);
  final String kind;
  final int count;
}

class GameController extends ChangeNotifier {
  GameController(SaveRepository repo, {Random? rng}) : this._(repo, rng ?? Random());

  GameController._(this._repo, this.rng) : sns = Sns(rng);

  final SaveRepository _repo;
  final Random rng;
  final Sns sns;

  GameState? _state;
  GameState get s => _state!;
  bool get playing => _state != null;

  /// 화면에 띄울 짧은 알림 (마일스톤 등). 화면이 꺼내 간다.
  final List<String> toasts = [];

  final _effects = StreamController<RoomEffect>.broadcast();
  Stream<RoomEffect> get effects => _effects.stream;

  T _pick<T>(List<T> list) => list[rng.nextInt(list.length)];

  // ───── 저장 ─────
  GameState? get saved => _repo.load();
  List<String> get endingsSeen => _repo.endings();

  void save() {
    if (_state != null && _state!.ended == null) _repo.save(_state!);
  }

  void newGame(String name, Look look, {int wallColor = 0xE9DCCB}) {
    _state = GameState(name: name, look: look, wallColor: wallColor, trend: _pick(['talk', 'mukbang', 'sing']));
    log('📱 스마트폰 하나로 방송을 시작했다. 목표: 60일 안에 셀럽 되기!', 'day');
    save();
    notifyListeners();
  }

  void resume(GameState state) {
    _state = state..mode = 'idle';
    notifyListeners();
  }

  void log(String text, [String kind = '']) {
    s.log = [LogEntry(text, kind, s.day, min(s.slot, 2)), ...s.log].take(30).toList();
  }

  void setMode(String mode) {
    s.mode = mode;
    notifyListeners();
  }

  void emit(String kind, int count) => _effects.add(RoomEffect(kind, count));

  // ───── 행동 가능 여부 ─────
  /// 막혀 있으면 이유, 할 수 있으면 null
  String? actionBlock(String id) {
    final g = s.gear;
    switch (id) {
      case 'stream':
        final need = contents.where((c) => canStream(s, c)).map((c) => c.energy).reduce(min);
        if (s.energy < need) return '체력 부족';
      case 'upload':
        if (g['pc']! < 1) return 'PC 필요';
        if (s.lastViewers == 0) return '방송 기록 없음';
        if (s.energy < 15) return '체력 부족';
      case 'work':
        if (s.energy < 22) return '체력 부족';
    }
    return null;
  }

  /// 콘텐츠를 고를 수 없는 이유 (가능하면 null)
  String? contentBlock(Content c) {
    if (!canStream(s, c)) {
      return c.need.entries.where((e) => s.gear[e.key]! < e.value).map((e) => '${gearOf(e.key).label}: ${gearOf(e.key).tiers[e.value].name} 필요').join(', ');
    }
    if (s.energy < c.energy) return '체력 ${c.energy} 필요';
    if (c.cost > 0 && s.money < c.cost) return '돈 부족';
    return null;
  }

  // ───── 수치 적용 ─────
  List<Change> applyFx(Fx fx) {
    final changes = <Change>[];
    if (fx.followers != 0) {
      var d = (s.followers * fx.followers).round();
      if (fx.followers > 0) d = max(d, 3 + rng.nextInt(10));
      s.followers = max(0, s.followers + d);
      changes.add(_delta('구독자', d, shortNum));
    }
    if (fx.money != 0) {
      s.money += fx.money;
      if (fx.money > 0) s.earned += fx.money;
      changes.add(_delta('돈', fx.money, shortWon));
    }
    if (fx.image != 0) {
      s.image = (s.image + fx.image).clamp(-100, 100);
      changes.add(_delta('이미지', fx.image));
    }
    if (fx.heat != 0) {
      s.heat = (s.heat + fx.heat).clamp(0, 100);
      changes.add(_delta('논란', fx.heat, null, true));
    }
    if (fx.mental != 0) {
      s.mental = (s.mental + fx.mental).clamp(0, 100);
      changes.add(_delta('멘탈', fx.mental));
    }
    if (fx.energy != 0) {
      s.energy = (s.energy + fx.energy).clamp(0, 100);
      changes.add(_delta('체력', fx.energy));
    }
    if (fx.flag != null) s.flags.add(fx.flag!);
    if (fx.unflag != null) s.flags.remove(fx.unflag);
    return changes;
  }

  Change _delta(String label, int d, [String Function(int)? fmt, bool invert = false]) {
    final text = '${d > 0 ? '+' : ''}${(fmt ?? (n) => '$n')(d)}';
    return Change(label, text, d == 0 ? null : (invert ? d < 0 : d > 0));
  }

  // ───── SNS ─────
  void pushFeed(List<Post> posts) {
    s.feed = [...posts, ...s.feed].take(80).toList();
    s.unread += posts.length;
  }

  void pushTrend(Trend t) {
    s.trends = [...s.trends, t];
    if (s.trends.length > 12) s.trends = s.trends.sublist(s.trends.length - 12);
    pushFeed(t.posts);
  }

  void markRead() {
    s.unread = 0;
    save();
    notifyListeners();
  }

  void checkMilestones() {
    for (final m in milestones) {
      if (s.followers >= m.at && !s.milestones.contains(m.at)) {
        s.milestones.add(m.at);
        pushFeed(sns.milestonePosts(s, m.at));
        log('🏆 ${m.title}', 'milestone');
        toasts.add('🏆 ${m.title}');
        emit('heart', 14);
      }
    }
  }

  // ───── 이벤트 ─────
  GameEvent? rollEvent(String where, double chance) {
    if (rng.nextDouble() > chance) return null;
    final recent = s.seen.length > 5 ? s.seen.sublist(s.seen.length - 5) : s.seen;
    final pool = gameEvents.where((e) => e.where == where && e.when(s) && !recent.contains(e.id)).toList();
    if (pool.isEmpty) return null;
    var r = rng.nextDouble() * pool.fold<int>(0, (a, e) => a + e.weight);
    for (final e in pool) {
      r -= e.weight;
      if (r <= 0) return e;
    }
    return pool.last;
  }

  String eventText(GameEvent ev) => Sns.fill(ev.text(s), s);

  EventOutcome resolveEvent(GameEvent ev, int index) {
    s.seen.add(ev.id);
    if (s.seen.length > 10) s.seen.removeAt(0);
    final choice = ev.choices[index];
    final changes = applyFx(choice.fx(s));
    log('${ev.title}: ${choice.label}', 'event');
    Trend? trend;
    if (choice.sns != null) {
      trend = sns.topicFeed(s, choice.sns!);
      pushTrend(trend);
    }
    checkMilestones();
    save();
    notifyListeners();
    return EventOutcome(choice, changes, trend);
  }

  // ───── 방송 ─────
  /// 방송 시작: 체력과 비용을 쓰고 결과를 미리 계산한다 (연출 중 시청자 수 표시용).
  StreamResult beginStream(Content c) {
    s.energy -= c.energy;
    s.money -= c.cost;
    final r = calcStream(s, c, rng);
    s.mode = 'live';
    notifyListeners();
    return r;
  }

  /// 방송 중 사건이 생길 확률
  double liveEventChance(Content c) => 0.38 + (c.risky ? 0.15 : 0) - (c.calm ? 0.15 : 0);

  StreamOutcome finishStream(Content c, StreamResult r) {
    s.followers += r.gain;
    final income = r.donation + r.ads;
    s.money += income;
    s.earned += income;
    s.streams++;
    s.peak = max(s.peak, r.viewers);
    s.skills[c.id] = (s.skills[c.id] ?? 0) + 1;
    s.lastContent = c.id;
    s.lastViewers = r.viewers;
    s.mental = (s.mental - 2).clamp(0, 100);
    if (c.id == 'study') s.image = (s.image + 1).clamp(-100, 100);
    s.mode = 'idle';

    pushFeed(sns.streamPosts(s, c, viral: r.viral, flop: r.flop));
    log('${c.icon} ${c.name} · 시청자 ${shortNum(r.viewers)}명 · 구독자 +${shortNum(r.gain)}', r.viral ? 'viral' : (r.flop ? 'flop' : ''));
    checkMilestones();
    if (r.viral) emit('heart', 20);
    if (income > 0) emit('coin', 6);

    Trend? trend;
    if (r.viral) {
      trend = sns.topicFeed(
        s,
        SnsTopic(
          tag: '{name}_떡상',
          headline: '{name}의 ${c.name} 클립이 알고리즘을 탔다',
          tone: 0.6,
          hate: const ['이게 왜 뜨는지 모르겠음', '알고리즘 고장났나', '곧 거품 빠질 듯'],
          shield: const ['드디어 {name}이 빛을 보네', '원래 재밌었음 이제 알았냐', '클립 10번 돌려봄 ㅋㅋㅋ'],
          neutral: const ['추천 탭에 계속 뜸', '누군데 다들 얘기함?'],
        ),
      );
      pushTrend(trend);
    }
    save();
    notifyListeners();
    return StreamOutcome(r, trend);
  }

  String hintFor(Content c) {
    final g = s.gear;
    if (g['camera'] == 0) return '💡 시청자들이 화질을 아쉬워해요. 장비 쇼핑에서 웹캠을 살펴보세요.';
    if (g['mic'] == 0) return '💡 소리가 지직거린다는 반응이 있어요. 핀 마이크라도 장만해 보세요.';
    if (g['light'] == 0) return '💡 얼굴이 어둡게 나와요. 조명을 사면 화면이 확 살아나요.';
    if (g['pc'] == 0 && s.money > 300000) return '💡 노트북이 있으면 게임·리액션 방송과 영상 업로드를 할 수 있어요.';
    if (c.id != s.trend) return '💡 이번 주 대세 콘텐츠로 방송하면 시청자가 1.5배예요.';
    if (s.slot != 2) return '💡 밤 방송이 시청자가 가장 많아요.';
    return '💡 같은 콘텐츠를 연속으로 하면 시청자가 조금 줄어들어요.';
  }

  /// 방송 중 채팅 한 줄 (닉네임, 색, 내용)
  (String, int, String) chatLine(Content c) {
    final g = s.gear;
    final pools = [chatLines['any']!, chatLines['any']!, chatLines[c.id]!];
    if (g['camera'] == 0) pools.add(chatLines['lowcam']!);
    if (g['mic'] == 0) pools.add(chatLines['lowmic']!);
    if (g['light'] == 0 && s.slot == 2) pools.add(chatLines['dark']!);
    final u = sns.user();
    return (u.nick, u.color, Sns.fill(_pick(_pick(pools)), s));
  }

  // ───── 다른 행동 ─────
  UploadOutcome upload() {
    s.energy -= 15;
    s.mode = 'idle';
    final r = calcUpload(s, rng);
    s.followers += r.gain;
    s.money += r.ads;
    s.earned += r.ads;
    s.uploads++;
    s.mental = (s.mental - 1).clamp(0, 100);
    final c = contentOf(s.lastContent ?? 'talk');
    pushFeed(sns.streamPosts(s, c, viral: r.viral));
    log('✂️ 하이라이트 영상 업로드 · 조회수 ${shortNum(r.views)} · 구독자 +${shortNum(r.gain)}', r.viral ? 'viral' : '');
    checkMilestones();
    Trend? trend;
    if (r.viral) {
      trend = sns.topicFeed(
        s,
        const SnsTopic(
          tag: '{name}_쇼츠',
          headline: '{name} 쇼츠 영상, 하루 만에 조회수 폭발',
          tone: 0.5,
          hate: ['쇼츠로 뜬 사람은 금방 짐', '편집빨이네'],
          shield: ['쇼츠 보고 본방까지 정주행함', '{name} 편집 센스 미쳤다', '이 영상 중독성 있음 ㅋㅋ'],
          neutral: ['이 밈 어디서 시작된 거임?'],
        ),
      );
      pushTrend(trend);
    }
    save();
    notifyListeners();
    return UploadOutcome(r, trend);
  }

  static const _workText = [
    '편의점 야간 알바를 했다. 폐기 삼각김밥이 오늘의 저녁.',
    '편의점 알바를 했다. 진상 손님에게 시달렸다.',
    '편의점 알바를 했다. 손님이 "혹시 방송하시는 분?"이라고 물었다… 착각이었다.',
    '편의점 알바를 했다. 물건 정리하며 다음 방송 아이디어를 떠올렸다.',
  ];

  void work() {
    s.mode = 'away';
    s.energy -= 22;
    s.mental = (s.mental - 3).clamp(0, 100);
    final pay = s.slot == 2 ? 72000 : 60000;
    s.money += pay;
    log('🏪 ${_pick(_workText)} +${shortWon(pay)}');
    notifyListeners();
  }

  void rest() {
    s.mode = 'stand';
    s.energy = (s.energy + 25).clamp(0, 100);
    s.mental = (s.mental + 8).clamp(0, 100);
    log('${_pick(['🛋️ 뒹굴거리며 쉬었다.', '🛋️ 좋아하는 방송을 보며 쉬었다.', '🛋️ 산책을 다녀왔다. 머리가 맑아졌다.', '🛋️ 낮잠을 잤다.'])} 체력 +25, 멘탈 +8');
    notifyListeners();
  }

  /// 일찍 잠자리에 든다. 남은 시간만큼 체력을 더 회복.
  int goSleep() {
    final remaining = 2 - s.slot;
    log('😴 일찍 잠자리에 들었다.${remaining > 0 ? ' 체력 추가 회복 +${remaining * 15}' : ''}');
    s.slot = 2;
    s.mode = 'sleep';
    notifyListeners();
    return remaining;
  }

  /// 시간을 한 칸 보낸다. 밤이 지나면 true (화면이 [endDay]를 부른다).
  bool advance() {
    s.slot++;
    if (s.slot > 2) {
      s.slot = 2;
      s.mode = 'sleep';
      notifyListeners();
      return true;
    }
    save();
    notifyListeners();
    return false;
  }

  DayReport endDay(int remaining) {
    s.energy = (s.energy + 45 + remaining * 15).clamp(0, 100);
    s.mental = (s.mental + 5).clamp(0, 100);
    s.heat = (s.heat - 7).clamp(0, 100);
    s.day++;
    s.slot = 0;
    s.mode = 'idle';
    if (s.day > seasonDays) return const DayReport(seasonOver: true);

    final notes = <String>[];
    if (s.heat >= 60) {
      s.mental = (s.mental - 8).clamp(0, 100);
      notes.add('밤새 악플 알림이 울렸다. 멘탈 -8');
    }
    if (s.day % 7 == 1) {
      s.trend = _pick(contents.where((c) => c.id != s.trend).toList()).id;
      final c = contentOf(s.trend);
      notes.add('이번 주 대세 콘텐츠는 ${c.icon} ${c.name}! 시청자 1.5배');
    }
    log('D+${s.day} 아침이 밝았다.', 'day');
    for (final n in notes) {
      log(n, 'note');
    }
    final over = overKey() != null;
    final news = over ? null : rollEvent('news', s.flags.contains('hiddenAd') || s.flags.contains('lieDating') ? 0.2 : 0.06);
    save();
    notifyListeners();
    return DayReport(news: news);
  }

  // ───── 상점 ─────
  bool buyGear(String key) {
    final g = gearOf(key);
    final lv = s.gear[key]!;
    if (lv + 1 >= g.tiers.length) return false;
    final next = g.tiers[lv + 1];
    if (s.money < next.price) return false;
    s.money -= next.price;
    s.gear[key] = lv + 1;
    log('🛒 ${next.name} 구입! (-${shortWon(next.price)})', 'buy');
    pushFeed([sns.post(s, _pick(['{name} 장비 바꿨나? ${g.label} 확 좋아짐', '{name} 새 ${g.label} 플렉스 ㅋㅋ', '{name} 방송 퀄 점점 올라가네']), 'fan')]);
    toasts.add('${next.name} 설치 완료!');
    emit('coin', 8);
    save();
    notifyListeners();
    return true;
  }

  bool buyDeco(Deco d) {
    if (s.deco.contains(d.id) || s.money < d.price) return false;
    s.money -= d.price;
    s.deco.add(d.id);
    log('🛒 ${d.name} 구입! (-${shortWon(d.price)})', 'buy');
    toasts.add('${d.name}을(를) 방에 놓았어요');
    save();
    notifyListeners();
    return true;
  }

  void setWall(int color) {
    s.wallColor = color;
    save();
    notifyListeners();
  }

  // ───── 종료 ─────
  /// 게임 오버 조건이면 엔딩 키
  String? overKey() {
    if (s.heat >= 100) return 'scandal';
    if (s.mental <= 0) return 'burnout';
    return null;
  }

  String seasonEndingKey() {
    final f = s.followers;
    if (f >= 1000000) return s.image >= 0 ? 'celeb_good' : 'celeb_bad';
    if (f >= 100000) return 'big';
    if (f >= 10000) return 'mid';
    if (f >= 1000) return 'small';
    return 'zero';
  }

  /// 게임을 끝낸다. 마지막 SNS 반응을 만들고 저장 데이터를 지운다.
  Trend finish(String key) {
    s.ended = key;
    _repo.addEnding(key);
    _repo.clear();
    final bad = key == 'scandal' || key == 'burnout';
    final t = sns.topicFeed(
      s,
      SnsTopic(
        tag: key == 'scandal' ? '{name}_자숙' : (key == 'burnout' ? '{name}_휴방' : '{name}_60일'),
        headline: key == 'scandal'
            ? '{name}, 잇단 논란에 결국 자숙 선언'
            : key == 'burnout'
                ? '{name}, 건강 문제로 무기한 휴방'
                : '{name}, 방송 60일 만에 구독자 ${shortNum(s.followers)}',
        tone: key == 'scandal' ? -0.5 : 0.5,
        hate: key == 'scandal' ? const ['자숙이 아니라 은퇴해라', '결국 이렇게 될 줄 알았다'] : const ['별로 대단한 것도 아닌데'],
        shield: const ['그동안 고생 많았어요', '{name} 꼭 다시 돌아와요', '덕분에 즐거웠다 진짜'],
        neutral: const ['한 시대가 끝났다', '다음 행보가 궁금하다'],
      ),
    );
    pushTrend(t);
    s.mode = bad ? 'away' : 'live';
    notifyListeners();
    return t;
  }

  @override
  void dispose() {
    _effects.close();
    super.dispose();
  }
}

/// 1.2만, 34만, 1.5억 같은 짧은 표기
String shortNum(int n) {
  final a = n.abs();
  final sign = n < 0 ? '-' : '';
  String trim(String v) => v.endsWith('.0') ? v.substring(0, v.length - 2) : v;
  if (a >= 100000000) return '$sign${trim((a / 1e8).toStringAsFixed(a >= 1e9 ? 0 : 1))}억';
  if (a >= 10000) return '$sign${trim((a / 1e4).toStringAsFixed(a >= 1e5 ? 0 : 1))}만';
  return '$sign${won(a).replaceAll('원', '')}';
}

String shortWon(int n) => '${shortNum(n)}원';

String imageText(int v) {
  if (v >= 40) return '호감';
  if (v >= 10) return '좋음';
  if (v > -10) return '보통';
  if (v > -40) return '나쁨';
  return '비호감';
}
