// 저장되는 게임 데이터.

/// 캐릭터 외모 (색은 0xRRGGBB)
class Look {
  const Look({required this.hair, required this.shirt, this.long = false, this.gender = 'f', this.style = '', this.outfit = 'tee', this.acc = 'none'});
  final int hair;
  final int shirt;
  final bool long;

  /// 'm' 남자 / 'f' 여자
  final String gender;
  bool get male => gender == 'm';

  /// 머리 모양 (비어 있으면 long에 따라 숏컷/장발), 옷, 액세서리 (data.dart의 styleItems)
  final String style;
  final String outfit;
  final String acc;

  String get hairStyle => style.isEmpty ? (long ? 'long' : 'short') : style;

  Look copyWith({int? hair, bool? long, String? style, String? outfit, String? acc}) => Look(
        hair: hair ?? this.hair,
        shirt: shirt,
        long: long ?? this.long,
        gender: gender,
        style: style ?? this.style,
        outfit: outfit ?? this.outfit,
        acc: acc ?? this.acc,
      );

  Map<String, dynamic> toJson() => {'hair': hair, 'shirt': shirt, 'long': long, 'gender': gender, 'style': style, 'outfit': outfit, 'acc': acc};
  factory Look.fromJson(Map<String, dynamic> j) => Look(
        hair: j['hair'] as int,
        shirt: j['shirt'] as int,
        long: j['long'] as bool? ?? false,
        gender: j['gender'] as String? ?? 'f',
        style: j['style'] as String? ?? '',
        outfit: j['outfit'] as String? ?? 'tee',
        acc: j['acc'] as String? ?? 'none',
      );
}

/// SNS 글 하나 (답글 포함)
class Post {
  Post({
    required this.id,
    required this.nick,
    required this.handle,
    required this.color,
    required this.text,
    required this.side,
    required this.likes,
    required this.reposts,
    required this.day,
    required this.slot,
    List<Post>? replies,
    this.news = false,
    this.replyTo,
    this.g = '',
  }) : replies = replies ?? [];

  final String id;
  final String nick;
  final String handle;
  final int color;
  String text;

  /// hate(까) / shield(쉴드) / neutral / fan
  final String side;
  final int likes;
  final int reposts;
  final int day;
  final int slot;
  final List<Post> replies;
  final bool news;
  String? replyTo;

  /// 글쓴이 성별 'm' / 'f' (뉴스 계정은 '')
  final String g;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nick': nick,
        'handle': handle,
        'color': color,
        'text': text,
        'side': side,
        'likes': likes,
        'reposts': reposts,
        'day': day,
        'slot': slot,
        'replies': replies.map((r) => r.toJson()).toList(),
        'news': news,
        'replyTo': replyTo,
        'g': g,
      };

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        nick: j['nick'] as String,
        handle: j['handle'] as String,
        color: j['color'] as int,
        text: j['text'] as String,
        side: j['side'] as String,
        likes: j['likes'] as int,
        reposts: j['reposts'] as int,
        day: j['day'] as int,
        slot: j['slot'] as int,
        replies: (j['replies'] as List).map((r) => Post.fromJson(r as Map<String, dynamic>)).toList(),
        news: j['news'] as bool? ?? false,
        replyTo: j['replyTo'] as String?,
        g: j['g'] as String? ?? '',
      );
}

/// 실시간 트렌드에 오른 주제 (토론 피드)
class Trend {
  Trend({required this.tag, required this.headline, required this.shield, required this.hate, required this.day, required this.posts, this.response});
  final String tag;
  final String headline;
  int shield;
  int hate;
  final int day;
  final List<Post> posts;

  /// 내가 한 대응 (explain / sue / pin / ignore, 성공·실패는 explain_ok / explain_bad). 안 했으면 null
  String? response;

  /// 글과 답글을 다시 세어 여론을 갱신한다 (내 글은 빼고)
  void recount() {
    final all = [...posts, for (final p in posts) ...p.replies];
    shield = all.where((p) => p.side == 'shield' || p.side == 'fan').length;
    hate = all.where((p) => p.side == 'hate').length;
  }

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'headline': headline,
        'shield': shield,
        'hate': hate,
        'day': day,
        'posts': posts.map((p) => p.toJson()).toList(),
        'response': response,
      };

  factory Trend.fromJson(Map<String, dynamic> j) => Trend(
        tag: j['tag'] as String,
        headline: j['headline'] as String,
        shield: j['shield'] as int,
        hate: j['hate'] as int,
        day: j['day'] as int,
        posts: (j['posts'] as List).map((p) => Post.fromJson(p as Map<String, dynamic>)).toList(),
        response: j['response'] as String?,
      );
}

