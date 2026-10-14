/// 저장되는 게임 데이터. 화면이나 계산 로직 없이 값만 가진다.
class GameState {
  GameState({
    this.gold = 0,
    this.totalEarned = 0,
    this.mineLevel = 1,
    this.workers = 1,
    this.pickaxeLevel = 1,
    DateTime? lastSavedAt,
  }) : lastSavedAt = lastSavedAt ?? DateTime.now();

  double gold;

  /// 지금까지 번 골드 총합 (업적, 통계용).
  double totalEarned;

  int mineLevel;
  int workers;
  int pickaxeLevel;

  /// 마지막으로 저장한 시각. 오프라인 보상 계산의 기준이 된다.
  DateTime lastSavedAt;

  Map<String, dynamic> toJson() => {
    'gold': gold,
    'totalEarned': totalEarned,
    'mineLevel': mineLevel,
    'workers': workers,
    'pickaxeLevel': pickaxeLevel,
    'lastSavedAt': lastSavedAt.millisecondsSinceEpoch,
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final savedAt = json['lastSavedAt'] as int?;
    return GameState(
      gold: (json['gold'] as num?)?.toDouble() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      mineLevel: json['mineLevel'] as int? ?? 1,
      workers: json['workers'] as int? ?? 1,
      pickaxeLevel: json['pickaxeLevel'] as int? ?? 1,
      lastSavedAt: savedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
  }
}
