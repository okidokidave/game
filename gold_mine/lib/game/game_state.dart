import 'mine_event.dart';

/// 저장되는 게임 데이터. 화면이나 계산 로직 없이 값만 가진다.
class GameState {
  GameState({
    this.gold = 0,
    this.totalEarned = 0,
    this.mineLevel = 1,
    this.workers = 1,
    this.pickaxeLevel = 1,
    DateTime? lastSavedAt,
    this.boostEndsAt,
    List<MineEvent>? events,
    this.nextEventId = 1,
  }) : lastSavedAt = lastSavedAt ?? DateTime.now(),
       events = events ?? [];

  double gold;

  /// 지금까지 번 골드 총합 (업적, 통계용).
  double totalEarned;

  int mineLevel;
  int workers;
  int pickaxeLevel;

  /// 마지막으로 저장한 시각. 오프라인 보상 계산의 기준이 된다.
  DateTime lastSavedAt;

  /// 광고 부스트가 끝나는 시각. 부스트가 없으면 null.
  DateTime? boostEndsAt;

  /// 진행 중인 돌발상황과 좋은 일.
  List<MineEvent> events;
  int nextEventId;

  Map<String, dynamic> toJson() => {
    'gold': gold,
    'totalEarned': totalEarned,
    'mineLevel': mineLevel,
    'workers': workers,
    'pickaxeLevel': pickaxeLevel,
    'lastSavedAt': lastSavedAt.millisecondsSinceEpoch,
    'boostEndsAt': boostEndsAt?.millisecondsSinceEpoch,
    'events': [for (final e in events) e.toJson()],
    'nextEventId': nextEventId,
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final savedAt = json['lastSavedAt'] as int?;
    final boostEndsAt = json['boostEndsAt'] as int?;
    return GameState(
      gold: (json['gold'] as num?)?.toDouble() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      mineLevel: json['mineLevel'] as int? ?? 1,
      workers: json['workers'] as int? ?? 1,
      pickaxeLevel: json['pickaxeLevel'] as int? ?? 1,
      lastSavedAt: savedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedAt),
      boostEndsAt: boostEndsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(boostEndsAt),
      events: [
        for (final e in (json['events'] as List<dynamic>? ?? const []))
          ?MineEvent.fromJson(e as Map<String, dynamic>),
      ],
      nextEventId: json['nextEventId'] as int? ?? 1,
    );
  }
}
