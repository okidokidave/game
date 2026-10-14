import 'dart:math';

/// 게임 밸런스 숫자를 한곳에 모아 둔 클래스.
///
/// 여기 있는 숫자만 바꿔도 게임 속도와 난이도를 조절할 수 있다.
class GameConfig {
  GameConfig._();

  // ── 생산 ────────────────────────────────────────────
  /// 광산 1레벨에서 인부 한 명이 1초에 캐는 골드.
  static const double goldPerWorkerPerSecond = 1.0;

  /// 광산 레벨이 1 오를 때마다 생산량에 곱해지는 배수.
  static const double mineMultiplierGrowth = 1.6;

  /// 광산 레벨 1당 고용할 수 있는 인부 수.
  static const int workersPerMineLevel = 3;

  // ── 비용 ────────────────────────────────────────────
  static const double workerBaseCost = 10;
  static const double workerCostGrowth = 1.15;

  static const double mineBaseCost = 100;
  static const double mineCostGrowth = 3.5;

  static const double pickaxeBaseCost = 15;
  static const double pickaxeCostGrowth = 1.5;

  // ── 오프라인 보상 ───────────────────────────────────
  /// 앱을 꺼 둔 시간 중 최대 몇 시간까지 보상하는지.
  static const Duration maxOfflineTime = Duration(hours: 8);

  /// 오프라인 동안은 실제 생산량의 몇 %를 주는지.
  static const double offlineEfficiency = 0.5;

  // ── 광고 보상 ───────────────────────────────────────
  /// 광고를 보면 채굴 속도가 몇 배가 되는지.
  static const double boostMultiplier = 2;

  /// 광고 한 번에 늘어나는 부스트 시간.
  static const Duration boostDuration = Duration(minutes: 5);

  /// 부스트를 최대 몇 분까지 쌓아 둘 수 있는지.
  static const Duration maxBoostTime = Duration(minutes: 30);

  /// 자동 저장 주기.
  static const Duration autoSaveInterval = Duration(seconds: 10);

  static const List<String> mineNames = [
    '작은 광산',
    '동굴 광산',
    '깊은 갱도',
    '수정 광맥',
    '용암 광산',
    '고대 광산',
    '황금 왕국',
  ];

  // ── 계산식 ──────────────────────────────────────────
  static double mineMultiplier(int mineLevel) =>
      pow(mineMultiplierGrowth, mineLevel - 1).toDouble();

  static int maxWorkers(int mineLevel) => mineLevel * workersPerMineLevel;

  static double goldPerSecond(int workers, int mineLevel) =>
      workers * goldPerWorkerPerSecond * mineMultiplier(mineLevel);

  static double goldPerTap(int pickaxeLevel, int mineLevel) =>
      pickaxeLevel * mineMultiplier(mineLevel);

  /// 현재 [workers]명일 때 다음 인부를 고용하는 비용.
  static double workerCost(int workers) =>
      workerBaseCost * pow(workerCostGrowth, workers - 1);

  /// 현재 [mineLevel]에서 다음 레벨로 확장하는 비용.
  static double mineUpgradeCost(int mineLevel) =>
      mineBaseCost * pow(mineCostGrowth, mineLevel - 1);

  /// 현재 [pickaxeLevel]에서 다음 레벨로 강화하는 비용.
  static double pickaxeUpgradeCost(int pickaxeLevel) =>
      pickaxeBaseCost * pow(pickaxeCostGrowth, pickaxeLevel - 1);

  static String mineName(int mineLevel) {
    if (mineLevel <= mineNames.length) return mineNames[mineLevel - 1];
    return '${mineNames.last} +${mineLevel - mineNames.length}';
  }
}
