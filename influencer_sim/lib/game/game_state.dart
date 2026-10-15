// 저장되는 게임 데이터.

/// 캐릭터 외모 (색은 0xRRGGBB)
class Look {
  const Look({required this.hair, required this.shirt, this.long = false});
  final int hair;
  final int shirt;
  final bool long;

  Map<String, dynamic> toJson() => {'hair': hair, 'shirt': shirt, 'long': long};
  factory Look.fromJson(Map<String, dynamic> j) =>
      Look(hair: j['hair'] as int, shirt: j['shirt'] as int, long: j['long'] as bool? ?? false);
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
      );
}

/// 실시간 트렌드에 오른 주제 (토론 피드)
class Trend {
  Trend({required this.tag, required this.headline, required this.shield, required this.hate, required this.day, required this.posts});
  final String tag;
  final String headline;
  final int shield;
  final int hate;
  final int day;
  final List<Post> posts;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'headline': headline,
        'shield': shield,
        'hate': hate,
        'day': day,
        'posts': posts.map((p) => p.toJson()).toList(),
      };

  factory Trend.fromJson(Map<String, dynamic> j) => Trend(
        tag: j['tag'] as String,
        headline: j['headline'] as String,
        shield: j['shield'] as int,
        hate: j['hate'] as int,
        day: j['day'] as int,
        posts: (j['posts'] as List).map((p) => Post.fromJson(p as Map<String, dynamic>)).toList(),
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
  })  : gear = gear ?? {'camera': 0, 'mic': 0, 'light': 0, 'pc': 0},
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
      );
}
