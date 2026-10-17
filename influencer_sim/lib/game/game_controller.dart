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
/// 클래스 안에서는 log가 기록 메서드라서 밖에 둔다
double _log10(num x) => log(x) / ln10;

class Change {
  const Change(this.label, this.text, this.good);
  final String label;
  final String text;

  /// true 좋음(초록) / false 나쁨(빨강) / null 변화 없음
  final bool? good;
}

class EventOutcome {
  const EventOutcome(this.choice, this.changes, this.trend, [this.won]);

  /// 실제로 일어난 선택지 (운에 달린 선택지에서 실패하면 그 실패 결과)
  final EventChoice choice;

  /// 운에 달린 선택지였으면 성공 여부, 아니면 null
  final bool? won;
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
  const HiatusReport(this.days, this.lostFans, this.cost, this.changes, this.trend);
  final int days;
  final int lostFans;
  final int cost;

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

/// 부모님 가게 홍보 결과
class PromoOutcome {
  const PromoOutcome(this.changes, this.trend, this.backlash);
  final List<Change> changes;
  final Trend? trend;

  /// "가족 장사" 논란이 났는지
  final bool backlash;
}

class UploadOutcome {
  const UploadOutcome(this.result, this.trend);
  final UploadResult result;
  final Trend? trend;
}

/// 하루가 끝났을 때 결과
class DayReport {
  const DayReport({this.news, this.goal});

  /// 새로 달성한 목표 엔딩 (계속하거나 은퇴할 수 있다)
  final String? goal;

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
    if (_state == null) return;
    checkAchievements();
    checkUnlocks();
    if (_state!.ended == null) _repo.save(_state!);
  }

  // ───── 업적 (판이 바뀌어도 남는다) ─────
  Set<String>? _achieved;
  Set<String> get achieved => _achieved ??= _repo.achievements().toSet();

  void checkAchievements() {
    for (final a in achievements) {
      if (achieved.contains(a.id) || !a.check(s)) continue;
      achieved.add(a.id);
      _repo.addAchievement(a.id);
      toasts.add('🏅 업적 달성: ${a.title}');
    }
  }

  /// 지금 열린 다회차 혜택
  List<Perk> get unlockedPerks => perks.where((p) => p.unlocked(endingsSeen.length, achieved.length)).toList();

  void newGame(String name, Look look, {int wallColor = 0xE9DCCB}) {
    _state = GameState(name: name, look: look, wallColor: wallColor, trend: _pick(['talk', 'mukbang', 'sing']));
    log('📱 스마트폰 하나로 방송을 시작했다. 목표: 스트리머 인기 순위 1위!', 'day');
    _applyPerks();
    _newMissions();
    s.prevRanks = _ranks();
    s.lastRanks = s.prevRanks;
    save();
    notifyListeners();
  }

