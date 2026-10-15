import 'dart:math';

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
    List<int>? workerGrades,
    List<double>? workerXp,
    this.regionIndex = 0,
    Map<String, int>? codex,
    List<String>? unseenOres,
    Map<int, double>? caretakers,
    List<double>? workerStamina,
    List<bool>? workerCollapsed,
    Map<String, int>? inventory,
    this.staminaBuffUntil,
    this.cyborgs = 0,
    this.cyborgLevel = 1,
    this.attendanceCount = 0,
    this.lastAttendanceDay,
  }) : workerStamina = workerStamina ?? [],
       workerCollapsed = workerCollapsed ?? [],
       inventory = inventory ?? {},
       codex = codex ?? {},
       unseenOres = unseenOres ?? [],
       caretakers = caretakers ?? {},
       lastSavedAt = lastSavedAt ?? DateTime.now(),
       events = events ?? [],
       workerGrades = workerGrades ?? [],
       workerXp = workerXp ?? [] {
    // 예전 저장에는 등급 정보가 없으니 인부 수만큼 견습으로 채운다.
    while (this.workerGrades.length < workers) {
      this.workerGrades.add(0);
    }
    while (this.workerXp.length < workers) {
      this.workerXp.add(0);
    }
    while (this.workerStamina.length < workers) {
      this.workerStamina.add(100);
    }
    while (this.workerCollapsed.length < workers) {
      this.workerCollapsed.add(false);
    }
  }

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

  /// 인부마다의 등급과 경험치. 순서는 B1의 첫 인부부터 층마다 3명씩.
  List<int> workerGrades;
  List<double> workerXp;

  /// 지금 운영 중인 지역 (Regions.all 순서).
  int regionIndex;

  /// 도감: 광석 id → 찾은 개수.
  Map<String, int> codex;

  /// 도감에서 아직 확인하지 않은 새 광석.
  List<String> unseenOres;

  /// 관리인에게 맡긴 지역 → 초당 보내 주는 골드.
  Map<int, double> caretakers;

  /// 인부마다의 체력(0~100)과 쓰러졌는지.
  List<double> workerStamina;
  List<bool> workerCollapsed;

  /// 매점에서 사서 가지고 있는 물건: 물건 id → 개수.
  Map<String, int> inventory;

  /// 비타민 효과가 끝나는 시각 (그때까지 아무도 지치지 않는다).
  DateTime? staminaBuffUntil;

  /// 출석 보상으로 받은 사이보그 인부 수 (0 또는 1, 지역을 옮겨도 따라온다).
  int cyborgs;

  /// 사이보그 인부 업그레이드 단계 (1부터).
  int cyborgLevel;

  /// 지금까지 출석한 날 수, 마지막으로 출석한 날 ("2026-10-15").
  int attendanceCount;
  String? lastAttendanceDay;

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
    'workerGrades': workerGrades,
    'workerXp': workerXp,
    'regionIndex': regionIndex,
    'codex': codex,
    'unseenOres': unseenOres,
    'cyborgs': cyborgs,
    'cyborgLevel': cyborgLevel,
    'attendanceCount': attendanceCount,
    'lastAttendanceDay': lastAttendanceDay,
    'workerStamina': workerStamina,
    'workerCollapsed': workerCollapsed,
    'inventory': inventory,
    'staminaBuffUntil': staminaBuffUntil?.millisecondsSinceEpoch,
    'caretakers': {for (final e in caretakers.entries) '${e.key}': e.value},
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
      workerGrades: [
        for (final g in (json['workerGrades'] as List<dynamic>? ?? const []))
          g as int,
      ],
      workerXp: [
        for (final x in (json['workerXp'] as List<dynamic>? ?? const []))
          (x as num).toDouble(),
      ],
      regionIndex: json['regionIndex'] as int? ?? 0,
      cyborgs: min(json['cyborgs'] as int? ?? 0, 1),
      cyborgLevel: max(json['cyborgLevel'] as int? ?? 1, 1),
      attendanceCount: json['attendanceCount'] as int? ?? 0,
      lastAttendanceDay: json['lastAttendanceDay'] as String?,
      workerStamina: [
        for (final v in (json['workerStamina'] as List<dynamic>? ?? const []))
          (v as num).toDouble(),
      ],
      workerCollapsed: [
        for (final v in (json['workerCollapsed'] as List<dynamic>? ?? const []))
          v as bool,
      ],
      inventory: {
        for (final e
            in (json['inventory'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as int,
      },
      staminaBuffUntil: json['staminaBuffUntil'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['staminaBuffUntil'] as int,
            ),
      codex: {
        for (final e
            in (json['codex'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as int,
      },
      unseenOres: [
        for (final id in (json['unseenOres'] as List<dynamic>? ?? const []))
          id as String,
      ],
      caretakers: {
        for (final e
            in (json['caretakers'] as Map<String, dynamic>? ?? const {})
                .entries)
          int.parse(e.key): (e.value as num).toDouble(),
      },
    );
  }
}