class LogEntry {
  const LogEntry(this.text, this.kind, this.day, this.slot);
  final String text;

  /// day / note / event / viral / flop / milestone / buy / ''
  final String kind;
  final int day;
  final int slot;

  Map<String, dynamic> toJson() => {'text': text, 'kind': kind, 'day': day, 'slot': slot};
  factory LogEntry.fromJson(Map<String, dynamic> j) =>
      LogEntry(j['text'] as String, j['kind'] as String, j['day'] as int, j['slot'] as int);
}

/// 통장 내역 한 줄 (+수입 / -지출)
class LedgerEntry {
  const LedgerEntry(this.day, this.label, this.amount);
  final int day;
  final String label;
  final int amount;

  Map<String, dynamic> toJson() => {'day': day, 'label': label, 'amount': amount};
  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(j['day'] as int, j['label'] as String, j['amount'] as int);
}

/// DM 한 통. kind: fan(응원) / hate(욕) / offer(제안)
class Dm {
  Dm({required this.id, required this.nick, required this.color, required this.text, required this.day, required this.kind, this.offer, this.status = 'open', this.read = false, this.note});
  final String id;
  final String nick;
  final int color;
  final String text;
  final int day;
  final String kind;

  /// 제안 DM이면 data.dart의 dmOffers id
  final String? offer;

  /// 제안 상태: open / accepted / declined / expired
  String status;
  bool read;

  /// 수락·거절한 뒤 보여 줄 결과 글
  String? note;

  Map<String, dynamic> toJson() =>
      {'id': id, 'nick': nick, 'color': color, 'text': text, 'day': day, 'kind': kind, 'offer': offer, 'status': status, 'read': read, 'note': note};
  factory Dm.fromJson(Map<String, dynamic> j) => Dm(
        id: j['id'] as String,
        nick: j['nick'] as String,
        color: j['color'] as int,
        text: j['text'] as String,
        day: j['day'] as int,
        kind: j['kind'] as String,
        offer: j['offer'] as String?,
        status: j['status'] as String? ?? 'open',
        read: j['read'] as bool? ?? false,
        note: j['note'] as String?,
      );
}

/// 오늘의 미션 하나. kind는 data.dart의 missionKinds
class Mission {
  Mission(this.kind, this.goal, this.reward, {this.progress = 0, this.done = false});
  final String kind;
  final int goal;
  final int reward;
  int progress;
  bool done;

  Map<String, dynamic> toJson() => {'kind': kind, 'goal': goal, 'reward': reward, 'progress': progress, 'done': done};
  factory Mission.fromJson(Map<String, dynamic> j) =>
      Mission(j['kind'] as String, j['goal'] as int, j['reward'] as int, progress: j['progress'] as int? ?? 0, done: j['done'] as bool? ?? false);
}

/// 하루가 끝날 때의 기록 (그래프용)
class DayStat {
  const DayStat(this.day, this.followers, this.money, this.peak, this.core);
  final int day;
  final int followers;
  final int money;

  /// 그날 최고 시청자
  final int peak;
  final int core;

  List<int> toJson() => [day, followers, money, peak, core];
  factory DayStat.fromJson(List<dynamic> j) => DayStat(j[0] as int, j[1] as int, j[2] as int, j[3] as int, j.length > 4 ? j[4] as int : 0);
}

/// 기억에 남는 방송 (최고 시청자 순 3개)
class BestStream {
  const BestStream(this.day, this.content, this.viewers);
  final int day;
  final String content;
  final int viewers;

  List<dynamic> toJson() => [day, content, viewers];
  factory BestStream.fromJson(List<dynamic> j) => BestStream(j[0] as int, j[1] as String, j[2] as int);
}

