/// 광산 지역과 희귀 광석(도감) 정보.
///
/// 지역마다 막장(가장 깊은 층)이 정해져 있다. 막장까지 파 내려가면
/// 그 지역의 희귀 광석이 나오기 시작하고, 다음 지역을 개척할 수 있다.
/// 개척하면 새 지역 B1부터 다시 시작하고, 원래 광산은 관리인이 맡아
/// 적은 수입을 계속 보내 준다.
library;

enum OreRarity { common, rare, epic, legendary }

extension OreRarityInfo on OreRarity {
  String get label => switch (this) {
    OreRarity.common => '일반',
    OreRarity.rare => '희귀',
    OreRarity.epic => '영웅',
    OreRarity.legendary => '전설',
  };

  /// 막장에서 광석이 나올 때 이 등급이 뽑히는 비율.
  int get weight => switch (this) {
    OreRarity.common => 65,
    OreRarity.rare => 28,
    OreRarity.epic => 7,
    OreRarity.legendary => 2,
  };

  int get color => switch (this) {
    OreRarity.common => 0xFFB0BEC5,
    OreRarity.rare => 0xFF4FC3F7,
    OreRarity.epic => 0xFFBA68C8,
    OreRarity.legendary => 0xFFFFB300,
  };
}

class Ore {
  const Ore(this.id, this.name, this.rarity, this.color, this.description);

  /// 저장할 때 쓰는 이름 (바꾸면 저장된 도감이 사라지니 주의).
  final String id;
  final String name;
  final OreRarity rarity;

  /// 도감 그림 색 (0xAARRGGBB).
  final int color;
  final String description;
}

class Region {
  const Region({
    required this.name,
    required this.bottomFloor,
    required this.summary,
    required this.traits,
    required this.floorThemes,
    required this.ores,
    this.productionMultiplier = 1,
    this.dynamiteAccidents = false,
  });

  final String name;

  /// 막장 층 번호 (예: 5 = B5가 막장).
  final int bottomFloor;

  /// 지역 소개 한 줄.
  final String summary;

  /// 지역 특징 설명 (화면에 보여 줄 문장들).
  final List<String> traits;

  /// 층마다 쓰는 암석 그림 (sprites의 테마 번호). 모자라면 마지막 것을 쓴다.
  final List<int> floorThemes;

  final List<Ore> ores;

  /// 이 지역 인부 생산량 배수.
  final double productionMultiplier;

  /// 유황 가스: 다이너마이트를 쓰면 폭발 사고(부상)가 잦아진다.
  final bool dynamiteAccidents;

  int themeOf(int floor) =>
      floorThemes[floor < floorThemes.length ? floor : floorThemes.length - 1];
}

/// 암석 그림 테마 번호 (tool/generate_sprites.py 의 THEMES 순서).
abstract final class RockTheme {
  static const int dirt = 0;
  static const int stone = 1;
  static const int deepStone = 2;
  static const int crystal = 3;
  static const int lava = 4;
  static const int sulfur = 5;
}

abstract final class Regions {
  static const List<Region> all = [
    Region(
      name: '금빛 언덕 광산',
      bottomFloor: 5,
      summary: '처음 맡게 된 작은 광산. 흙과 돌 사이로 금이 드문드문 보인다.',
      traits: ['특별한 위험이 없는 무난한 광산이에요.'],
      floorThemes: [
        RockTheme.dirt,
        RockTheme.stone,
        RockTheme.deepStone,
        RockTheme.crystal,
        RockTheme.lava,
      ],
      ores: [
        Ore(
          'golden_nugget',
          '황금 원석',
          OreRarity.common,
          0xFFFFD23F,
          '손바닥만 한 순금 덩어리. 언덕 광부들의 자랑거리.',
        ),
        Ore(
          'silver_mica',
          '은빛 운모',
          OreRarity.rare,
          0xFFCFD8DC,
          '얇은 판이 겹겹이 쌓인 은빛 광물. 빛을 받으면 반짝인다.',
        ),
        Ore(
          'ancient_amber',
          '고대 호박',
          OreRarity.epic,
          0xFFFF9800,
          '먼 옛날 곤충이 갇혀 있는 호박. 수집가들이 탐낸다.',
        ),
      ],
    ),
    Region(
      name: '유황 골짜기',
      bottomFloor: 6,
      summary: '노란 연기가 피어오르는 골짜기. 광석이 풍부하지만 위험하다.',
      traits: [
        '광석이 풍부해 생산량 ×1.5',
        '⚠ 유황 가스! 다이너마이트를 쓰면 폭발 사고가 자주 나요',
        '굴착 기계는 불꽃이 적어 안전해요',
      ],
      floorThemes: [
        RockTheme.sulfur,
        RockTheme.sulfur,
        RockTheme.deepStone,
        RockTheme.sulfur,
        RockTheme.lava,
        RockTheme.lava,
      ],
      productionMultiplier: 1.5,
      dynamiteAccidents: true,
      ores: [
        Ore(
          'sulfur_crystal',
          '유황 결정',
          OreRarity.common,
          0xFFFFEB3B,
          '바늘처럼 뾰족한 노란 결정. 코를 찌르는 냄새가 난다.',
        ),
        Ore(
          'volcanic_glass',
          '화산 유리',
          OreRarity.rare,
          0xFF37474F,
          '용암이 순식간에 식어 만들어진 검은 유리.',
        ),
        Ore(
          'flame_ruby',
          '불꽃 루비',
          OreRarity.epic,
          0xFFE53935,
          '안에서 불길이 일렁이는 듯한 붉은 보석.',
        ),
      ],
    ),
  ];

  static Region at(int index) => all[index.clamp(0, all.length - 1)];

  static Iterable<Ore> get allOres => all.expand((r) => r.ores);

  static Ore? oreById(String id) {
    for (final ore in allOres) {
      if (ore.id == id) return ore;
    }
    return null;
  }

  /// 광석이 나온 지역 번호.
  static int regionOf(Ore ore) =>
      all.indexWhere((r) => r.ores.any((o) => o.id == ore.id));
}
