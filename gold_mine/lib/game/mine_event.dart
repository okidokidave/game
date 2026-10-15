/// 광산에서 일어나는 돌발상황과 좋은 일.
///
/// 플레이어는 "현장 소장"이다. 피로·부상·다이아 발견은 소장이 직접 결정해야
/// 하고, 휴식·활력·금맥은 시간이 지나면 저절로 끝난다.
enum MineEventType {
  /// 인부가 지쳐서 절반 속도로 일한다. 소장이 휴식을 줄 때까지 계속된다.
  fatigue,

  /// 인부가 다쳐서 일을 못 한다. 치료하거나 시간이 지나면 회복한다.
  injury,

  /// 인부가 쉬는 중 (일 안 함). 끝나면 활력 상태가 된다.
  rest,

  /// 푹 쉰 인부가 빨리 일한다.
  energized,

  /// 인부가 다이아몬드를 찾았다. 소장이 받아야 골드가 된다.
  diamond,

  /// 층 전체에 금맥이 드러나 생산량이 늘어난다.
  goldVein,
}

extension MineEventTypeInfo on MineEventType {
  /// 소장이 눌러서 결정해야 하는 상황인지.
  bool get needsManager =>
      this == MineEventType.fatigue ||
      this == MineEventType.injury ||
      this == MineEventType.diamond;

  /// 층 전체에 걸리는 상황인지 (아니면 인부 한 명).
  bool get isFloorWide => this == MineEventType.goldVein;

  bool get isGood =>
      this == MineEventType.diamond ||
      this == MineEventType.goldVein ||
      this == MineEventType.energized;
}

class MineEvent {
  MineEvent({
    required this.id,
    required this.type,
    required this.floor,
    required this.worker,
    required this.startedAt,
    this.endsAt,
    this.reward = 0,
  });

  final int id;
  final MineEventType type;

  /// 0부터 시작하는 층 번호 (B1 = 0).
  final int floor;

  /// 층 안에서 몇 번째 인부인지 (층 전체 상황이면 -1).
  final int worker;

  final DateTime startedAt;

  /// 이 시각이 지나면 끝난다. null이면 소장이 처리할 때까지 계속.
  final DateTime? endsAt;

  /// 다이아몬드처럼 골드를 주는 상황의 보상.
  final double reward;

  bool isOver(DateTime now) => endsAt != null && !now.isBefore(endsAt!);

  Duration remaining(DateTime now) {
    if (endsAt == null) return Duration.zero;
    final left = endsAt!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool concerns(int floor, int worker) =>
      this.floor == floor && (type.isFloorWide || this.worker == worker);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'floor': floor,
    'worker': worker,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endsAt': endsAt?.millisecondsSinceEpoch,
    'reward': reward,
  };

  /// 알 수 없는 종류(예: 새 버전에서 만든 저장)는 null.
  static MineEvent? fromJson(Map<String, dynamic> json) {
    final type = MineEventType.values
        .where((t) => t.name == json['type'])
        .firstOrNull;
    if (type == null) return null;
    final endsAt = json['endsAt'] as int?;
    return MineEvent(
      id: json['id'] as int? ?? 0,
      type: type,
      floor: json['floor'] as int? ?? 0,
      worker: json['worker'] as int? ?? 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        json['startedAt'] as int? ?? 0,
      ),
      endsAt: endsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAt),
      reward: (json['reward'] as num?)?.toDouble() ?? 0,
    );
  }
}