class GameState {
  GameState({
    required this.name,
    required this.look,
    required this.wallColor,
    required this.trend,
    this.day = 1,
    this.slot = 0,
    this.money = 30000,
    this.followers = 0,
    this.energy = 100,
    this.mental = 80,
    this.image = 0,
    this.heat = 0,
    Map<String, int>? gear,
    List<String>? deco,
    Map<String, int>? skills,
    Set<String>? flags,
    List<String>? seen,
    this.lastContent,
    this.lastViewers = 0,
    List<int>? milestones,
    List<Post>? feed,
    List<Trend>? trends,
    this.unread = 0,
    List<LogEntry>? log,
    this.mode = 'idle',
    this.streams = 0,
    this.peak = 0,
    this.earned = 0,
    this.uploads = 0,
    this.ended,
    double? maleFans,
    this.antis = 0,
    List<LedgerEntry>? ledger,
    this.house = 'banjiha',
    Map<String, int>? rivals,
    Map<String, int>? prevRanks,
    Map<String, int>? lastRanks,
    this.workplace = 0,
    this.workStrikes = 0,
    this.firedUntil = 0,
    List<String>? staff,
    List<Dm>? dms,
    this.lastGaffe = -99,
    this.coreFans = 0,
    this.schedDay = 0,
    this.schedSlot = 0,
    this.schedContent,
    this.schedKept = 0,
    this.missionsDone = 0,
    this.todayPeak = 0,
    this.lastEventDay = 0,
    this.adDay = 0,
    this.pet,
    Set<String>? owned,
    this.miniDay = 0,
    this.miniStars = 0,
    Map<String, int>? genreFans,
    List<Mission>? missions,
    List<DayStat>? history,
    List<BestStream>? best,
    List<String>? business,
  })  : genreFans = genreFans ?? {},
        owned = owned ?? {},
        missions = missions ?? [],
        history = history ?? [],
        best = best ?? [],
        business = business ?? [],
        dms = dms ?? [],
        staff = staff ?? [], rivals = rivals ?? {},
        prevRanks = prevRanks ?? {},
        lastRanks = lastRanks ?? {},
        ledger = ledger ?? [],
        maleFans = maleFans ?? (look.male ? 0.35 : 0.72),
        gear = gear ?? {'camera': 0, 'mic': 0, 'light': 0, 'pc': 0},
        deco = deco ?? [],
        skills = skills ?? {},
        flags = flags ?? {},
        seen = seen ?? [],
        milestones = milestones ?? [],
        feed = feed ?? [],
        trends = trends ?? [],
        log = log ?? [];

  String name;
  Look look;
  int wallColor;
  int day;

  /// 0 오전, 1 오후, 2 밤
  int slot;
  int money;
  int followers;
  int energy;
  int mental;

  /// -100 ~ 100
  int image;

  /// 논란 0 ~ 100
  int heat;
  final Map<String, int> gear;
  final List<String> deco;
  final Map<String, int> skills;
  final Set<String> flags;
  final List<String> seen;

  /// 이번 주 대세 콘텐츠 id
  String trend;
  String? lastContent;
  int lastViewers;
  final List<int> milestones;
  List<Post> feed;
  List<Trend> trends;
  int unread;
  List<LogEntry> log;

  /// 방 화면 모드: idle / live / sleep / away / stand
  String mode;
  int streams;
  int peak;
  int earned;
  int uploads;

  /// 끝났으면 엔딩 키
  String? ended;

  /// 팬 중 남자 비율 (0~1). 여자 방송인은 남자 팬이, 남자 방송인은 여자 팬이 많게 시작
  double maleFans;

  /// 안티 수 (사과 없이 넘어간 사고 등으로 생김)
  int antis;

  /// 통장 내역 (최신이 앞)
  List<LedgerEntry> ledger;

  /// 사는 집 (data.dart의 houses)
  String house;

  /// 라이벌 스트리머 구독자 (id → 구독자)
  Map<String, int> rivals;

  /// 그저께 밤 순위 (id → 순위, 나는 'me'). 순위표의 ▲▼ 표시용
  Map<String, int> prevRanks;

  /// 어젯밤 순위. 오늘 밤 순위 상승 알림 비교용
  Map<String, int> lastRanks;

  /// 알바하는 곳 (data.dart의 workplaces), 점장 경고 횟수, 잘린 뒤 다시 일할 수 있는 날
  int workplace;
  int workStrikes;
  int firedUntil;

  /// 고용한 직원 id (editor, manager)
  final List<String> staff;

