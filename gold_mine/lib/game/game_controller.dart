import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game_config.dart';
import 'game_state.dart';
import 'mine_event.dart';
import 'save_repository.dart';

/// 게임 규칙을 실행하고, 값이 바뀌면 화면에 알린다.
class GameController extends ChangeNotifier {
  /// [clock]과 [random]은 테스트에서 시간과 운을 정해 두고 확인할 때만 넘긴다.
  GameController(this._repository, {DateTime Function()? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random(),
      _state = _repository.load() ?? GameState();

  static const _tickInterval = Duration(milliseconds: 100);

  final SaveRepository _repository;
  final DateTime Function() _clock;
  final Random _random;

  /// 상황이 생기거나 바뀔 때 화면에 알리는 함수 (반장에게 보고).
  void Function(MineEvent event, String message)? onEventNotice;
  GameState _state;
  Timer? _ticker;

  // ── 읽기용 값 ───────────────────────────────────────
  double get gold => _state.gold;
  double get totalEarned => _state.totalEarned;
  int get mineLevel => _state.mineLevel;
  int get workers => _state.workers;
  int get pickaxeLevel => _state.pickaxeLevel;
  int get maxWorkers => GameConfig.maxWorkers(_state.mineLevel);
  String get mineName => GameConfig.mineName(_state.mineLevel);

  /// 돌발상황이 없을 때의 초당 생산량. 오프라인 보상은 이 값으로 계산한다.
  double get steadyGoldPerSecond =>
      GameConfig.goldPerSecond(_state.workers, _state.mineLevel);

  /// 돌발상황(부상, 금맥 등)을 반영하고 광고 부스트는 뺀 초당 생산량.
  double get baseGoldPerSecond {
    final perWorker =
        GameConfig.goldPerWorkerPerSecond *
        GameConfig.mineMultiplier(_state.mineLevel);
    var total = 0.0;
    for (var f = 0; f < _state.mineLevel; f++) {
      final count = GameConfig.workersOnFloor(f, _state.workers);
      var floorTotal = 0.0;
      for (var i = 0; i < count; i++) {
        floorTotal += workerSpeed(f, i);
      }
      total += floorTotal * floorMultiplier(f);
    }
    return total * perWorker;
  }

  double get goldPerSecond =>
      baseGoldPerSecond * (isBoostActive ? GameConfig.boostMultiplier : 1);
  double get goldPerTap =>
      GameConfig.goldPerTap(_state.pickaxeLevel, _state.mineLevel);

  double get workerCost => GameConfig.workerCost(_state.workers);
  double get mineUpgradeCost => GameConfig.mineUpgradeCost(_state.mineLevel);
  double get pickaxeUpgradeCost =>
      GameConfig.pickaxeUpgradeCost(_state.pickaxeLevel);

  bool get isWorkerFull => _state.workers >= maxWorkers;
  bool get canHireWorker => !isWorkerFull && gold >= workerCost;
  bool get canUpgradeMine => gold >= mineUpgradeCost;
  bool get canUpgradePickaxe => gold >= pickaxeUpgradeCost;

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

  /// 반장이 결정해야 하는 상황 (오래된 것부터).
  List<MineEvent> get foremanEvents => [
    for (final e in _state.events)
      if (e.type.needsForeman) e,
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
      case MineEventType.fatigue:
        return GameConfig.fatigueSpeed;
      case MineEventType.injury:
      case MineEventType.rest:
      case MineEventType.diamond:
        return 0;
      case MineEventType.energized:
        return GameConfig.energizedSpeed;
      case MineEventType.goldVein:
      case null:
        return 1;
    }
  }

  double floorMultiplier(int floor) =>
      floorEvent(floor) != null ? GameConfig.goldVeinMultiplier : 1;

  double get treatCost => max(
    GameConfig.minTreatCost,
    steadyGoldPerSecond * GameConfig.treatCostSeconds,
  );

  bool get canTreat => gold >= treatCost;

  /// 지친 인부를 쉬게 한다. 쉬고 나면 한동안 빨리 일한다.
  bool restWorker(int eventId) {
    final e = eventById(eventId);
    if (e == null || e.type != MineEventType.fatigue) return false;
    _replace(e, MineEventType.rest, GameConfig.restDuration);
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
    if (changed) notifyListeners();
  }

  bool _expireEvents(DateTime now) {
    var changed = false;
    for (final e in List.of(_state.events)) {
      if (e.type == MineEventType.fatigue &&
          now.difference(e.startedAt) >= GameConfig.fatigueToInjury) {
        final injury = _replace(
          e,
          MineEventType.injury,
          GameConfig.injuryHealTime,
        );
        _notice(injury, '반장님, B${e.floor + 1} 인부가 무리하다 다쳤어요!');
        changed = true;
        continue;
      }
      if (!e.isOver(now)) continue;
      changed = true;
      switch (e.type) {
        case MineEventType.rest:
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
    if (foremanEvents.length >= GameConfig.maxForemanEvents) return false;

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
      _notice(e, '반장님! B${floor + 1}에서 금맥이 드러났어요! 1분간 생산 3배!');
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
        _notice(_add(type, floor, worker, now, null), '반장님, $name가 많이 지쳤어요.');
      case MineEventType.injury:
        _notice(
          _add(type, floor, worker, now, GameConfig.injuryHealTime),
          '반장님, $name가 다쳤어요!',
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
          '반장님! $name가 다이아몬드를 찾았어요!',
        );
      case MineEventType.rest:
      case MineEventType.energized:
      case MineEventType.goldVein:
        return false;
    }
    return true;
  }

  MineEventType _pickEventType() {
    const weighted = [
      (MineEventType.fatigue, GameConfig.fatigueWeight),
      (MineEventType.injury, GameConfig.injuryWeight),
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

  // ── 게임 동작 ───────────────────────────────────────
  /// 인부들이 [seconds]초 동안 채굴한다.
  void tick(double seconds) {
    if (seconds <= 0) return;
    _earn(goldPerSecond * seconds);
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
    final earned =
        steadyGoldPerSecond *
        (elapsed.inMilliseconds / 1000) *
        GameConfig.offlineEfficiency;
    _state.lastSavedAt = now;
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
