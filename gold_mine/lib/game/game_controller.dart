import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game_config.dart';
import 'game_state.dart';
import 'mine_event.dart';
import 'regions.dart';
import 'shop.dart';
import 'save_repository.dart';

/// 화면에서 소리·효과를 붙일 수 있게 알려 주는 게임 속 순간들.
enum GameCue {
  promotionReady,
  oreFound,
  newOre,
  setComplete,
  workerTired,
  workerCollapsed,
}

/// 게임 규칙을 실행하고, 값이 바뀌면 화면에 알린다.
class GameController extends ChangeNotifier {
  /// [clock]과 [random]은 테스트에서 시간과 운을 정해 두고 확인할 때만 넘긴다.
  GameController(this._repository, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random(),
      _state = _repository.load() ?? GameState() {
    // 예전 버전의 무작위 "지친 인부" 상황은 체력 시스템이 대신한다.
    _state.events.removeWhere((e) => e.type == MineEventType.fatigue);
  }

  static const _tickInterval = Duration(milliseconds: 100);

  final SaveRepository _repository;
  final DateTime Function() _clock;
  final Random _random;

  /// 상황이 생기거나 바뀔 때 화면에 알리는 함수 (소장에게 보고).
  void Function(MineEvent event, String message)? onEventNotice;

  /// 그 밖의 소식 (예: 승급 준비 완료)을 소장에게 알리는 함수.
  void Function(String message)? onMessage;

  /// 소리를 붙일 순간 (메시지와 함께 온다).
  void Function(GameCue cue)? onCue;
  GameState _state;
  Timer? _ticker;

  // ── 읽기용 값 ───────────────────────────────────────
  double get gold => _state.gold;
  double get totalEarned => _state.totalEarned;
  int get mineLevel => _state.mineLevel;
  int get workers => _state.workers;
  int get pickaxeLevel => _state.pickaxeLevel;
  int get maxWorkers => GameConfig.maxWorkers(_state.mineLevel);
  String get mineName => region.name;

  /// 돌발상황이 없을 때의 초당 생산량. 오프라인 보상은 이 값으로 계산한다.
  double get steadyGoldPerSecond {
    var grades = 0.0;
    for (var slot = 0; slot < _state.workers; slot++) {
      grades += gradeOf(slot).multiplier;
    }
    return _perWorkerGold * (grades + cyborgPower) + caretakerIncome;
  }

  /// 사이보그 인부 전원이 1초에 캐는 골드.
  double get cyborgGoldPerSecond =>
      _perWorkerGold * GameConfig.cyborgMultiplier * _state.cyborgs;

  /// 사이보그 인부들의 생산량 (견습 인부 몇 명분인지).
  double get cyborgPower => _state.cyborgs * GameConfig.cyborgMultiplier;

  /// 관리인에게 맡긴 광산들이 보내 주는 초당 골드.
  double get caretakerIncome =>
      _state.caretakers.values.fold(0.0, (sum, v) => sum + v);

  /// 견습 인부 한 명이 1초에 캐는 골드 (광산 레벨, 장비 반영).
  double get _perWorkerGold =>
      GameConfig.goldPerWorkerPerSecond *
      GameConfig.mineMultiplier(_state.mineLevel) *
      GameConfig.equipmentMultiplier(_state.pickaxeLevel) *
      region.productionMultiplier *
      codexMultiplier;

  /// 돌발상황(부상, 금맥 등)을 반영하고 광고 부스트는 뺀 초당 생산량.
  double get baseGoldPerSecond {
    final perWorker = _perWorkerGold;
    var total = 0.0;
    for (var f = 0; f < _state.mineLevel; f++) {
      final count = GameConfig.workersOnFloor(f, _state.workers);
      var floorTotal = 0.0;
      for (var i = 0; i < count; i++) {
        floorTotal += workerSpeed(f, i) * workerGrade(f, i).multiplier;
      }
      total += floorTotal * floorMultiplier(f);
    }
    return (total + cyborgPower) * perWorker + caretakerIncome;
  }

  /// 광고 부스트는 지금 광산에만 걸리고, 관리인 수입에는 걸리지 않는다.
  double get goldPerSecond =>
      (baseGoldPerSecond - caretakerIncome) *
          (isBoostActive ? GameConfig.boostMultiplier : 1) +
      caretakerIncome;
  double get goldPerTap =>
      GameConfig.goldPerTap(_state.pickaxeLevel, _state.mineLevel) *
      region.productionMultiplier *
      codexMultiplier;

  double get workerCost => GameConfig.workerCost(_state.workers);
  double get mineUpgradeCost => GameConfig.mineUpgradeCost(_state.mineLevel);
  double get pickaxeUpgradeCost =>
      GameConfig.pickaxeUpgradeCost(_state.pickaxeLevel);

  bool get isWorkerFull => _state.workers >= maxWorkers;
  bool get canHireWorker => !isWorkerFull && gold >= workerCost;
  bool get canUpgradeMine => !isAtBottom && gold >= mineUpgradeCost;

  // ── 지역 / 막장 / 도감 ──────────────────────────────
  int get regionIndex => _state.regionIndex;
  Region get region => Regions.at(_state.regionIndex);

  /// 막장(이 지역의 가장 깊은 층)까지 파 내려갔는지.
  bool get isAtBottom => _state.mineLevel >= region.bottomFloor;

  Region? get nextRegion => _state.regionIndex + 1 < Regions.all.length
      ? Regions.all[_state.regionIndex + 1]
      : null;

  double get pioneerCost =>
      GameConfig.pioneerBaseCost *
      pow(GameConfig.pioneerCostGrowth, _state.regionIndex);

  bool get canPioneer =>
      isAtBottom && nextRegion != null && gold >= pioneerCost;

  /// 다음 지역을 개척한다. 지금 광산은 관리인에게 맡기고,
  /// 새 지역 B1에서 인부 한 명과 곡괭이로 다시 시작한다.
  bool pioneer() {
    if (!canPioneer) return false;
    _state.gold -= pioneerCost;
    // 사이보그는 새 지역으로 따라오므로 관리인 몫에서 뺀다.
    _state.caretakers[_state.regionIndex] =
        (steadyGoldPerSecond - caretakerIncome - cyborgGoldPerSecond) *
        GameConfig.caretakerShare;
    _state
      ..regionIndex += 1
      ..mineLevel = 1
      ..workers = 1
      ..pickaxeLevel = 1
      ..workerGrades = [0]
      ..workerXp = [0]
      ..workerStamina = [GameConfig.maxStamina]
      ..workerCollapsed = [false]
      ..events = [];
    notifyListeners();
    return true;
  }

  int oreCount(Ore ore) => _state.codex[ore.id] ?? 0;
  bool isDiscovered(Ore ore) => oreCount(ore) > 0;
  bool isUnseen(Ore ore) => _state.unseenOres.contains(ore.id);
  int get unseenOreCount => _state.unseenOres.length;

  /// 도감을 열어 새 광석을 확인했다.
  void markCodexSeen() {
    if (_state.unseenOres.isEmpty) return;
    _state.unseenOres.clear();
    notifyListeners();
  }

  bool isRegionComplete(Region r) => r.ores.every(isDiscovered);

  int get completedSets => Regions.all.where(isRegionComplete).length;

  double get codexMultiplier => 1 + GameConfig.regionSetBonus * completedSets;

  /// 막장에서 일하는 인부들이 가끔 희귀 광석을 찾는다.
  void _findRareOres(double seconds) {
    if (!isAtBottom || seconds <= 0) return;
    final floor = region.bottomFloor - 1;
    final count = GameConfig.workersOnFloor(floor, _state.workers);
    for (var i = 0; i < count; i++) {
      final chance =
          seconds * workerSpeed(floor, i) / GameConfig.rareOreInterval;
      if (chance > 0 && _random.nextDouble() < chance) _discover(_pickOre());
    }
  }

  Ore _pickOre() {
    final ores = region.ores;
    final total = ores.fold(0, (sum, o) => sum + o.rarity.weight);
    var roll = _random.nextInt(total);
    for (final ore in ores) {
      if (roll < ore.rarity.weight) return ore;
      roll -= ore.rarity.weight;
    }
    return ores.last;
  }

  void _discover(Ore ore) {
    final first = !isDiscovered(ore);
    final completedBefore = isRegionComplete(region);
    _state.codex[ore.id] = oreCount(ore) + 1;
    if (first) {
      _state.unseenOres.add(ore.id);
      onMessage?.call('📖 도감 등록! ${ore.name} (${ore.rarity.label})을(를) 찾았어요!');
      onCue?.call(GameCue.newOre);
    } else {
      onMessage?.call('✨ ${ore.name} 발견! (보관 ${oreCount(ore)}개)');
      onCue?.call(GameCue.oreFound);
    }
    if (!completedBefore && isRegionComplete(region)) {
      onCue?.call(GameCue.setComplete);
      onMessage?.call(
        '🎉 ${region.name} 도감 완성! 생산량이 영구히 '
        '+${(GameConfig.regionSetBonus * 100).round()}% 올라요!',
      );
    }
    notifyListeners();
  }

  bool get canUpgradePickaxe =>
      equipmentLockedUntilMine == null && gold >= pickaxeUpgradeCost;

  // ── 채굴 장비 ───────────────────────────────────────
  /// 지금 장비 단계 (0 곡괭이, 1 드릴, 2 다이너마이트, 3 굴착 기계).
  int get equipmentTier => GameConfig.equipmentTier(_state.pickaxeLevel);

  EquipmentTier get equipment => GameConfig.equipmentTiers[equipmentTier];

  /// 다음 레벨에서 새 장비로 바뀌면 그 장비, 아니면 null.
  EquipmentTier? get nextEquipment {
    final next = GameConfig.equipmentTier(_state.pickaxeLevel + 1);
    return next != equipmentTier ? GameConfig.equipmentTiers[next] : null;
  }

  /// 다음 장비를 들이려면 필요한 광산 레벨. 지금 강화할 수 있으면 null.
  int? get equipmentLockedUntilMine {
    final next = nextEquipment;
    if (next == null || _state.mineLevel >= next.requiredMineLevel) {
      return null;
    }
    return next.requiredMineLevel;
  }

  Duration get boostRemaining {
    final endsAt = _state.boostEndsAt;
    if (endsAt == null) return Duration.zero;
    final remaining = endsAt.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isBoostActive => boostRemaining > Duration.zero;

  /// 부스트를 한 번 더 쌓아도 최대 시간을 넘지 않을 때만 true.
  bool get canActivateBoost =>
      boostRemaining + GameConfig.boostDuration <= GameConfig.maxBoostTime;

  // ── 돌발상황 / 좋은 일 ──────────────────────────────
  List<MineEvent> get events => List.unmodifiable(_state.events);

  /// 소장이 결정해야 하는 상황 (오래된 것부터).
  List<MineEvent> get managerEvents => [
    for (final e in _state.events)
      if (e.type.needsManager) e,
  ];

  /// 인부 한 명에게 걸린 상황 (없으면 null).
  MineEvent? workerEvent(int floor, int worker) {
    for (final e in _state.events) {
      if (!e.type.isFloorWide && e.floor == floor && e.worker == worker) {
        return e;
      }
    }
    return null;
  }

  MineEvent? floorEvent(int floor) {
    for (final e in _state.events) {
      if (e.type.isFloorWide && e.floor == floor) return e;
    }
    return null;
  }

  MineEvent? eventById(int id) {
    for (final e in _state.events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 인부 한 명의 작업 속도 (0 = 쉼, 1 = 보통). 애니메이션 속도로도 쓴다.
  double workerSpeed(int floor, int worker) {
    switch (workerEvent(floor, worker)?.type) {
      case MineEventType.injury:
      case MineEventType.rest:
      case MineEventType.diamond:
        return 0;
      case MineEventType.energized:
        return GameConfig.energizedSpeed;
      case MineEventType.fatigue:
      case MineEventType.goldVein:
      case null:
        break;
    }
    final slot = slotOf(floor, worker);
    if (isCollapsed(slot)) return 0;
    if (isTired(slot)) return GameConfig.fatigueSpeed;
    return 1;
  }

  double floorMultiplier(int floor) =>
      floorEvent(floor) != null ? GameConfig.goldVeinMultiplier : 1;

  double get treatCost => max(
    GameConfig.minTreatCost,
    steadyGoldPerSecond * GameConfig.treatCostSeconds,
  );

  bool get canTreat => gold >= treatCost;

  /// 인부를 쉬게 한다. 쉬고 나면 체력이 차고 한동안 빨리 일한다.
  /// 다쳤거나 이미 쉬는 중이면 쉬게 할 수 없다.
  bool restWorker(int slot) {
    final floor = slot ~/ GameConfig.workersPerMineLevel;
    final worker = slot % GameConfig.workersPerMineLevel;
    if (workerEvent(floor, worker) != null) return false;
    _add(MineEventType.rest, floor, worker, _clock(), GameConfig.restDuration);
    notifyListeners();
    return true;
  }

  /// 다친 인부를 치료한다. [free]면 (광고 시청 등) 치료비를 받지 않는다.
  bool treatInjury(int eventId, {bool free = false}) {
    final e = eventById(eventId);
    if (e == null || e.type != MineEventType.injury) return false;
    if (!free) {
      if (!canTreat) return false;
      _state.gold -= treatCost;
    }
    _state.events.remove(e);
    notifyListeners();
    return true;
  }

  /// 다이아몬드를 골드로 바꾼다. 받은 골드를 돌려준다.
  double collectDiamond(int eventId, {double multiplier = 1}) {
    final e = eventById(eventId);
    if (e == null || e.type != MineEventType.diamond) return 0;
    final earned = e.reward * multiplier;
    _earn(earned);
    _state.events.remove(e);
    notifyListeners();
    return earned;
  }

  /// [seconds]초만큼 상황을 진행한다: 끝난 상황 정리, 새 상황 발생.
  void updateEvents(double seconds) {
    final now = _clock();
    var changed = _expireEvents(now);
    if (seconds > 0 &&
        _state.totalEarned >= GameConfig.eventsStartAfterEarned &&
        _random.nextDouble() < seconds / GameConfig.eventMeanInterval) {
      changed = _spawnEvent(now) || changed;
    }
    _findRareOres(seconds);
    if (changed) notifyListeners();
  }

  bool _expireEvents(DateTime now) {
    var changed = false;
    for (final e in List.of(_state.events)) {
      if (!e.isOver(now)) continue;
      changed = true;
      switch (e.type) {
        case MineEventType.rest:
          final slot = slotOf(e.floor, e.worker);
          _setStamina(slot, staminaOf(slot) + GameConfig.restStamina);
          final energized = _replace(
            e,
            MineEventType.energized,
            GameConfig.energizedDuration,
          );
          _notice(energized, 'B${e.floor + 1} 인부가 푹 쉬고 힘이 넘쳐요!');
        case MineEventType.injury:
          _state.events.remove(e);
          _notice(e, 'B${e.floor + 1} 인부가 회복해서 다시 일해요.');
        case MineEventType.diamond:
          _state.events.remove(e);
          _notice(e, '앗, B${e.floor + 1} 다이아몬드를 놓쳤어요...');
        case MineEventType.fatigue:
        case MineEventType.energized:
        case MineEventType.goldVein:
          _state.events.remove(e);
      }
    }
    return changed;
  }

  bool _spawnEvent(DateTime now) {
    if (managerEvents.length >= GameConfig.maxManagerEvents) return false;

    final type = _pickEventType();
    if (type == MineEventType.goldVein) {
      final floors = [
        for (var f = 0; f < _state.mineLevel; f++)
          if (floorEvent(f) == null &&
              GameConfig.workersOnFloor(f, _state.workers) > 0)
            f,
      ];
      if (floors.isEmpty) return false;
      final floor = floors[_random.nextInt(floors.length)];
      final e = _add(type, floor, -1, now, GameConfig.goldVeinDuration);
      _notice(e, '소장님! B${floor + 1}에서 금맥이 드러났어요! 1분간 생산 3배!');
      return true;
    }

    final free = <(int, int)>[
      for (var f = 0; f < _state.mineLevel; f++)
        for (var i = 0; i < GameConfig.workersOnFloor(f, _state.workers); i++)
          if (workerEvent(f, i) == null) (f, i),
    ];
    if (free.isEmpty) return false;
    final (floor, worker) = free[_random.nextInt(free.length)];
    final name = 'B${floor + 1} 인부';
    switch (type) {
      case MineEventType.fatigue:
        _notice(_add(type, floor, worker, now, null), '소장님, $name가 많이 지쳤어요.');
      case MineEventType.injury:
        _notice(
          _add(type, floor, worker, now, GameConfig.injuryHealTime),
          _sulfurDanger
              ? '💥 유황 가스에 불이 붙었어요! $name가 다쳤어요!'
              : '소장님, $name가 다쳤어요!',
        );
      case MineEventType.diamond:
        final reward = max(
          GameConfig.minDiamondReward,
          steadyGoldPerSecond * GameConfig.diamondRewardSeconds,
        );
        _notice(
          _add(
            type,
            floor,
            worker,
            now,
            GameConfig.diamondExpireTime,
            reward: reward,
          ),
          '소장님! $name가 다이아몬드를 찾았어요!',
        );
      case MineEventType.rest:
      case MineEventType.energized:
      case MineEventType.goldVein:
        return false;
    }
    return true;
  }

  /// 유황 지역에서 다이너마이트를 쓰는 중이면 폭발 사고가 잦다.
  bool get _sulfurDanger =>
      region.dynamiteAccidents && equipmentTier == GameConfig.dynamiteTier;

  MineEventType _pickEventType() {
    final weighted = [
      (MineEventType.fatigue, GameConfig.fatigueWeight),
      (
        MineEventType.injury,
        GameConfig.injuryWeight *
            (_sulfurDanger ? GameConfig.sulfurInjuryMultiplier : 1),
      ),
      (MineEventType.diamond, GameConfig.diamondWeight),
      (MineEventType.goldVein, GameConfig.goldVeinWeight),
    ];
    final total = weighted.fold(0, (sum, w) => sum + w.$2);
    var roll = _random.nextInt(total);
    for (final (type, weight) in weighted) {
      if (roll < weight) return type;
      roll -= weight;
    }
    return MineEventType.goldVein;
  }

  MineEvent _add(
    MineEventType type,
    int floor,
    int worker,
    DateTime now,
    Duration? duration, {
    double reward = 0,
  }) {
    final e = MineEvent(
      id: _state.nextEventId++,
      type: type,
      floor: floor,
      worker: worker,
      startedAt: now,
      endsAt: duration == null ? null : now.add(duration),
      reward: reward,
    );
    _state.events.add(e);
    return e;
  }

  MineEvent _replace(MineEvent old, MineEventType type, Duration duration) {
    _state.events.remove(old);
    return _add(type, old.floor, old.worker, _clock(), duration);
  }

  void _notice(MineEvent e, String message) => onEventNotice?.call(e, message);

  // ── 체력 (피로도) ───────────────────────────────────
  double staminaOf(int slot) => _state.workerStamina[slot];
  bool isCollapsed(int slot) => _state.workerCollapsed[slot];
  bool isTired(int slot) =>
      !isCollapsed(slot) && staminaOf(slot) < GameConfig.tiredStamina;

  /// 비타민 효과가 남아 있어 아무도 지치지 않는지.
  bool get isStaminaBuffActive =>
      _state.staminaBuffUntil != null &&
      _clock().isBefore(_state.staminaBuffUntil!);

  Duration get staminaBuffRemaining => isStaminaBuffActive
      ? _state.staminaBuffUntil!.difference(_clock())
      : Duration.zero;

  /// 돌봐야 하는 인부 수 (지쳤거나 쓰러짐).
  int get exhaustedCount => [
    for (var s = 0; s < _state.workers; s++)
      if (isCollapsed(s) || isTired(s)) s,
  ].length;

  void _setStamina(int slot, double value) {
    _state.workerStamina[slot] = value.clamp(0, GameConfig.maxStamina);
    // 체력이 조금이라도 생기면 쓰러졌던 인부가 일어난다.
    if (isCollapsed(slot) && staminaOf(slot) >= GameConfig.tiredStamina) {
      _state.workerCollapsed[slot] = false;
    }
  }

  /// 일한 만큼 체력이 줄고, 쓰러진 인부는 천천히 회복한다.
  void _useStamina(double seconds) {
    final buff = isStaminaBuffActive;
    for (var slot = 0; slot < _state.workers; slot++) {
      final label = workerLabel(slot);
      if (isCollapsed(slot)) {
        _setStamina(
          slot,
          staminaOf(slot) + seconds * GameConfig.collapsedRegenPerSecond,
        );
        if (!isCollapsed(slot)) {
          onMessage?.call('$label 인부가 겨우 일어나 다시 일해요.');
        }
        continue;
      }
      if (buff) continue;
      final floor = slot ~/ GameConfig.workersPerMineLevel;
      final speed = workerSpeed(floor, slot % GameConfig.workersPerMineLevel);
      if (speed <= 0) continue;
      final wasTired = isTired(slot);
      final next =
          staminaOf(slot) - seconds * GameConfig.staminaDrainPerSecond * speed;
      _state.workerStamina[slot] = max(0, next);
      if (staminaOf(slot) <= 0) {
        _state.workerCollapsed[slot] = true;
        onMessage?.call('😵 소장님! $label 인부가 지쳐 쓰러졌어요! 매점에서 먹을 것을 사 주세요.');
        onCue?.call(GameCue.workerCollapsed);
      } else if (!wasTired && isTired(slot)) {
        onMessage?.call('💦 $label 인부가 지쳤어요. 체력을 채워 주세요.');
        onCue?.call(GameCue.workerTired);
      }
    }
  }

  // ── 출석 / 사이보그 ─────────────────────────────────
  int get cyborgs => _state.cyborgs;
  int get attendanceCount => _state.attendanceCount;

  static String _dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 오늘 아직 출석 보상을 받지 않았는지.
  bool get canCheckIn => _state.lastAttendanceDay != _dayKey(_clock());

  /// 이번 주기에서 오늘 받을 보상 칸 (0~6).
  int get attendanceSlot =>
      _state.attendanceCount % GameConfig.attendanceRewards.length;

  AttendanceReward get todaysReward =>
      GameConfig.attendanceRewards[attendanceSlot];

  double rewardGold(AttendanceReward r) =>
      max(r.minGold, (steadyGoldPerSecond - caretakerIncome) * r.goldSeconds);

  /// 오늘 출석하고 보상을 받는다. 받은 보상을 돌려준다 (이미 받았으면 null).
  AttendanceReward? checkIn() {
    if (!canCheckIn) return null;
    final reward = todaysReward;
    if (reward.isCyborg) {
      _state.cyborgs++;
    } else if (reward.itemId != null) {
      _state.inventory[reward.itemId!] =
          (_state.inventory[reward.itemId!] ?? 0) + reward.count;
    } else {
      _earn(rewardGold(reward));
    }
    _state.attendanceCount++;
    _state.lastAttendanceDay = _dayKey(_clock());
    notifyListeners();
    return reward;
  }

  // ── 매점 ────────────────────────────────────────────
  int itemCount(ShopItem item) => _state.inventory[item.id] ?? 0;

  /// 가격은 광산 규모(관리인 수입 제외 생산량)에 맞춰 오른다.
  double itemCost(ShopItem item) => max(
    item.minCost,
    (steadyGoldPerSecond - caretakerIncome) * item.costSeconds,
  );

  bool canBuy(ShopItem item) => gold >= itemCost(item);

  bool buyItem(ShopItem item) {
    if (!canBuy(item)) return false;
    _state.gold -= itemCost(item);
    _state.inventory[item.id] = itemCount(item) + 1;
    notifyListeners();
    return true;
  }

  /// 인부 한 명에게 먹인다 ([ShopTarget.worker] 물건).
  bool feedWorker(ShopItem item, int slot) {
    if (item.target != ShopTarget.worker || itemCount(item) <= 0) return false;
    _state.inventory[item.id] = itemCount(item) - 1;
    _setStamina(slot, staminaOf(slot) + item.stamina);
    _state.workerCollapsed[slot] = false;
    notifyListeners();
    return true;
  }

  /// 모두에게 쓰는 물건이나 비타민을 쓴다.
  bool useItem(ShopItem item) {
    if (item.target == ShopTarget.worker || itemCount(item) <= 0) {
      return false;
    }
    _state.inventory[item.id] = itemCount(item) - 1;
    if (item.target == ShopTarget.everyone) {
      for (var slot = 0; slot < _state.workers; slot++) {
        _setStamina(slot, staminaOf(slot) + item.stamina);
        _state.workerCollapsed[slot] = false;
      }
    } else {
      final from = isStaminaBuffActive ? _state.staminaBuffUntil! : _clock();
      _state.staminaBuffUntil = from.add(Duration(minutes: item.buffMinutes));
    }
    notifyListeners();
    return true;
  }

  // ── 인부 등급 ───────────────────────────────────────
  /// 인부 번호 (B1의 첫 인부가 0, 층마다 3명씩).
  static int slotOf(int floor, int worker) =>
      floor * GameConfig.workersPerMineLevel + worker;

  /// "B1-2"처럼 화면에 보이는 인부 이름.
  static String workerLabel(int slot) =>
      'B${slot ~/ GameConfig.workersPerMineLevel + 1}-'
      '${slot % GameConfig.workersPerMineLevel + 1}';

  WorkerGrade gradeOf(int slot) =>
      GameConfig.workerGrades[_state.workerGrades[slot]];

  int gradeIndexOf(int slot) => _state.workerGrades[slot];

  WorkerGrade workerGrade(int floor, int worker) =>
      gradeOf(slotOf(floor, worker));

  double xpOf(int slot) => _state.workerXp[slot];

  /// 다음 등급까지 필요한 경험치. 최고 등급이면 null.
  double? xpNeeded(int slot) => gradeOf(slot).xpToPromote;

  /// 경험치가 다 찼고, 승급할 자리도 있는지.
  bool isPromotionReady(int slot) {
    final need = xpNeeded(slot);
    return need != null && xpOf(slot) >= need && !isBlockedByForeman(slot);
  }

  /// 베테랑이 반장이 되려는데 그 층에 이미 반장이 있으면 true.
  bool isBlockedByForeman(int slot) =>
      gradeIndexOf(slot) + 1 == GameConfig.foremanGrade &&
      foremanOnFloor(slot ~/ GameConfig.workersPerMineLevel) != null;

  /// [floor]층 반장의 인부 번호 (없으면 null).
  int? foremanOnFloor(int floor) {
    final first = floor * GameConfig.workersPerMineLevel;
    final count = GameConfig.workersOnFloor(floor, _state.workers);
    for (var slot = first; slot < first + count; slot++) {
      if (gradeIndexOf(slot) == GameConfig.foremanGrade) return slot;
    }
    return null;
  }

  int get promotionReadyCount => [
    for (var s = 0; s < _state.workers; s++)
      if (isPromotionReady(s)) s,
  ].length;

  double promotionCost(int slot) {
    final grade = gradeOf(slot);
    return max(
      grade.minPromoteCost,
      steadyGoldPerSecond * grade.promoteCostSeconds,
    );
  }

  bool canPromote(int slot) =>
      isPromotionReady(slot) && gold >= promotionCost(slot);

  /// 소장이 인부를 다음 등급으로 올린다.
  bool promote(int slot) {
    if (!canPromote(slot)) return false;
    _state.gold -= promotionCost(slot);
    _state.workerGrades[slot]++;
    _state.workerXp[slot] = 0;
    notifyListeners();
    return true;
  }

  /// 일한 만큼 경험치를 쌓는다 (지치면 느리게, 쉬거나 다치면 안 쌓임).
  void _gainXp(double seconds, {required bool notify}) {
    for (var slot = 0; slot < _state.workers; slot++) {
      final need = xpNeeded(slot);
      if (need == null || xpOf(slot) >= need) continue;
      final floor = slot ~/ GameConfig.workersPerMineLevel;
      final worker = slot % GameConfig.workersPerMineLevel;
      // 같은 층 반장이 이끌어 주면 경험치가 빨리 쌓인다.
      final lead = foremanOnFloor(floor) != null
          ? GameConfig.foremanXpBoost
          : 1.0;
      _state.workerXp[slot] = min(
        need,
        xpOf(slot) + seconds * workerSpeed(floor, worker) * lead,
      );
      if (notify && isPromotionReady(slot)) {
        onMessage?.call(
          '소장님, ${workerLabel(slot)} ${gradeOf(slot).name} 인부가 '
          '승급할 준비가 됐어요! ⬆',
        );
        onCue?.call(GameCue.promotionReady);
      }
    }
  }

  // ── 게임 동작 ───────────────────────────────────────
  /// 인부들이 [seconds]초 동안 채굴한다.
  void tick(double seconds) {
    if (seconds <= 0) return;
    _earn(goldPerSecond * seconds);
    _gainXp(seconds, notify: true);
    _useStamina(seconds);
    notifyListeners();
  }

  /// 광산을 직접 터치해서 채굴한다. 얻은 골드를 돌려준다.
  double tap() {
    final earned = goldPerTap;
    _earn(earned);
    notifyListeners();
    return earned;
  }

  bool hireWorker() {
    if (!canHireWorker) return false;
    _state.gold -= workerCost;
    _state.workers++;
    _state.workerGrades.add(0);
    _state.workerXp.add(0);
    _state.workerStamina.add(GameConfig.maxStamina);
    _state.workerCollapsed.add(false);
    notifyListeners();
    return true;
  }

  bool upgradeMine() {
    if (!canUpgradeMine) return false;
    _state.gold -= mineUpgradeCost;
    _state.mineLevel++;
    notifyListeners();
    return true;
  }

  bool upgradePickaxe() {
    if (!canUpgradePickaxe) return false;
    _state.gold -= pickaxeUpgradeCost;
    _state.pickaxeLevel++;
    notifyListeners();
    return true;
  }

  /// 광고 시청 보상: 채굴 속도 부스트 시간을 늘린다.
  bool activateBoost() {
    if (!canActivateBoost) return false;
    _state.boostEndsAt = _clock().add(
      boostRemaining + GameConfig.boostDuration,
    );
    notifyListeners();
    return true;
  }

  /// 광고 시청 보상: 골드를 바로 지급한다 (오프라인 보상 2배 등).
  void grantBonusGold(double amount) {
    if (amount <= 0) return;
    _earn(amount);
    notifyListeners();
  }

  /// 마지막 저장 이후 [now]까지 앱이 꺼져 있던 동안의 보상을 지급한다.
  /// 지급한 골드를 돌려준다.
  double collectOfflineEarnings(DateTime now) {
    var elapsed = now.difference(_state.lastSavedAt);
    // 기기 시간을 과거로 돌린 경우에는 보상하지 않는다.
    if (elapsed.isNegative) elapsed = Duration.zero;
    if (elapsed > GameConfig.maxOfflineTime) {
      elapsed = GameConfig.maxOfflineTime;
    }
    final seconds = elapsed.inMilliseconds / 1000;
    final earned = steadyGoldPerSecond * seconds * GameConfig.offlineEfficiency;
    _state.lastSavedAt = now;
    _gainXp(seconds * GameConfig.offlineEfficiency, notify: false);
    // 자리를 비운 동안 인부들은 쉬면서 체력을 채운다.
    for (var slot = 0; slot < _state.workers; slot++) {
      _setStamina(
        slot,
        staminaOf(slot) + seconds * GameConfig.offlineStaminaPerSecond,
      );
    }
    if (earned > 0) {
      _earn(earned);
      notifyListeners();
    }
    return earned;
  }

  void _earn(double amount) {
    _state.gold += amount;
    _state.totalEarned += amount;
  }

  // ── 실시간 진행 & 저장 ──────────────────────────────
  /// 0.1초마다 채굴을 진행하고 주기적으로 자동 저장한다.
  void start() {
    _ticker?.cancel();
    final clock = Stopwatch()..start();
    var lastTick = Duration.zero;
    var lastSave = Duration.zero;
    _ticker = Timer.periodic(_tickInterval, (_) {
      final now = clock.elapsed;
      final seconds =
          (now - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
      updateEvents(seconds);
      tick(seconds);
      lastTick = now;
      if (now - lastSave >= GameConfig.autoSaveInterval) {
        lastSave = now;
        save();
      }
    });
  }

  bool get isRunning => _ticker != null;

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> save([DateTime? now]) {
    _state.lastSavedAt = now ?? _clock();
    return _repository.save(_state);
  }

  /// 저장 데이터를 지우고 처음부터 다시 시작한다.
  Future<void> reset() async {
    _state = GameState(lastSavedAt: _clock());
    await _repository.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
