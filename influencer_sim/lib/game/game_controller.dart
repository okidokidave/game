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
  const StreamOutcome(this.result, this.trend, [this.offer]);
  final StreamResult result;
  final Trend? trend;

  /// 방송 뒤 DM으로 온 제안 (없으면 null)
  final DmOffer? offer;
}

class GaffeOutcome {
  const GaffeOutcome(this.result, this.changes, this.trend);

  /// 사고 영향을 반영한 방송 결과
  final StreamResult result;
  final List<Change> changes;
  final Trend trend;
}

/// 자숙 결과
class HiatusReport {
  const HiatusReport(this.days, this.lostFans, this.cost, this.seasonOver, this.changes, this.trend);
  final int days;
  final int lostFans;
  final int cost;

  /// 자숙 중에 60일이 다 지났는지
  final bool seasonOver;
  final List<Change> changes;
  final Trend? trend;
}

/// 알바 결과
class WorkOutcome {
  const WorkOutcome({required this.pay, this.gain = 0, this.caught = false, this.fired = false, this.strikes = 0, this.trend});
  final int pay;

  /// 브이로그로 늘어난 구독자
  final int gain;
  final bool caught;
  final bool fired;
  final int strikes;
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
    s.prevRanks = _ranks();
    s.lastRanks = s.prevRanks;
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

  /// 하루 생활비 (방세·식비): 사는 집에 따라 다르다
  int get rent => houseOf(s.house).rent;

  /// 자숙 기간 (일)
  static const hiatusDays = 21;

