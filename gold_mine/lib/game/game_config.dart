import 'dart:math';

/// 인부 등급. 일한 시간(경험치)이 차면 소장이 골드를 내고 승급시킨다.
class WorkerGrade {
  const WorkerGrade(
    this.name,
    this.multiplier, {
    this.xpToPromote,
    this.promoteCostSeconds = 0,
    this.minPromoteCost = 0,
  });

  final String name;

  /// 이 등급 인부의 생산량 배수.
  final double multiplier;

  /// 다음 등급까지 필요한 경험치 (일한 초). 마지막 등급이면 null.
  final double? xpToPromote;

  /// 승급 비용 = 초당 생산량 × 이 초 (최소 [minPromoteCost]).
  final double promoteCostSeconds;
  final double minPromoteCost;
}

/// 출석 보상 한 칸.
class AttendanceReward {
  const AttendanceReward.gold(
    this.emoji,
    this.name,
    this.goldSeconds,
    this.minGold,
  ) : itemId = null,
      count = 0,
      isCyborg = false;

  const AttendanceReward.item(this.emoji, this.name, this.itemId, this.count)
    : goldSeconds = 0,
      minGold = 0,
      isCyborg = false;

  const AttendanceReward.cyborg()
    : emoji = '🤖',
      name = '사이보그 인부',
      itemId = null,
      count = 1,
      goldSeconds = 0,
      minGold = 0,
      isCyborg = true;

  final String emoji;
  final String name;

  /// 골드 보상: 초당 생산량 × 이 초 (최소 [minGold]).
  final double goldSeconds;
  final double minGold;

  /// 물건 보상: 매점 물건 id와 개수.
  final String? itemId;
  final int count;

  final bool isCyborg;
}

/// 채굴 장비 단계. 장비 레벨이 [startLevel]에 닿으면 이 장비로 바뀐다.
class EquipmentTier {
  const EquipmentTier(
    this.name,
    this.startLevel,
    this.requiredMineLevel,
    this.multiplier,
  );

  final String name;
  final int startLevel;

  /// 이 장비를 들이려면 광산이 이 레벨(층 수) 이상이어야 한다.
  final int requiredMineLevel;

