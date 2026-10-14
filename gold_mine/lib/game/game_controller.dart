import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_config.dart';
import 'game_state.dart';
import 'save_repository.dart';

/// 게임 규칙을 실행하고, 값이 바뀌면 화면에 알린다.
class GameController extends ChangeNotifier {
  /// [clock]은 테스트에서 시간을 바꿔 가며 확인할 때만 넘긴다.
  GameController(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _state = _repository.load() ?? GameState();

  static const _tickInterval = Duration(milliseconds: 100);

  final SaveRepository _repository;
  final DateTime Function() _clock;
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

  /// 부스트를 뺀 기본 초당 생산량. 오프라인 보상은 이 값으로 계산한다.
  double get baseGoldPerSecond =>
      GameConfig.goldPerSecond(_state.workers, _state.mineLevel);
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
        baseGoldPerSecond *
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
      tick((now - lastTick).inMicroseconds / Duration.microsecondsPerSecond);
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
    _state = GameState();
    await _repository.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