  /// 받은 DM (최신이 앞)
  List<Dm> dms;

  /// 마지막으로 말실수한 날
  int lastGaffe;

  /// 찐팬 수 (논란이 나도 쉴드를 쳐 주고 후원을 많이 한다)
  int coreFans;

  /// 방송 예고 (schedDay가 0이면 예고 없음)
  int schedDay;
  int schedSlot;
  String? schedContent;

  /// 예고를 지킨 횟수, 완료한 미션 수
  int schedKept;
  int missionsDone;

  /// 오늘 최고 시청자 (그래프용)
  int todayPeak;

  /// 마지막으로 사건이 터진 날 (하루에 사건은 하나만)
  int lastEventDay;

  /// 광고주 후원을 받은 날 (하루 한 번)
  int adDay;

  /// 분양한 반려동물 (data.dart의 pets)
  String? pet;

  /// 오늘의 컨디션: 하루 첫 방송 미니게임을 한 날과 그 별 개수 (0~5)
  int miniDay;
  double miniStars;

  /// 장르별 팬 (그 콘텐츠로 방송해서 얻은 구독자). 장르별 순위에 쓴다
  final Map<String, int> genreFans;

  /// 뷰티샵에서 산 아이템 (기본 아이템은 빼고)
  final Set<String> owned;

  /// 오늘의 미션
  List<Mission> missions;

  /// 날짜별 기록, 기억에 남는 방송
  List<DayStat> history;
  List<BestStream> best;