  /// 인부 생산량과 터치 채굴에 곱해지는 배수.
  final double multiplier;
}

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

  // ── 인부 등급 ───────────────────────────────────────
  static const List<WorkerGrade> workerGrades = [
    WorkerGrade(
      '견습',
      1,
      xpToPromote: 300,
      promoteCostSeconds: 90,
      minPromoteCost: 50,
    ),
    WorkerGrade(
      '숙련',
      1.5,
      xpToPromote: 1200,
      promoteCostSeconds: 300,
      minPromoteCost: 300,
    ),
    WorkerGrade(
      '베테랑',
      2.2,
      xpToPromote: 3600,
      promoteCostSeconds: 900,
      minPromoteCost: 2000,
    ),
    WorkerGrade('반장', 3),
  ];

  /// 마지막 등급(반장)의 번호. 반장은 층마다 한 명만 둘 수 있다.
  static int get foremanGrade => workerGrades.length - 1;

  /// 반장이 있는 층의 다른 인부들은 경험치가 이 배수로 쌓인다.
  static const double foremanXpBoost = 1.5;

  // ── 채굴 장비 단계 ──────────────────────────────────
  // 목표: 드릴 약 10분, 다이너마이트 약 30분, 굴착 기계 약 75분.
  static const List<EquipmentTier> equipmentTiers = [
    EquipmentTier('곡괭이', 1, 1, 1),
    EquipmentTier('착암 드릴', 4, 3, 1.5),
    EquipmentTier('다이너마이트', 8, 4, 2.5),
    EquipmentTier('굴착 기계', 12, 5, 4),
  ];

  /// 다이너마이트 단계 번호 (유황 지역 사고 판정에 쓴다).
  static const int dynamiteTier = 2;

  /// 장비 레벨이 몇 번째 단계인지 (0 = 곡괭이).
  static int equipmentTier(int equipmentLevel) {
    var tier = 0;
    for (var i = 0; i < equipmentTiers.length; i++) {
      if (equipmentLevel >= equipmentTiers[i].startLevel) tier = i;
    }
    return tier;
  }

  static double equipmentMultiplier(int equipmentLevel) =>
      equipmentTiers[equipmentTier(equipmentLevel)].multiplier;

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

  /// 소장이 처리해야 하는 상황은 동시에 최대 몇 개까지.
  static const int maxManagerEvents = 2;

  /// 이만큼 벌기 전까지는 상황이 생기지 않는다 (처음 배우는 동안).
  static const double eventsStartAfterEarned = 100;

  /// 상황이 나올 비율 (합이 100일 필요는 없다).
  /// 지친 인부는 이제 체력(피로도) 시스템으로 생긴다. 무작위로는 나오지 않는다.
  static const int fatigueWeight = 0;
  static const int injuryWeight = 15;
  static const int diamondWeight = 25;
  static const int goldVeinWeight = 30;

  /// 지역 장애물 (그 지역에서만 나온다).
  static const int floodWeight = 20;
  static const int ghostWeight = 20;

  // ── 침수 ────────────────────────────────────────────
  /// 물에 잠긴 층 인부들의 작업 속도 (물을 빼기 전까지 계속).
  static const double floodSpeed = 0.3;

  /// 양수기 대여비 (초당 생산량 × 이 초). 바로 물이 빠진다.
  static const double pumpCostSeconds = 90;
  static const double minPumpCost = 100;

  /// 인부들이 직접 퍼내면 걸리는 시간 (그동안 그 층은 채굴을 못 한다).
  static const Duration bailDuration = Duration(minutes: 3);

  // ── 귀신 ────────────────────────────────────────────
  /// 귀신이 나온 층 인부들은 겁에 질려 일을 못 한다. 그냥 두면 이만큼 뒤 떠난다.
  static const Duration ghostDuration = Duration(minutes: 8);

  /// 무당 부르는 값 (초당 생산량 × 이 초).
  static const double shamanCostSeconds = 150;
  static const double minShamanCost = 300;

  /// 굿 하는 시간, 굿이 끝난 뒤 신령님의 축복 (층 생산량 배수와 시간).
  static const Duration exorcismDuration = Duration(seconds: 20);
  static const double blessingMultiplier = 2;
  static const Duration blessingDuration = Duration(minutes: 3);

  /// 지친 인부(체력이 [tiredStamina] 아래)의 작업 속도.
  static const double fatigueSpeed = 0.5;

  // ── 체력 (피로도) ───────────────────────────────────
  static const double maxStamina = 100;

  /// 일하는 동안 초당 줄어드는 체력 (가득 찬 체력이 약 20분 만에 바닥).
  static const double staminaDrainPerSecond = 100 / (20 * 60);

  /// 이보다 낮으면 지쳐서 절반 속도로 일한다.
  static const double tiredStamina = 30;

  /// 쓰러진 인부는 이 속도로 체력을 되찾고, [tiredStamina]가 되면 일어난다
  /// (약 15분).
  static const double collapsedRegenPerSecond = 30 / (15 * 60);

  /// 게임을 꺼 둔 동안은 쉬면서 체력을 채운다 (30분이면 가득).
  static const double offlineStaminaPerSecond = 100 / (30 * 60);

  /// "쉬게 하기"를 하면 쉬고 난 뒤 채워지는 체력.
  static const double restStamina = 40;

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

  // ── 지역 / 막장 / 도감 ──────────────────────────────
  /// 막장 인부 한 명이 평균 몇 초 일하면 희귀 광석을 하나 찾는지.
  static const double rareOreInterval = 540;

  /// 한 지역의 광석을 모두 모으면 영구 생산량 보너스 (+10%).
  static const double regionSetBonus = 0.1;

  /// 떠난 광산을 맡은 관리인이 보내 주는 수입 (떠날 때 생산량의 10%).
  static const double caretakerShare = 0.1;

  /// 다음 지역 개척 비용 (지역이 바뀔수록 10배).
  static const double pioneerBaseCost = 1e6;
  static const double pioneerCostGrowth = 10;

  /// 유황 지역에서 다이너마이트를 쓸 때 부상 상황이 나올 비율 배수.
  static const int sulfurInjuryMultiplier = 4;

  // ── 사이보그 인부 / 출석 ─────────────────────────────
  /// 사이보그 인부(1단계)는 견습 인부보다 이만큼 더 캔다. 지치지도 다치지도 않는다.
  static const double cyborgMultiplier = 10;

  /// 업그레이드 한 단계마다 1단계 생산량의 이만큼씩 더 캔다 (+50%).
  static const double cyborgLevelBonus = 0.5;
  static const int maxCyborgLevel = 10;

  /// [level]단계 사이보그가 견습 인부 몇 명 몫을 캐는지.
  static double cyborgPower(int level) =>
      cyborgMultiplier * (1 + cyborgLevelBonus * (level - 1));

  /// [level]단계에서 다음 단계로 올리는 데 드는 부품 수.
  static int cyborgPartsFor(int level) => level;

  /// 사이보그를 이미 받았으면 7일째에는 부품을 대신 준다.
  static const int cyborgPartsReward = 3;

  /// 출석 보상 7일 (7일째 사이보그 인부, 딱 한 번). 다 받으면 1일째부터 다시.
  static const List<AttendanceReward> attendanceRewards = [
    AttendanceReward.gold('💰', '골드 꾸러미', 300, 200),
    AttendanceReward.item('⚡', '에너지 드링크', 'energy_drink', 3),
    AttendanceReward.item('☕', '믹스 커피', 'coffee', 2),
    AttendanceReward.gold('💰', '골드 상자', 900, 1000),
    AttendanceReward.item('🍱', '든든한 도시락', 'lunch_box', 3),
    AttendanceReward.item('💊', '종합 비타민', 'vitamin', 2),
    AttendanceReward.cyborg(),
  ];

  /// 자동 저장 주기.
  static const Duration autoSaveInterval = Duration(seconds: 10);

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

  static double goldPerSecond(
    int workers,
    int mineLevel, [
    int equipmentLevel = 1,
  ]) =>
      workers *
      goldPerWorkerPerSecond *
      mineMultiplier(mineLevel) *
      equipmentMultiplier(equipmentLevel);

  static double goldPerTap(int pickaxeLevel, int mineLevel) =>
      pickaxeLevel *
      mineMultiplier(mineLevel) *
      equipmentMultiplier(pickaxeLevel);

  /// 현재 [workers]명일 때 다음 인부를 고용하는 비용.
  static double workerCost(int workers) =>
      workerBaseCost * pow(workerCostGrowth, workers - 1);

  /// 현재 [mineLevel]에서 다음 레벨로 확장하는 비용.
  static double mineUpgradeCost(int mineLevel) =>
      mineBaseCost * pow(mineCostGrowth, mineLevel - 1);

  /// 현재 [pickaxeLevel]에서 다음 레벨로 강화하는 비용.
  static double pickaxeUpgradeCost(int pickaxeLevel) =>
      pickaxeBaseCost * pow(pickaxeCostGrowth, pickaxeLevel - 1);
}