  /// 다회차 혜택을 새 게임에 적용한다
  void _applyPerks() {
    final e = endingsSeen.length, a = achieved.length;
    if (e >= 1) s.money += 50000;
    if (a >= 5) s.image = 10;
    if (e >= 3) s.gear['camera'] = max(s.gear['camera']!, 1);
    if (a >= 10) {
      s.followers += 50;
      s.coreFans += 20;
    }
    if (e >= 5) s.gear['mic'] = max(s.gear['mic']!, 1);
    if (a >= 15) {
      s.house = 'oneroom';
      s.wallColor = houseOf('oneroom').wall;
    }
    final n = unlockedPerks.length;
    if (n > 0) log('🎁 다회차 혜택 $n개가 적용됐다.', 'note');
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

  /// 화면에 알림 한 줄
  void toast(String msg) {
    toasts.add(msg);
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
        if (isPro) {
          if (!s.flags.contains('parentShop')) return '전업 방송인';
          if (s.energy < 20) return '체력 부족';
          return null;
        }
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
      // 찐팬이 많으면 논란이 덜 커진다
      final h = fx.heat > 0 ? max(1, (fx.heat * (1 - shieldPower)).round()) : fx.heat;
      s.heat = (s.heat + h).clamp(0, 100);
      changes.add(_delta('논란', h, null, true));
    }
    if (fx.mental != 0) {
      s.mental = (s.mental + fx.mental).clamp(0, 100);
      changes.add(_delta('멘탈', fx.mental));
    }
    if (fx.energy != 0) {
      s.energy = (s.energy + fx.energy).clamp(0, 100);
      changes.add(_delta('체력', fx.energy));
    }
    if (fx.quit != null && s.staff.remove(fx.quit)) {
      final st = staffOf(fx.quit!);
      changes.add(Change(st.name, '퇴사', false));
      log('${st.icon} ${st.name}가 일을 그만뒀다.', 'event');
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
  /// 사건은 하루에 하나만 일어난다
  GameEvent? rollEvent(String where, double chance) {
    if (s.lastEventDay == s.day) return null;
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
    var choice = ev.choices[index];
    // 운에 달린 선택지 (승소·패소 등)
    bool? won;
    if (choice.chance != null) {
      won = rng.nextDouble() < choice.chance!(s);
      if (!won) choice = choice.lose!;
    }
    s.lastEventDay = s.day;
    s.flags.add('${ev.id}#$index');
    if (won == true) s.flags.add('${ev.id}Won');
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
    return EventOutcome(choice, changes, trend, won);
  }

  // ───── 방송 ─────
  /// 방송 시작: 체력과 비용을 쓰고 결과를 미리 계산한다 (연출 중 시청자 수 표시용).
  StreamResult beginStream(Content c) {
    s.energy -= energyCost(c);
    money(-c.cost, '${c.name} 재료비');
    var r = calcStream(s, c, rng);
    // 예고한 방송을 지키면 기다리던 시청자가 몰려온다
    scheduleHit = isScheduled(c);
    if (scheduleHit) {
      r = StreamResult(viewers: (r.viewers * 1.25).round(), gain: (r.gain * 1.2).round(), donation: r.donation, ads: r.ads, viral: r.viral, flop: false);
    }
    s.mode = 'live';
    notifyListeners();
    return r;
  }

  /// 채팅 반응을 성공한 만큼 방송 결과를 키운다 (한 번에 시청자 +8%, 구독자 +10%, 후원 +15%)
  /// 시청자 질문에 잘 대답한 분위기([hype])도 같은 만큼 결과를 키운다
  StreamResult boostStream(StreamResult r, int hits, {int hype = 0}) {
    if (hits > 0) progress('react', hits);
    hits += hype;
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
  double liveEventChance(Content c) => 0.2 + (c.risky ? 0.1 : 0) - (c.calm ? 0.1 : 0);

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
  /// 말실수 확률. 한 번 사고가 나면 열흘은 조심하게 된다
  double gaffeChance(Content c) {
    if (s.day - s.lastGaffe < 10 || s.lastEventDay == s.day) return 0;
    return 0.03 + (c.risky ? 0.02 : 0) - (c.calm ? 0.015 : 0);
  }

  /// 드물게 말실수가 일어난다 (없으면 null)
  Gaffe? rollGaffe(Content c) => rng.nextDouble() < gaffeChance(c) ? _pick(gaffes) : null;

  /// 말실수 대처. 사과하면 피해가 적고, 강행하면 팬이 떠나고 안티가 생긴다.
  GaffeOutcome resolveGaffe(Gaffe g, StreamResult r, {required bool apologize}) {
    s.lastGaffe = s.day;
    s.lastEventDay = s.day;
    final changes = <Change>[];
    // 사과 없이 넘어가면 찐팬도 실망한다
    addCore(-(s.coreFans * (apologize ? 0.03 : 0.12)).round());
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
    s.flags.add('hiatus');
    s.schedDay = 0;
    final fans0 = s.followers, heat0 = s.heat, mental0 = s.mental, image0 = s.image;
    var days = 0;
    while (days < hiatusDays) {
      days++;
      s.followers = (s.followers * 0.9988).floor(); // 3주에 약 2.5%
      s.heat = (s.heat - 7).clamp(0, 100);
      s.antis = (s.antis * 0.97).floor();
      s.mental = (s.mental + 3).clamp(0, 100);
      _updateRanking();
      s.history.add(DayStat(s.day, s.followers, s.money, 0, s.coreFans));
      s.day++;
    }
    // 자숙 중에도 사업은 돌아간다
    for (final b in ownedBusinesses) {
      money(businessIncome(b) * days, '${b.name} 수익 ($days일)');
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
    final changes = <Change>[
      _delta('팬 이탈', s.followers - fans0, shortNum),
      _delta(wages > 0 ? '생활비·일당' : '생활비', -cost, shortWon),
      _delta('논란', s.heat - heat0, null, true),
      _delta('멘탈', s.mental - mental0),
      _delta('이미지', s.image - image0),
    ].where((c) => c.good != null).toList();

    s.trend = _pick(contents.where((c) => c.id != s.trend).toList()).id;
    log('🎬 $days일간의 자숙을 마치고 복귀했다.', 'day');
    final trend = sns.topicFeed(s, snsComeback);
    pushTrend(trend);
    s.lastEventDay = s.day;
    save();
    notifyListeners();
    return HiatusReport(days, fans0 - s.followers, cost, changes, trend);
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
    if (s.flags.contains('mcn')) money(-((income * 0.3) / 100).round() * 100, 'MCN 수수료 30%');
    if (r.viral) s.flags.add('viral');
    // 꾸준히 보러 오는 사람 일부가 찐팬이 된다
    addCore((r.gain * 0.06).round() + (r.viral ? 0 : 1));
    s.todayPeak = max(s.todayPeak, r.viewers);
    s.best = ([...s.best, BestStream(s.day, c.id, r.viewers)]..sort((a, b) => b.viewers.compareTo(a.viewers))).take(3).toList();
    if (scheduleHit) {
      scheduleHit = false;
      s.schedKept++;
      s.schedDay = 0;
      addCore(max(3, (r.viewers * 0.05).round()));
      toasts.add('📅 예고한 방송을 지켰다! 찐팬이 늘었어요');
      log('📅 예고한 대로 ${c.name}을(를) 켰다. 기다리던 시청자들이 몰려왔다.', 'event');
    }
    progress('stream', 1);
    if (s.slot == 2) progress('night', 1);
    progress('gain', r.gain);
    progress('donation', r.donation);
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
    progress('upload', 1);
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

  /// 전업 방송인 (구독자 1만 명부터). 알바는 그만두고, 부모님 가게가 생기면 가게 홍보를 한다
  bool get isPro => s.followers >= proFollowers;

  /// 부모님 가게 홍보. [onAir]면 방송에서 대놓고 홍보하고(효과가 크지만 '가족 장사' 논란 위험),
  /// 아니면 가게 일을 도우며 브이로그를 찍는다.
  PromoOutcome promote({required bool onAir}) {
    s.mode = 'away';
    s.energy -= onAir ? 12 : 20;
    Trend? trend;
    var backlash = false;
    final changes = <Change>[];
    if (onAir) {
      backlash = rng.nextDouble() < 0.3 + s.heat / 200;
      if (backlash) {
        changes.addAll(applyFx(const Fx(heat: 10, image: -5)));
        trend = sns.topicFeed(
          s,
          const SnsTopic(
            tag: '{name}_가족장사',
            headline: '{name}, 방송 중 부모님 가게 홍보… "가족 장사" 논란',
            tone: -0.3,
            hate: ['방송을 광고판으로 쓰네', '팬들한테 치킨 강매?', '선 넘었다'],
            shield: ['부모님 가게 좀 도울 수도 있지', '효도하는 게 뭐가 문제', '맛있으면 됐지'],
            neutral: ['그래서 치킨 맛은?'],
          ),
        );
        pushTrend(trend);
        log('🍗 방송에서 부모님 가게를 홍보했다가 "가족 장사" 소리를 들었다.', 'flop');
      } else {
        final gift = scaleMoney(s, 60000);
        changes
          ..addAll(applyFx(Fx(money: gift, image: 3), '부모님 용돈'))
          ..add(Change('찐팬', '+${shortNum(3 + s.followers ~/ 3000)}', true));
        addCore(3 + s.followers ~/ 3000);
        trend = sns.topicFeed(s, snsParentShop);
        pushTrend(trend);
        log('🍗 방송에서 부모님 가게를 소개했다. 주문이 밀려들었다!', 'event');
      }
    } else {
      final gain = max(3, (s.followers * 0.004 * (0.7 + rng.nextDouble() * 0.6)).round());
      s.followers += gain;
      changes
        ..add(Change('구독자', '+${shortNum(gain)}', true))
        ..addAll(applyFx(Fx(money: scaleMoney(s, 20000), image: 2, mental: 4), '부모님 용돈'));
      addCore(2 + s.followers ~/ 5000);
      pushFeed([
        for (var i = 0; i < 2; i++)
          sns.post(s, _pick(['{name} 치킨 튀기는 브이로그 ㅋㅋ 생활력 만렙', '부모님 가게 돕는 {name} 효도 클라스', '{name} 앞치마 잘 어울린다', '이 가게 어디예요? 가 보고 싶다']), 'fan', g: sns.fanGender(s)),
      ]);
      log('🍗 부모님 가게 일을 도우며 브이로그를 찍었다. 구독자 +${shortNum(gain)}');
    }
    checkMilestones();
    save();
    notifyListeners();
    return PromoOutcome(changes, trend, backlash);
  }

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
        s.flags.add('fired');
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
    progress('rest', 1);
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
    for (final b in ownedBusinesses) {
      money(businessIncome(b), '${b.icon} ${b.name} 수익');
    }
    _scheduleNight();
    s.history.add(DayStat(s.day, s.followers, s.money, s.todayPeak, s.coreFans));
    if (s.history.length > 90) s.history.removeAt(0);
    s.todayPeak = 0;
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
    _newMissions();
    if (s.firedUntil > 0 && s.day == s.firedUntil) notes.add('${job.icon} 새 알바를 구했다: ${job.name}');
    for (final n in notes) {
      log(n, 'note');
    }
    final over = overKey() != null;
    // 목표를 달성했으면 그날 아침은 축하만 한다
    final goal = over ? null : _goalEnding();
    // 폭로될 일이 있거나 유명해질수록 아침 소식이 자주 온다
    final newsChance = s.flags.contains('hiddenAd') || s.flags.contains('lieDating') ? 0.2 : (s.followers >= 30000 ? 0.08 : 0.04);
    // 순위표 상위권이면 순위 이벤트(CF·뉴스·공중파·1위)가 먼저 찾아온다
    final news = over || goal != null ? null : (rollEvent('rank', 0.3) ?? rollEvent('crisis', crisisChance) ?? rollEvent('news', newsChance));
    save();
    notifyListeners();
    return DayReport(news: news, goal: goal);
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
    s.flags.add('offer_${o.id}');
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

  /// 위기가 찾아올 확률: 구독자 5천부터, 10배 늘 때마다 +4%p (최대 15%)
  double get crisisChance => s.followers < 5000 ? 0 : min(0.08, 0.025 + 0.02 * _log10(s.followers / 5000));

  // ───── 단계별로 열리는 기능 ─────
  static const featureNames = {
    'fans': '💖 팬 성비·찐팬',
    'ranking': '🏆 스트리머 인기 순위',
    'missions': '🎯 오늘의 미션',
    'schedule': '📅 방송 예고',
    'stats': '📊 방송 기록',
    'staff': '🧑‍💼 직원 고용 (상점)',
    'business': '🛍️ 사업 (상점)',
  };

  bool unlocked(String f) => switch (f) {
        'fans' => s.followers >= 30 || s.streams >= 3,
        'ranking' => s.followers >= 50,
        'missions' => s.day >= 2,
        'schedule' => s.followers >= 100,
        'stats' => s.day >= 3,
        'staff' => s.followers >= 3000,
        'business' => s.followers >= 8000,
        _ => true,
      };

  /// 새로 열린 기능을 알린다. 열어 볼 때까지 'new_' 표시가 남는다
  void checkUnlocks() {
    for (final f in featureNames.keys) {
      if (!unlocked(f) || s.flags.contains('unlock_$f')) continue;
      s.flags
        ..add('unlock_$f')
        ..add('new_$f');
      toasts.add('🔓 새 기능: ${featureNames[f]}');
    }
  }

  bool isNew(String f) => s.flags.contains('new_$f');

  void seen(String f) {
    if (s.flags.remove('new_$f')) notifyListeners();
  }

  // ───── 광고주 후원 (보상형 광고) ─────
  /// 오늘 광고주 후원을 받을 수 있는지
  bool get canAdDonate => s.adDay != s.day && s.streams > 0;

  int get adDonation => scaleMoney(s, 30000);

  /// 광고를 끝까지 보면 광고주가 후원을 보낸다
  int claimAdDonation() {
    final amount = adDonation;
    s.adDay = s.day;
    money(amount, '광고주 후원');
    log('🎬 광고주님이 방송을 보고 ${shortWon(amount)}을 후원했다!', 'event');
    emit('coin', 10);
    save();
    notifyListeners();
    return amount;
  }

  // ───── 찐팬 ─────
  void addCore(int n) => s.coreFans = (s.coreFans + n).clamp(0, s.followers);

  /// 구독자 중 찐팬 비율
  double get loyalty => s.coreFans / (s.followers + 50);

  /// 논란이 덜 커지는 정도 (0 ~ 0.3)
  double get shieldPower => min(0.3, loyalty * 1.5);

  // ───── 시청자 질문 ─────
  String? _lastQuestion;

  /// 방송 중에 시청자 질문이 올라온다 (없으면 null)
  ChatQuestion? rollQuestion([double chance = 0.3]) {
    if (rng.nextDouble() >= chance) return null;
    final pool = chatQuestions.where((q) => s.followers >= q.min && q.id != _lastQuestion).toList();
    if (pool.isEmpty) return null;
    final q = _pick(pool);
    _lastQuestion = q.id;
    return q;
  }

  /// 질문에 대답한다. (채팅 반응, 분위기, 변화)
  (List<String>, int, List<Change>) answerQuestion(ChatQuestion q, int index, int viewers) {
    final a = q.answers[index];
    final changes = applyFx(a.fx, '시청자 질문');
    if (a.core != 0) {
      final n = a.core * (1 + (viewers * 0.02).round());
      addCore(n);
      changes.add(_delta('찐팬', n, shortNum));
    }
    progress('question', 1);
    if (changes.isNotEmpty) toasts.add('💬 ${changes.map((c) => '${c.label} ${c.text}').join(' · ')}');
    log('🙋 "${q.question}" → ${a.label}');
    save();
    notifyListeners();
    return (a.reactions, a.hype, changes);
  }

  // ───── 방송 예고 ─────
  /// 이번 방송이 예고한 방송인지
  bool scheduleHit = false;

  bool isScheduled(Content c) => s.schedDay == s.day && s.schedSlot == s.slot && s.schedContent == c.id;

  /// 예고할 수 있는 시간 (day, slot): 지금 이후부터 내일 밤까지
  List<(int, int)> scheduleSlots() => [
        for (var sl = s.slot + 1; sl <= 2; sl++) (s.day, sl),
        for (var sl = 0; sl <= 2; sl++) (s.day + 1, sl),
      ];

  void setSchedule(int day, int slot, String content) {
    s.schedDay = day;
    s.schedSlot = slot;
    s.schedContent = content;
    log('📅 방송 예고: ${day == s.day ? '오늘' : '내일'} ${slotNames[slot]} ${contentOf(content).name}');
    pushFeed([sns.post(s, _pick(['{name} ${day == s.day ? '오늘' : '내일'} ${slotNames[slot]}에 ${contentOf(content).name} 한대!! 알람 맞춤', '예고 떴다 ${contentOf(content).icon} 무조건 본방', '{name} 예고 지키는지 보자 ㅋㅋ']), 'fan', g: sns.fanGender(s))]);
    save();
    notifyListeners();
  }

  void cancelSchedule() {
    s.schedDay = 0;
    save();
    notifyListeners();
  }

  /// 오늘 예고를 어겼으면 찐팬이 실망한다
  void _scheduleNight() {
    if (s.schedDay == 0 || s.schedDay > s.day) return;
    final lost = max(1, (s.coreFans * 0.08).round());
    addCore(-lost);
    s.image = (s.image - 2).clamp(-100, 100);
    s.schedDay = 0;
    log('📅 예고한 방송을 펑크 냈다… 찐팬 -${shortNum(lost)}, 이미지 -2', 'flop');
    pushFeed([sns.post(s, _pick(['{name} 예고 펑크 냄 ㅡㅡ 알람까지 맞췄는데', '기다렸는데 방송 안 켬…', '{name} 예고 믿은 내가 바보']), 'hate', g: sns.fanGender(s))]);
  }

  // ───── 오늘의 미션 ─────
  void _newMissions() {
    final kinds = missionKinds.where((k) => k.id != 'upload' || s.gear['pc']! >= 1).toList()..shuffle(rng);
    final reward = scaleMoney(s, 30000);
    s.missions = [
      for (final k in kinds.take(3))
        Mission(
          k.id,
          switch (k.id) {
            'stream' => 2,
            'gain' => max(10, (s.followers * 0.03 / 10).round() * 10),
            'donation' => scaleMoney(s, 20000),
            'react' => 2,
            _ => 1,
          },
          reward,
        ),
    ];
  }

  String missionText(Mission m) {
    final k = missionKindOf(m.kind);
    final n = m.kind == 'donation' ? shortWon(m.goal) : shortNum(m.goal);
    return '${k.icon} ${k.label.replaceAll('{n}', n)}';
  }

  /// 미션 진행. 다 채우면 보상을 바로 받는다
  void progress(String kind, int amount) {
    if (amount <= 0 || !unlocked('missions')) return;
    for (final m in s.missions.where((m) => m.kind == kind && !m.done)) {
      m.progress = min(m.goal, m.progress + amount);
      if (m.progress < m.goal) continue;
      m.done = true;
      s.missionsDone++;
      money(m.reward, '미션 보상');
      addCore(2 + s.followers ~/ 2000);
      toasts.add('🎯 미션 완료! +${shortWon(m.reward)}');
      log('🎯 미션 완료: ${missionText(m)} (+${shortWon(m.reward)})', 'milestone');
    }
  }

  // ───── 사업 ─────
  List<Business> get ownedBusinesses => businesses.where((b) => s.business.contains(b.id)).toList();

  /// 하루 수입: 이미지가 좋으면 더, 논란이 크면 불매로 반토막
  int businessIncome(Business b) {
    final v = (b.base + b.perFan * s.followers) * (1 + s.image / 200) * (s.heat >= 60 ? 0.5 : 1);
    return (v / 1000).round() * 1000;
  }

  String? businessBlock(Business b) {
    if (s.business.contains(b.id)) return '운영 중';
    if (s.followers < b.minFollowers) return '구독자 ${shortNum(b.minFollowers)} 필요';
    if (s.money < b.cost) return '돈 부족';
    return null;
  }

  bool openBusiness(Business b) {
    if (businessBlock(b) != null) return false;
    money(-b.cost, '${b.name} 창업');
    s.business.add(b.id);
    log('${b.icon} ${b.name}을(를) 열었다! 매일 밤 수익이 들어온다.', 'buy');
    toasts.add('${b.icon} ${b.name} 오픈!');
    pushFeed([sns.post(s, _pick(['{name} ${b.name} 오픈했대!! 가 봐야지', '{name} 이제 사업가네 ㄷㄷ', '{name} ${b.name} 대박 나라']), 'fan', g: sns.fanGender(s), boost: 2)]);
    emit('coin', 10);
    save();
    notifyListeners();
    return true;
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

  /// 목표 엔딩: 1만 → 10만 → 100만 → 순위 1위. 달성하면 엔딩 도감에 오르고, 계속 방송할 수 있다
  String? _goalEnding() {
    final f = s.followers;
    final goals = <(String, String, bool)>[
      ('mid', 'mid', f >= 10000),
      ('big', 'big', f >= 100000),
      ('celeb', s.image >= 0 ? 'celeb_good' : 'celeb_bad', f >= 1000000),
      ('top', 'top', s.lastRanks['me'] == 1),
    ];
    for (final (flag, key, ok) in goals) {
      if (!ok || s.flags.contains('goal_$flag')) continue;
      s.flags.add('goal_$flag');
      _repo.addEnding(key);
      log('🎬 엔딩 달성: ${endings[key]!.title}', 'milestone');
      return key;
    }
    return null;
  }

  /// 은퇴하면 지금까지의 성적으로 엔딩이 정해진다
  String retireEndingKey() {
    final f = s.followers;
    if (s.lastRanks['me'] == 1) return 'top';
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
        tag: key == 'scandal' ? '{name}_자숙' : (key == 'burnout' ? '{name}_휴방' : '{name}_은퇴'),
        headline: key == 'scandal'
            ? '{name}, 잇단 논란에 결국 자숙 선언'
            : key == 'burnout'
                ? '{name}, 건강 문제로 무기한 휴방'
                : '{name}, 방송 ${s.day}일 만에 은퇴 선언… 구독자 ${shortNum(s.followers)}',
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
