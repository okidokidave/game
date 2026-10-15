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
  // 목표 속도 (부지런히 플레이할 때): B2층 약 2분, B3층 약 15분,
  // B4층 약 45분, B5층 약 2시간, B6층 약 8시간.
  static const double workerBaseCost = 25;
  static const double workerCostGrowth = 1.3;

  static const double mineBaseCost = 800;
  static const double mineCostGrowth = 7;

  static const double pickaxeBaseCost = 40;
  static const double pickaxeCostGrowth = 2;

  // ── 오프라인 보상 ───────────────────────────────────
  /// 앱을 꺼 둔 시간 중 최대 몇 시간까지 보상하는지.
  static const Duration maxOfflineTime = Duration(hours: 4);

  /// 오프라인 동안은 실제 생산량의 몇 %를 주는지.
  static const double offlineEfficiency = 0.5;

  // ── 광고 보상 ───────────────────────────────────────
  /// 광고를 보면 채굴 속도가 몇 배가 되는지.
  static const double boostMultiplier = 2;

  /// 광고 한 번에 늘어나는 부스트 시간.
  static const Duration boostDuration = Duration(minutes: 5);

  /// 부스트를 최대 몇 분까지 쌓아 둘 수 있는지.
  static const Duration maxBoostTime = Duration(minutes: 30);

  // ── 돌발상황 / 좋은 일 ──────────────────────────────
  /// 평균 몇 초에 한 번 상황이 생기는지 (게임을 켜 둔 동안만).
  static const double eventMeanInterval = 150;

  /// 반장이 처리해야 하는 상황은 동시에 최대 몇 개까지.
  static const int maxForemanEvents = 2;

  /// 이만큼 벌기 전까지는 상황이 생기지 않는다 (처음 배우는 동안).
  static const double eventsStartAfterEarned = 100;

  /// 상황이 나올 비율 (합이 100일 필요는 없다).
  static const int fatigueWeight = 30;
  static const int injuryWeight = 15;
  static const int diamondWeight = 25;
  static const int goldVeinWeight = 30;

  /// 지친 인부의 작업 속도, 방치하면 다치기까지 걸리는 시간.
  static const double fatigueSpeed = 0.5;
  static const Duration fatigueToInjury = Duration(minutes: 3);

  /// 휴식 시간, 휴식 뒤 활력 시간과 속도.
  static const Duration restDuration = Duration(seconds: 20);
  static const Duration energizedDuration = Duration(minutes: 2);
  static const double energizedSpeed = 1.5;

  /// 부상: 저절로 낫는 시간, 치료비 (초당 생산량 × 이 초).
  static const Duration injuryHealTime = Duration(minutes: 10);
  static const double treatCostSeconds = 60;
  static const double minTreatCost = 20;

  /// 다이아몬드: 보상 (초당 생산량 × 이 초), 사라지기까지 시간.
  static const double diamondRewardSeconds = 120;
  static const double minDiamondReward = 50;
  static const Duration diamondExpireTime = Duration(minutes: 2);

  /// 금맥: 층 생산량 배수와 지속 시간.
  static const double goldVeinMultiplier = 3;
  static const Duration goldVeinDuration = Duration(minutes: 1);

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

  /// 인부는 위층부터 층마다 [workersPerMineLevel]명씩 배치된다.
  static int workersOnFloor(int floor, int totalWorkers) =>
      (totalWorkers - floor * workersPerMineLevel).clamp(
        0,
        workersPerMineLevel,
      );

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