  /// 연 사업 (data.dart의 businesses)
  final List<String> business;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'name': name,
        'look': look.toJson(),
        'wallColor': wallColor,
        'day': day,
        'slot': slot,
        'money': money,
        'followers': followers,
        'energy': energy,
        'mental': mental,
        'image': image,
        'heat': heat,
        'gear': gear,
        'deco': deco,
        'skills': skills,
        'flags': flags.toList(),
        'seen': seen,
        'trend': trend,
        'lastContent': lastContent,
        'lastViewers': lastViewers,
        'milestones': milestones,
        'feed': feed.map((p) => p.toJson()).toList(),
        'trends': trends.map((t) => t.toJson()).toList(),
        'unread': unread,
        'log': log.map((l) => l.toJson()).toList(),
        'streams': streams,
        'peak': peak,
        'earned': earned,
        'uploads': uploads,
        'maleFans': maleFans,
        'antis': antis,
        'ledger': ledger.map((l) => l.toJson()).toList(),
        'house': house,
        'rivals': rivals,
        'prevRanks': prevRanks,
        'lastRanks': lastRanks,
        'workplace': workplace,
        'workStrikes': workStrikes,
        'firedUntil': firedUntil,
        'staff': staff,
        'dms': dms.map((d) => d.toJson()).toList(),
        'lastGaffe': lastGaffe,
        'coreFans': coreFans,
        'schedDay': schedDay,
        'schedSlot': schedSlot,
        'schedContent': schedContent,
        'schedKept': schedKept,
        'missionsDone': missionsDone,
        'todayPeak': todayPeak,
        'lastEventDay': lastEventDay,
        'adDay': adDay,
        'pet': pet,
        'miniDay': miniDay,
        'miniStars': miniStars,
        'genreFans': genreFans,
        'owned': owned.toList(),
        'missions': missions.map((m) => m.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'best': best.map((b) => b.toJson()).toList(),
        'business': business,
      };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        name: j['name'] as String,
        look: Look.fromJson(j['look'] as Map<String, dynamic>),
        wallColor: j['wallColor'] as int,
        day: j['day'] as int,
        slot: j['slot'] as int,
        money: j['money'] as int,
        followers: j['followers'] as int,
        energy: j['energy'] as int,
        mental: j['mental'] as int,
        image: j['image'] as int,
        heat: j['heat'] as int,
        gear: Map<String, int>.from(j['gear'] as Map),
        deco: List<String>.from(j['deco'] as List),
        skills: Map<String, int>.from(j['skills'] as Map),
        flags: Set<String>.from(j['flags'] as List),
        seen: List<String>.from(j['seen'] as List),
        trend: j['trend'] as String,
        lastContent: j['lastContent'] as String?,
        lastViewers: j['lastViewers'] as int,
        milestones: List<int>.from(j['milestones'] as List),
        feed: (j['feed'] as List).map((p) => Post.fromJson(p as Map<String, dynamic>)).toList(),
        trends: (j['trends'] as List).map((t) => Trend.fromJson(t as Map<String, dynamic>)).toList(),
        unread: j['unread'] as int,
        log: (j['log'] as List).map((l) => LogEntry.fromJson(l as Map<String, dynamic>)).toList(),
        streams: j['streams'] as int,
        peak: j['peak'] as int,
        earned: j['earned'] as int,
        uploads: j['uploads'] as int,
        maleFans: (j['maleFans'] as num?)?.toDouble(),
        antis: j['antis'] as int? ?? 0,
        ledger: (j['ledger'] as List? ?? const []).map((l) => LedgerEntry.fromJson(l as Map<String, dynamic>)).toList(),
        // 이사 기능 전에 시작한 게임은 원룸에 살고 있었다
        house: j['house'] as String? ?? 'oneroom',
        rivals: Map<String, int>.from(j['rivals'] as Map? ?? const {}),
        prevRanks: Map<String, int>.from(j['prevRanks'] as Map? ?? const {}),
        lastRanks: Map<String, int>.from(j['lastRanks'] as Map? ?? const {}),
        workplace: j['workplace'] as int? ?? 0,
        workStrikes: j['workStrikes'] as int? ?? 0,
        firedUntil: j['firedUntil'] as int? ?? 0,
        staff: List<String>.from(j['staff'] as List? ?? const []),
        dms: (j['dms'] as List? ?? const []).map((d) => Dm.fromJson(d as Map<String, dynamic>)).toList(),
        lastGaffe: j['lastGaffe'] as int? ?? -99,
        coreFans: j['coreFans'] as int? ?? 0,
        schedDay: j['schedDay'] as int? ?? 0,
        schedSlot: j['schedSlot'] as int? ?? 0,
        schedContent: j['schedContent'] as String?,
        schedKept: j['schedKept'] as int? ?? 0,
        missionsDone: j['missionsDone'] as int? ?? 0,
        todayPeak: j['todayPeak'] as int? ?? 0,
        lastEventDay: j['lastEventDay'] as int? ?? 0,
        adDay: j['adDay'] as int? ?? 0,
        pet: j['pet'] as String?,
        miniDay: j['miniDay'] as int? ?? 0,
        miniStars: (j['miniStars'] as num?)?.toDouble() ?? 0,
        genreFans: Map<String, int>.from(j['genreFans'] as Map? ?? const {}),
        owned: Set<String>.from(j['owned'] as List? ?? const []),
        missions: (j['missions'] as List? ?? const []).map((m) => Mission.fromJson(m as Map<String, dynamic>)).toList(),
        history: (j['history'] as List? ?? const []).map((h) => DayStat.fromJson(h as List)).toList(),
        best: (j['best'] as List? ?? const []).map((b) => BestStream.fromJson(b as List)).toList(),
        business: List<String>.from(j['business'] as List? ?? const []),
      );
}

/// 끝난 판 하나의 기록 (회차 비교용, 판이 바뀌어도 남는다)
class RunRecord {
  const RunRecord({
    required this.name,
    required this.ending,
    required this.days,
    required this.followers,
    required this.peak,
    required this.earned,
    required this.streams,
    required this.core,
    required this.rank,
    required this.image,
    this.at = 0,
  });
  final String name;
  final String ending;
  final int days;
  final int followers;
  final int peak;
  final int earned;
  final int streams;
  final int core;

  /// 마지막 인기 순위
  final int rank;
  final int image;

  /// 끝난 시각 (밀리초)
  final int at;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ending': ending,
        'days': days,
        'followers': followers,
        'peak': peak,
        'earned': earned,
        'streams': streams,
        'core': core,
        'rank': rank,
        'image': image,
        'at': at,
      };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        name: j['name'] as String,
        ending: j['ending'] as String,
        days: j['days'] as int,
        followers: j['followers'] as int,
        peak: j['peak'] as int,
        earned: j['earned'] as int,
        streams: j['streams'] as int,
        core: j['core'] as int? ?? 0,
        rank: j['rank'] as int? ?? 0,
        image: j['image'] as int? ?? 0,
        at: j['at'] as int? ?? 0,
      );
}
