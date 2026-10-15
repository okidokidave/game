/// 갱도 밖 매점에서 파는 물건. 모두 인부의 체력(피로도)을 채워 준다.
library;

enum ShopTarget {
  /// 인부 한 명에게 먹인다 (인부를 골라서 사용).
  worker,

  /// 모든 인부에게 한 번에.
  everyone,

  /// 한동안 모든 인부의 체력이 줄지 않는다.
  buff,

  /// 사이보그 인부 업그레이드 부품 (인부 관리에서 쓴다).
  cyborgPart,
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.target,
    required this.costSeconds,
    required this.minCost,
    this.stamina = 0,
    this.buffMinutes = 0,
  });

  /// 저장할 때 쓰는 이름 (바꾸면 가진 물건이 사라지니 주의).
  final String id;
  final String emoji;
  final String name;
  final String description;
  final ShopTarget target;

  /// 가격 = 초당 생산량 × 이 초 (최소 [minCost]). 광산이 클수록 비싸진다.
  final double costSeconds;
  final double minCost;

  /// 채워 주는 체력 (100이면 완전 회복).
  final double stamina;

  /// [ShopTarget.buff]의 지속 시간.
  final int buffMinutes;
}

abstract final class Shop {
  static const energyDrink = ShopItem(
    id: 'energy_drink',
    emoji: '⚡',
    name: '에너지 드링크',
    description: '인부 한 명의 체력 +60',
    target: ShopTarget.worker,
    costSeconds: 30,
    minCost: 30,
    stamina: 60,
  );

  static const lunchBox = ShopItem(
    id: 'lunch_box',
    emoji: '🍱',
    name: '든든한 도시락',
    description: '인부 한 명의 체력을 가득',
    target: ShopTarget.worker,
    costSeconds: 50,
    minCost: 50,
    stamina: 100,
  );

  static const coffee = ShopItem(
    id: 'coffee',
    emoji: '☕',
    name: '믹스 커피',
    description: '모든 인부의 체력 +30',
    target: ShopTarget.everyone,
    costSeconds: 90,
    minCost: 80,
    stamina: 30,
  );

  static const stew = ShopItem(
    id: 'stew',
    emoji: '🍲',
    name: '보양식',
    description: '모든 인부의 체력을 가득',
    target: ShopTarget.everyone,
    costSeconds: 240,
    minCost: 200,
    stamina: 100,
  );

  static const vitamin = ShopItem(
    id: 'vitamin',
    emoji: '💊',
    name: '종합 비타민',
    description: '10분 동안 아무도 지치지 않아요',
    target: ShopTarget.buff,
    costSeconds: 180,
    minCost: 150,
    buffMinutes: 10,
  );

  static const cyborgPart = ShopItem(
    id: 'cyborg_part',
    emoji: '🔩',
    name: '사이보그 부품',
    description: '사이보그 인부 업그레이드용 (인부 관리에서 사용)',
    target: ShopTarget.cyborgPart,
    costSeconds: 240,
    minCost: 400,
  );

  static const List<ShopItem> items = [
    energyDrink,
    lunchBox,
    coffee,
    stew,
    vitamin,
    cyborgPart,
  ];

  static ShopItem? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