  /// 돈이 오갈 때는 모두 여기로: 통장 내역에 남긴다
  void money(int amount, String label) {
    if (amount == 0) return;
    s.money += amount;
    if (amount > 0) s.earned += amount;
    s.ledger = [LedgerEntry(s.day, label, amount), ...s.ledger].take(80).toList();
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
        final need = contents.where((c) => canStream(s, c)).map(energyCost).reduce(min);
        if (s.energy < need) return '체력 부족';
      case 'upload':
        if (g['pc']! < 1) return 'PC 필요';
        if (s.lastViewers == 0) return '방송 기록 없음';
        if (s.energy < 15) return '체력 부족';
      case 'work':
        if (s.day < s.firedUntil) return '잘림 (D${s.firedUntil}부터)';
        if (s.energy < 22) return '체력 부족';
    }
    return null;
  }

  /// 콘텐츠를 고를 수 없는 이유 (가능하면 null)
  String? contentBlock(Content c) {
    if (!canStream(s, c)) {
      return c.need.entries.where((e) => s.gear[e.key]! < e.value).map((e) => '${gearOf(e.key).label}: ${gearOf(e.key).tiers[e.value].name} 필요').join(', ');
    }
    if (s.energy < energyCost(c)) return '체력 ${energyCost(c)} 필요';
    if (c.cost > 0 && s.money < c.cost) return '돈 부족';
    return null;
  }

  // ───── 수치 적용 ─────
  List<Change> applyFx(Fx fx, [String moneyLabel = '사건']) {
    final changes = <Change>[];
    if (fx.followers != 0) {
      var d = (s.followers * fx.followers).round();
      if (fx.followers > 0) d = max(d, 3 + rng.nextInt(10));
      s.followers = max(0, s.followers + d);
      changes.add(_delta('구독자', d, shortNum));
    }
    if (fx.money != 0) {
      money(fx.money, moneyLabel);
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
    final changes = applyFx(choice.fx(s), ev.title);
    log('${ev.title}: ${choice.label}', 'event');
    Trend? trend;
    if (choice.sns != null) {
      trend = sns.topicFeed(s, choice.sns!);
      pushTrend(trend);
      if (choice.sns!.tone <= -0.3) _hateDms(1 + rng.nextInt(2));
    }
    checkMilestones();
    save();
    notifyListeners();
    return EventOutcome(choice, changes, trend);
  }

  // ───── 방송 ─────
  /// 방송 시작: 체력과 비용을 쓰고 결과를 미리 계산한다 (연출 중 시청자 수 표시용).
  StreamResult beginStream(Content c) {
    s.energy -= energyCost(c);
    money(-c.cost, '${c.name} 재료비');
    final r = calcStream(s, c, rng);
    s.mode = 'live';
    notifyListeners();
    return r;
  }

  /// 채팅 반응을 성공한 만큼 방송 결과를 키운다 (한 번에 시청자 +8%, 구독자 +10%, 후원 +15%)
  StreamResult boostStream(StreamResult r, int hits) {
    if (hits <= 0) return r;
    return StreamResult(
      viewers: (r.viewers * (1 + 0.08 * hits)).round(),
      gain: (r.gain * (1 + 0.10 * hits)).round(),
      donation: ((r.donation * (1 + 0.15 * hits)) / 100).round() * 100,
      ads: r.ads,
      viral: r.viral,
      flop: r.flop,
    );
  }

  /// 방송 중 사건이 생길 확률
  double liveEventChance(Content c) => 0.38 + (c.risky ? 0.15 : 0) - (c.calm ? 0.15 : 0);

  // ───── 인기 순위 ─────
  /// 라이벌 구독자 (처음이면 시작 값)
  int rivalFollowers(Rival r) => s.rivals[r.id] ?? r.start;

  /// 순위표: (id, 이름, 아이콘, 구독자) 를 구독자 순으로. 나는 id 'me'
  List<(String, String, String, int)> ranking() {
    final rows = [
      for (final r in rivals) (r.id, r.name, r.icon, rivalFollowers(r)),
      ('me', s.name, '⭐', s.followers),
    ]..sort((a, b) => b.$4.compareTo(a.$4));
    return rows;
  }

  int get myRank => ranking().indexWhere((r) => r.$1 == 'me') + 1;

  /// 하루가 지나면 라이벌도 성장한다. 내가 누군가를 제쳤으면 알림과 SNS 글
  Map<String, int> _ranks() => {for (final (i, row) in ranking().indexed) row.$1: i + 1};

  void _updateRanking() {
    // 어젯밤 순위와 비교한다 (처음이면 지금 순위)
    final before = s.lastRanks.isEmpty ? _ranks() : s.lastRanks;
    for (final r in rivals) {
      final f = rivalFollowers(r);
      final rate = r.growth * (0.3 + rng.nextDouble() * 1.4);
      s.rivals[r.id] = (f * (1 + rate)).round();
    }
    final after = ranking();
    final rankNow = after.indexWhere((r) => r.$1 == 'me') + 1;
    final rankBefore = before['me'] ?? rankNow;
    s.prevRanks = before;
    s.lastRanks = _ranks();
    if (rankNow < rankBefore) {
      // 바로 아래로 내려간 라이벌 = 방금 제친 사람
      final passed = after[rankNow];
      toasts.add('🏆 순위 상승! $rankBefore위 → $rankNow위');
      log('🏆 인기 순위 $rankNow위! ${passed.$2}을(를) 제쳤다.', 'milestone');
      pushFeed([sns.post(s, _pick(snsOvertake).replaceAll('{rival}', passed.$2), 'fan', g: sns.fanGender(s), boost: 2)]);
    }
  }

  // ───── SNS 대응 ─────
  /// 고소에 드는 변호사비
  int get lawyerFee => scaleMoney(s, 200000);

  /// 가장 최근 트렌드에, 이틀 안에, 한 번만 대응할 수 있다
  bool canRespond(Trend t) => s.ended == null && s.trends.isNotEmpty && identical(t, s.trends.last) && t.response == null && s.day - t.day <= 2;

  /// 트렌드에 내 계정으로 대응한다. 결과 한 줄 설명과 수치 변화를 돌려준다.
  (String, List<Change>) respond(Trend t, String kind) {
    if (!canRespond(t)) return ('', const []);
    final changes = <Change>[];
    String summary;
    switch (kind) {
      case 'explain':
        // 여론이 내 편일수록 해명이 잘 먹힌다
        final share = t.shield / max(1, t.shield + t.hate);
        final ok = share >= 0.5 || rng.nextDouble() < share + 0.2;
        final me = sns.myPost(s, _pick(myExplain));
        me.replies.addAll(sns.reactions(s, ok ? snsExplainOk : snsExplainBad, 4));
        t.posts.insert(1, me);
        pushFeed([me]);
        t.response = ok ? 'explain_ok' : 'explain_bad';
        changes.addAll(applyFx(ok ? const Fx(image: 3, heat: -6) : const Fx(image: -3, heat: 8)));
        summary = ok ? '해명이 먹혔다! 여론이 돌아서고 있다.' : '해명이 역풍을 맞았다… 오히려 불이 붙었다.';
        log(ok ? '✍️ 해명 글이 통했다.' : '✍️ 해명 글이 역풍을 맞았다.', 'event');
      case 'sue':
        money(-lawyerFee, '변호사 선임비');
        changes.add(_delta('돈', -lawyerFee, shortWon));
        final gone = (s.antis * 0.5).round();
        s.antis -= gone;
        if (gone > 0) changes.add(_delta('안티', -gone, shortNum, true));
        changes.addAll(applyFx(const Fx(heat: -10, image: -1)));
        final me = sns.myPost(s, _pick(mySue));
        me.replies.addAll(sns.reactions(s, snsSue, 4));
        t.posts.insert(1, me);
        pushFeed([me]);
        t.response = 'sue';
        summary = '고소 공지를 올렸다. 악플이 눈에 띄게 줄었지만, 과하다는 말도 나온다.';
        log('⚖️ 악플러 고소를 진행했다.', 'event');
      case 'pin':
        // 가장 좋아요가 많은 쉴드 글을 고정하고 답글을 단다
        final fans = t.posts.where((p) => p.side == 'shield' || p.side == 'fan').toList()..sort((a, b) => b.likes.compareTo(a.likes));
        // 쉴드 글이 하나도 없으면 응원 글을 하나 불러온다
        if (fans.isEmpty) fans.addAll(sns.reactions(s, const SnsTopic(tag: '', headline: '', tone: 1, shield: ['{name} 항상 응원해요', '우리는 {name} 편이에요']), 1));
        if (fans.isNotEmpty) {
          final top = fans.first;
          t.posts.remove(top);
          t.posts.insert(1, top);
          top.text = '📌 ${top.text}';
          top.replies.insert(0, sns.myPost(s, _pick(myPin)));
        }
        // 고정 글을 보고 팬들이 모여든다
        t.posts.addAll(sns.reactions(s, const SnsTopic(tag: '', headline: '', tone: 0.8, shield: ['고정 댓글 보고 울컥함', '{name} 팬들 화력 보여주자', '우리가 지킨다']), 2));
        changes.addAll(applyFx(const Fx(mental: 8, image: 1)));
        t.response = 'pin';
        summary = '팬 댓글을 고정했다. 팬들이 힘을 모으기 시작했다.';
        log('📌 응원 댓글을 고정했다.', 'event');
      default:
        t.response = 'ignore';
        summary = '아무 대응도 하지 않았다. 시간이 지나면 잊히겠지…';
    }
    t.recount();
    save();
    notifyListeners();
    return (summary, changes);
  }

  // ───── 방송 중 말실수 ─────
  double gaffeChance(Content c) => 0.07 + (c.risky ? 0.04 : 0) - (c.calm ? 0.03 : 0);

  /// 드물게 말실수가 일어난다 (없으면 null)
  Gaffe? rollGaffe(Content c) => rng.nextDouble() < gaffeChance(c) ? _pick(gaffes) : null;

  /// 말실수 대처. 사과하면 피해가 적고, 강행하면 팬이 떠나고 안티가 생긴다.
  GaffeOutcome resolveGaffe(Gaffe g, StreamResult r, {required bool apologize}) {
    final changes = <Change>[];
    StreamResult scaled(double v, double gain, double money) => StreamResult(
          viewers: max(1, (r.viewers * v).round()),
          gain: (r.gain * gain).round(),
          donation: (r.donation * money / 100).round() * 100,
          ads: (r.ads * v / 100).round() * 100,
          viral: false,
          flop: r.flop,
        );
    final StreamResult result;
    final SnsTopic base;
    if (apologize) {
      // 방송을 바로 접고 사과한다: 이 방송의 수입과 새 팬은 없다. (이후 3주 자숙 → startHiatus)
      changes.addAll(applyFx(const Fx(image: -2, heat: 4, mental: -6)));
      result = StreamResult(viewers: max(1, (r.viewers * 0.85).round()), gain: 0, donation: 0, ads: 0, viral: false, flop: r.flop);
      base = snsGaffeApology;
      log('🙇 말실수 후 방송을 중단하고 사과했다. 3주간 자숙에 들어간다.', 'event');
    } else {
      final lost = max(1, (s.followers * 0.06).round());
      s.followers = max(0, s.followers - lost);
      final newAntis = max(5, (s.followers * 0.03 + r.viewers * 0.2).round());
      s.antis += newAntis;
      changes
        ..add(_delta('팬 이탈', -lost, shortNum))
        ..add(_delta('안티', newAntis, shortNum, true));
      changes.addAll(applyFx(const Fx(image: -8, heat: 16)));
      result = scaled(0.55, 0.25, 0.6);
      base = snsGaffeIgnore;
      log('😶 말실수를 하고도 사과 없이 방송을 이어갔다. 팬 ${shortNum(lost)}명이 떠났다.', 'event');
    }
    // 박제된 말을 기사 제목에 붙인다
    final topic = SnsTopic(
      tag: base.tag,
      headline: '${base.headline} ${g.quote}',
      tone: base.tone,
      hate: base.hate,
      shield: base.shield,
      neutral: base.neutral,
    );
    final trend = sns.topicFeed(s, topic);
    pushTrend(trend);
    // 사과 없이 넘어가면 욕 DM이 더 많이 온다
    _hateDms(apologize ? 2 : 4);
    if (apologize) _dm(_pick(dmComfort), 'fan');
    save();
    notifyListeners();
    return GaffeOutcome(result, changes, trend);
  }

  /// 사과 후 3주 자숙. 방송·수입은 없고 생활비는 나간다. 팬은 서서히 조금 떠나고 논란은 가라앉는다.
  HiatusReport startHiatus() {
    final fans0 = s.followers, heat0 = s.heat, mental0 = s.mental, image0 = s.image;
    var days = 0;
    while (days < hiatusDays && s.day <= seasonDays) {
      days++;
      s.followers = (s.followers * 0.9988).floor(); // 3주에 약 2.5%
      s.heat = (s.heat - 7).clamp(0, 100);
      s.antis = (s.antis * 0.97).floor();
      s.mental = (s.mental + 3).clamp(0, 100);
      _updateRanking();
      s.day++;
    }
    // 자숙 중 순위 알림은 쌓지 않는다
    toasts.removeWhere((m) => m.startsWith('🏆 순위'));
    // 자숙 중에도 생활비와 직원 일당은 나간다
    final wages = staffList.where((x) => hasStaff(x.id)).fold(0, (a, x) => a + x.wage);
    final cost = days * (rent + wages);
    money(-days * rent, '자숙 기간 생활비 ($days일)');
    if (wages > 0) money(-days * wages, '자숙 기간 직원 일당 ($days일)');
    s.image = (s.image + 4).clamp(-100, 100);
    s.energy = 100;
    s.slot = 0;
    s.mode = 'idle';
    final over = s.day > seasonDays;

    final changes = <Change>[
      _delta('팬 이탈', s.followers - fans0, shortNum),
      _delta(wages > 0 ? '생활비·일당' : '생활비', -cost, shortWon),
      _delta('논란', s.heat - heat0, null, true),
      _delta('멘탈', s.mental - mental0),
      _delta('이미지', s.image - image0),
    ].where((c) => c.good != null).toList();

    Trend? trend;
    if (!over) {
      s.trend = _pick(contents.where((c) => c.id != s.trend).toList()).id;
      log('🎬 $days일간의 자숙을 마치고 복귀했다.', 'day');
      trend = sns.topicFeed(s, snsComeback);
      pushTrend(trend);
    }
    save();
    notifyListeners();
    return HiatusReport(days, fans0 - s.followers, cost, over, changes, trend);
  }

  // 콘텐츠마다 새로 들어오는 팬의 성비가 조금씩 다르다
  static const _contentLean = {'game': 0.12, 'react': 0.05, 'sing': -0.08, 'asmr': -0.06, 'vlog': -0.08};

  void _shiftFans(Content c, int gain) {
    if (gain <= 0) return;
    final base = s.look.male ? 0.35 : 0.72;
    final target = (base + (_contentLean[c.id] ?? 0)).clamp(0.1, 0.9);
    s.maleFans = ((s.maleFans * s.followers + target * gain) / (s.followers + gain)).clamp(0.05, 0.95);
  }

  StreamOutcome finishStream(Content c, StreamResult r) {
    _shiftFans(c, r.gain);
    s.followers += r.gain;
    final income = r.donation + r.ads;
    money(r.donation, '${c.name} 후원');
    money(r.ads, '${c.name} 광고 수익');
    s.streams++;
    s.peak = max(s.peak, r.viewers);
    s.skills[c.id] = (s.skills[c.id] ?? 0) + 1;
    s.lastContent = c.id;
    s.lastViewers = r.viewers;
    s.mental = (s.mental - 2).clamp(0, 100);
    if (c.id == 'study') s.image = (s.image + 1).clamp(-100, 100);
    s.mode = 'idle';

    pushFeed(sns.streamPosts(s, c, viral: r.viral, flop: r.flop));
    final offer = _streamDms(c, r);
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
    return StreamOutcome(r, trend, offer);
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
    money(r.ads, '영상 광고 수익');
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

  Workplace get job => workplaces[s.workplace % workplaces.length];

  /// 알바. [vlog]면 일하면서 브이로그를 찍는다: 구독자는 늘지만 점장 눈치가 쌓이고 3번 걸리면 잘린다.
  WorkOutcome work({bool vlog = false}) {
    final place = job;
    s.mode = 'away';
    s.energy -= 22;
    s.mental = (s.mental - 3).clamp(0, 100);
    final pay = s.slot == 2 ? (place.pay * 1.2).round() : place.pay;
    money(pay, '${place.name} 알바');
    if (!vlog) {
      log('${place.icon} ${place.name} 알바를 했다. ${_pick(place.texts)} +${shortWon(pay)}');
      save();
      notifyListeners();
      return WorkOutcome(pay: pay);
    }

    // 브이로그: 알바 일상이 소소하게 인기를 끈다
    final gain = max(2, ((6 + s.followers * 0.015) * sqrt(quality(s, null)) * (0.7 + rng.nextDouble() * 0.8)).round());
    s.followers += gain;
    pushFeed([for (var i = 0; i < 2; i++) sns.post(s, _pick(snsWorkVlog), 'fan', g: sns.fanGender(s))]);
    var caught = false, fired = false;
    Trend? trend;
    if (rng.nextDouble() < 0.25 + 0.2 * s.workStrikes) {
      caught = true;
      s.workStrikes++;
      if (s.workStrikes >= 3) {
        fired = true;
        s.workStrikes = 0;
        s.firedUntil = s.day + 7;
        s.workplace = (s.workplace + 1) % workplaces.length;
        final bump = max(5, (s.followers * 0.04).round()); // 해고 클립이 화제가 된다
        s.followers += bump;
        trend = sns.topicFeed(s, snsFired);
        pushTrend(trend);
        log('🚫 ${place.name}에서 잘렸다! 해고 클립이 화제가 됐다. 일주일 뒤에 새 알바를 구할 수 있다.', 'event');
      } else {
        log('🎥 ${place.name} 알바 브이로그를 찍다가 점장님께 걸렸다. (경고 ${s.workStrikes}/3)', 'event');
      }
    } else {
      log('🎥 ${place.name} 알바 브이로그를 찍었다. 구독자 +${shortNum(gain)}');
    }
    checkMilestones();
    save();
    notifyListeners();
    return WorkOutcome(pay: pay, gain: gain, caught: caught, fired: fired, strikes: s.workStrikes, trend: trend);
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
    money(-rent, '생활비 (${houseOf(s.house).name})');
    _staffNight();
    final broke = s.money < 0;
    s.energy = (s.energy + 45 + remaining * 15).clamp(0, 100);
    s.mental = (s.mental + 5).clamp(0, 100);
    s.heat = (s.heat - 7).clamp(0, 100);
    s.antis = (s.antis * 0.97).floor();
    _updateRanking();
    s.day++;
    _expireOffers();
    s.slot = 0;
    s.mode = 'idle';
    if (s.day > seasonDays) return const DayReport(seasonOver: true);

    final notes = <String>[];
    if (broke) {
      s.mental = (s.mental - 3).clamp(0, 100);
      notes.add('통장이 마이너스다… 멘탈 -3');
    }
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
    if (s.firedUntil > 0 && s.day == s.firedUntil) notes.add('${job.icon} 새 알바를 구했다: ${job.name}');
    for (final n in notes) {
      log(n, 'note');
    }
    final over = overKey() != null;
    // 폭로될 일이 있거나 유명해질수록 아침 소식이 자주 온다
    final newsChance = s.flags.contains('hiddenAd') || s.flags.contains('lieDating') ? 0.2 : (s.followers >= 30000 ? 0.12 : 0.06);
    // 순위표 상위권이면 순위 이벤트(CF·뉴스·공중파·1위)가 먼저 찾아온다
    final news = over ? null : (rollEvent('rank', 0.45) ?? rollEvent('news', newsChance));
    save();
    notifyListeners();
    return DayReport(news: news);
  }

  // ───── DM ─────
  int get dmUnread => s.dms.where((d) => !d.read).length;

  void _dm(String text, String kind, {String? nick, int? color, String? offer}) {
    final u = sns.user();
    s.dms.insert(
      0,
      Dm(id: '${s.day}-${s.slot}-${rng.nextInt(1 << 30)}', nick: nick ?? u.nick, color: color ?? u.color, text: Sns.fill(text, s), day: s.day, kind: kind, offer: offer),
    );
    if (s.dms.length > 40) s.dms.removeRange(40, s.dms.length);
  }

  void _hateDms(int n) {
    final pool = [...dmHate]..shuffle(rng);
    for (final t in pool.take(n)) {
      _dm(t, 'hate');
    }
    toasts.add('📩 DM이 $n통 왔어요… 열어 보기 무섭다');
  }

  /// 방송이 끝나면 응원 DM이나 제안 DM이 온다. 새 제안이 있으면 돌려준다
  DmOffer? _streamDms(Content c, StreamResult r) {
    if (s.heat < 40 && (r.viral || (!r.flop && rng.nextDouble() < 0.25))) _dm(_pick(dmFan), 'fan');
    for (final o in dmOffers) {
      if (o.after != null && o.after != c.id) continue;
      if (s.followers < o.minFollowers) continue;
      if (s.dms.any((d) => d.offer == o.id && d.status == 'open')) continue;
      if (rng.nextDouble() >= o.chance) continue;
      _dm(o.text(s), 'offer', nick: o.from, color: o.color, offer: o.id);
      log('📩 ${o.from}에게서 DM이 왔다.', 'event');
      return o;
    }
    return null;
  }

  /// 답장 안 한 제안은 4일 뒤 사라진다
  void _expireOffers() {
    for (final d in s.dms) {
      if (d.kind == 'offer' && d.status == 'open' && s.day - d.day >= 4) {
        d.status = 'expired';
        d.note = '답장이 없어 제안이 다른 사람에게 넘어갔다.';
      }
    }
  }

  /// DM함을 열면 모두 읽음. 안 읽은 욕 DM은 멘탈을 깎고 (최대 -8), 응원 DM은 조금 채운다 (최대 +4)
  int readDms() {
    final unread = s.dms.where((d) => !d.read).toList();
    if (unread.isEmpty) return 0;
    final hate = unread.where((d) => d.kind == 'hate').length;
    final fan = unread.where((d) => d.kind == 'fan').length;
    final int delta = -min(hate * 2, 8) + min(fan, 4);
    for (final d in unread) {
      d.read = true;
    }
    s.mental = (s.mental + delta).clamp(0, 100);
    save();
    notifyListeners();
    return delta;
  }

  /// 제안 DM에 답장한다. (결과 글, 변화, SNS 트렌드)
  (String, List<Change>, Trend?) answerOffer(Dm d, {required bool accept}) {
    final o = dmOfferOf(d.offer!);
    if (d.status != 'open') return (d.note ?? '', const <Change>[], null);
    if (!accept) {
      d.status = 'declined';
      d.note = Sns.fill(o.declined, s);
      save();
      notifyListeners();
      return (d.note!, const <Change>[], null);
    }
    d.status = 'accepted';
    d.note = Sns.fill(o.result, s);
    final changes = applyFx(o.fx(s), o.from);
    log('📩 ${o.from}의 제안을 수락했다.', 'event');
    Trend? trend;
    if (o.sns != null) {
      trend = sns.topicFeed(s, o.sns!);
      pushTrend(trend);
    }
    checkMilestones();
    save();
    notifyListeners();
    return (d.note!, changes, trend);
  }

  // ───── 상점 ─────
  bool buyGear(String key) {
    final g = gearOf(key);
    final lv = s.gear[key]!;
    if (lv + 1 >= g.tiers.length) return false;
    final next = g.tiers[lv + 1];
    if (s.money < next.price) return false;
    money(-next.price, next.name);
    s.gear[key] = lv + 1;
    log('🛒 ${next.name} 구입! (-${shortWon(next.price)})', 'buy');
    pushFeed([sns.post(s, _pick(['{name} 장비 바꿨나? ${g.label} 확 좋아짐', '{name} 새 ${g.label} 플렉스 ㅋㅋ', '{name} 방송 퀄 점점 올라가네']), 'fan', g: sns.fanGender(s))]);
    toasts.add('${next.name} 설치 완료!');
    emit('coin', 8);
    save();
    notifyListeners();
    return true;
  }

  bool buyDeco(Deco d) {
    if (s.deco.contains(d.id) || s.money < d.price) return false;
    money(-d.price, d.name);
    s.deco.add(d.id);
    log('🛒 ${d.name} 구입! (-${shortWon(d.price)})', 'buy');
    toasts.add('${d.name}을(를) 방에 놓았어요');
    save();
    notifyListeners();
    return true;
  }

  // ───── 직원 ─────
  bool hasStaff(String id) => s.staff.contains(id);

  /// 방송에 드는 체력 (매니저가 있으면 20% 덜 든다)
  int energyCost(Content c) => hasStaff('manager') ? (c.energy * 0.8).round() : c.energy;

  String? hireBlock(Staff st) {
    if (hasStaff(st.id)) return '고용 중';
    if (s.followers < st.minFollowers) return '구독자 ${shortNum(st.minFollowers)} 필요';
    if (s.money < st.wage * 3) return '돈 부족';
    return null;
  }

  bool hire(Staff st) {
    if (hireBlock(st) != null) return false;
    s.staff.add(st.id);
    log('${st.icon} ${st.name}를 고용했다! (일당 ${shortWon(st.wage)})', 'buy');
    toasts.add('${st.icon} ${st.name} 고용 완료!');
    pushFeed([sns.post(s, _pick(['{name} ${st.name} 뽑았대 ㄷㄷ 이제 기업이네', '{name} 팀 생겼다 축하해요', '{name} ${st.name}님 일 잘하시네']), 'fan', g: sns.fanGender(s))]);
    save();
    notifyListeners();
    return true;
  }

  void dismiss(Staff st) {
    if (!s.staff.remove(st.id)) return;
    log('${st.icon} ${st.name}와 계약을 끝냈다.');
    save();
    notifyListeners();
  }

  /// 밤마다 직원이 하는 일과 일당
  void _staffNight() {
    for (final st in staffList.where((x) => hasStaff(x.id))) {
      money(-st.wage, '${st.name} 일당');
    }
    if (hasStaff('editor')) {
      final u = calcUpload(s, rng);
      final gain = (u.gain * 0.6).round();
      s.followers += gain;
      money((u.ads * 0.6 / 100).round() * 100, '편집자 영상 광고 수익');
      log('✂️ 편집자가 하이라이트 영상을 올렸다. 조회수 ${shortNum((u.views * 0.6).round())} · 구독자 +${shortNum(gain)}');
    }
    if (hasStaff('manager')) {
      s.heat = (s.heat - 3).clamp(0, 100);
      s.mental = (s.mental + 2).clamp(0, 100);
      if (rng.nextDouble() < 0.12) {
        final deal = scaleMoney(s, 100000);
        money(deal, '매니저가 따 온 광고');
        log('🧑‍💼 매니저가 광고 건을 따 왔다! +${shortWon(deal)}', 'event');
      }
    }
  }

  /// 이사할 수 없으면 이유, 할 수 있으면 null
  String? moveBlock(House h) {
    final cur = houses.indexWhere((x) => x.id == s.house);
    final idx = houses.indexOf(h);
    if (idx <= cur) return '이미 지나온 집';
    if (idx > cur + 1) return '${houses[idx - 1].name}부터';
    if (s.followers < h.minFollowers) return '구독자 ${shortNum(h.minFollowers)} 필요';
    if (s.money < h.deposit) return '돈 부족';
    return null;
  }

  bool moveHouse(House h) {
    if (moveBlock(h) != null) return false;
    money(-h.deposit, '${h.name} 보증금·이사비');
    s.house = h.id;
    s.wallColor = h.wall;
    log('${h.icon} ${h.name}(으)로 이사했다!', 'milestone');
    pushFeed([for (var i = 0; i < 3; i++) sns.post(s, _pick(snsMoving), 'fan', g: sns.fanGender(s), boost: 2)]);
    toasts.add('${h.icon} ${h.name}(으)로 이사 완료!');
    emit('heart', 16);
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
