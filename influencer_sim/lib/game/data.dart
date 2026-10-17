// 스트리머 키우기 — 게임 데이터
//
// 장비, 꾸미기, 방송 종류, 이벤트, SNS 반응 문구를 모아 둔 파일.
// 문구 안의 {name}은 플레이어가 정한 방송 닉네임으로 바뀐다.

import 'dart:math';

import 'game_state.dart';

const slotNames = ['오전', '오후', '밤'];

// ───── 장비 ─────
class GearTier {
  const GearTier(this.name, this.price);
  final String name;
  final int price;
}

class GearType {
  const GearType(this.key, this.label, this.icon, this.tiers);
  final String key;
  final String label;
  final String icon;
  final List<GearTier> tiers;
}

/// 순서대로 한 단계씩만 살 수 있다.
const gearTypes = [
  GearType('camera', '카메라', '📷', [
    GearTier('스마트폰 카메라', 0),
    GearTier('FHD 웹캠', 80000),
    GearTier('미러리스 카메라', 900000),
    GearTier('시네마 카메라', 4500000),
  ]),
  GearType('mic', '마이크', '🎙️', [
    GearTier('폰 내장 마이크', 0),
    GearTier('핀 마이크', 50000),
    GearTier('콘덴서 마이크', 350000),
    GearTier('스튜디오 마이크 세트', 2000000),
  ]),
  GearType('light', '조명', '💡', [
    GearTier('방 형광등', 0),
    GearTier('LED 스탠드', 30000),
    GearTier('링라이트', 180000),
    GearTier('소프트박스 세트', 1500000),
  ]),
  GearType('pc', 'PC', '🖥️', [
    GearTier('없음 (좌식 밥상)', 0),
    GearTier('중고 노트북 + 책상', 450000),
    GearTier('게이밍 PC', 2200000),
    GearTier('듀얼 모니터 방송 세팅', 6000000),
  ]),
];

GearType gearOf(String key) => gearTypes.firstWhere((g) => g.key == key);

// ───── 꾸미기 ─────
class Deco {
  const Deco(this.id, this.name, this.price);
  final String id;
  final String name;
  final int price;
}

/// 하나 살 때마다 방 매력도 +1 (시청자 소폭 증가)
const decos = [
  Deco('rug', '폭신한 러그', 40000),
  Deco('plant', '몬스테라 화분', 30000),
  Deco('poster', '좋아하는 영화 포스터', 15000),
  Deco('neon', '하트 네온사인', 150000),
  Deco('beanbag', '빈백 소파', 200000),
  Deco('figure', '피규어 진열장', 350000),
];

// ───── 집 (이사) ─────
class House {
  const House(this.id, this.name, this.icon, this.minFollowers, this.deposit, this.rent, this.bonus, this.wall, this.desc);
  final String id;
  final String name;
  final String icon;

  /// 이사할 수 있는 구독자 수
  final int minFollowers;

  /// 이사할 때 내는 보증금·이사비
  final int deposit;

  /// 하루 생활비 (월세·식비)
  final int rent;

  /// 시청자 보너스 (방이 좋을수록)
  final double bonus;

  /// 이사 직후 벽 색
  final int wall;
  final String desc;
}

const houses = [
  House('banjiha', '반지하', '🕳️', 0, 0, 7000, 0, 0xA9A69E, '눅눅한 벽, 천장 근처 작은 창. 그래도 내 첫 방송실.'),
  House('oneroom', '원룸', '🏠', 1000, 500000, 10000, 0.05, 0xE9DCCB, '햇빛 드는 창문이 생겼다. 시청자 +5%'),
  House('officetel', '오피스텔', '🏢', 10000, 3000000, 25000, 0.10, 0xF2F2F0, '깔끔한 벽, 큰 창 너머 도시 풍경. 시청자 +10%'),
  House('apartment', '아파트', '🏘️', 100000, 15000000, 60000, 0.15, 0xEFE6D6, '몰딩 벽과 헤링본 바닥. 시청자 +15%'),
  House('penthouse', '펜트하우스', '🌆', 500000, 80000000, 150000, 0.25, 0x22252E, '통유리 너머 야경. 성공한 방송인의 상징. 시청자 +25%'),
];

House houseOf(String id) => houses.firstWhere((h) => h.id == id, orElse: () => houses.first);

const snsMoving = ['{name} 이사했네?? 방 미쳤다', '{name} 새 집 투어 해주세요', '{name} 성공했구나 ㅠㅠ 감동', '{name} 이사 축하해요!!', '{name} 방송 배경 달라져서 깜짝 놀람'];

// ───── 라이벌 스트리머 (인기 순위) ─────
class Rival {
  const Rival(this.id, this.name, this.icon, this.start, this.growth);
  final String id;
  final String name;

  /// 주력 콘텐츠
  final String icon;

  /// 시즌 시작 때 구독자
  final int start;

  /// 하루 평균 성장률
  final double growth;
}

const rivals = [
  Rival('sua', '새벽감성 수아', '🎤', 120, 0.06),
  Rival('tori', '고양이집사 토리', '🐱', 900, 0.05),
  Rival('gombear', '롤하는 곰돌이', '🎮', 4000, 0.045),
  Rival('minji', '공부하는 민지', '📚', 15000, 0.035),
  Rival('mukbo', '먹보대장', '🍜', 60000, 0.03),
  Rival('jjin', '찐텐형', '💬', 300000, 0.02),
  Rival('minsu', '갓겜민수', '🎮', 800000, 0.015),
  Rival('hana', '대식가 하나', '🍜', 1200000, 0.012),
  Rival('kimpd', '레전드 김피디', '🎬', 2500000, 0.008),
];

const snsOvertake = ['{name}, {rival} 제쳤다 ㄷㄷ', '{name} 순위 실화냐 {rival}보다 위네', '{rival} 팬인데 {name}도 보러 감 ㅋㅋ', '{name} 요즘 상승세 미쳤다'];

// ───── 직원 ─────
class Staff {
  const Staff(this.id, this.name, this.icon, this.minFollowers, this.wage, this.desc);
  final String id;
  final String name;
  final String icon;

  /// 고용할 수 있는 구독자 수
  final int minFollowers;

  /// 하루 일당 (매일 밤 나간다)
  final int wage;
  final String desc;
}

const staffList = [
  Staff('editor', '편집자', '✂️', 5000, 30000, '매일 밤 하이라이트 영상을 편집해서 올려 준다. 구독자와 광고 수익이 들어온다.'),
  Staff('manager', '매니저', '🧑‍💼', 30000, 80000, '방송 체력 소모 -20%. 일정과 논란 대응을 맡아 매일 논란 -3, 멘탈 +2. 가끔 광고 건을 따 온다.'),
];

Staff staffOf(String id) => staffList.firstWhere((x) => x.id == id);

// ───── 알바 ─────
class Workplace {
  const Workplace(this.name, this.icon, this.pay, this.texts);
  final String name;
  final String icon;

  /// 한 번 일하면 받는 돈 (밤에는 1.2배)
  final int pay;
  final List<String> texts;
}

/// 잘리면 다음 알바로 넘어간다
const workplaces = [
  Workplace('편의점', '🏪', 60000, ['폐기 삼각김밥이 오늘의 저녁.', '진상 손님에게 시달렸다.', '손님이 "혹시 방송하시는 분?"이라고 물었다… 착각이었다.', '물건 정리하며 다음 방송 아이디어를 떠올렸다.']),
  Workplace('카페', '☕', 65000, ['라테 아트 하트가 오늘은 잘 나왔다.', '단체 주문 20잔에 정신이 없었다.', '단골손님이 쿠키를 나눠 줬다.']),
  Workplace('PC방', '🖥️', 62000, ['라면 주문이 끝없이 들어왔다.', '손님 자리 청소하다가 게임 공략을 배웠다.', '밤샘 손님들과 묘한 동지애가 생겼다.']),
];

const snsWorkVlog = ['{name} 알바 브이로그 너무 웃김 ㅋㅋㅋ', '알바하면서 방송 준비하는 거 리스펙', '{name} 알바복 잘 어울린다', '진상 손님 썰 레전드 ㅋㅋ', '{name} 현실 브이로그라 더 정감 감'];

const snsFired = SnsTopic(
  tag: '{name}_알바잘림',
  headline: '{name}, 알바 브이로그 찍다가 결국 잘려… 해고 순간 클립 화제',
  tone: 0.35,
  hate: ['일하는 데서 촬영하면 당연히 잘리지', '사장님만 불쌍하네', '콘텐츠에 미쳤네 ㅋㅋ'],
  shield: ['잘리는 것까지 콘텐츠 ㅋㅋㅋ 근성 인정', '{name} 힘내요 더 좋은 알바 구할 거예요', '해고 클립 보고 빵 터짐 ㅋㅋㅋ'],
  neutral: ['점장님 표정 짤 돌고 있음', '알바 브이로그 시즌 2 기대'],
);

// ───── 방송 종류 ─────
class Content {
  const Content({
    required this.id,
    required this.name,
    required this.icon,
    required this.energy,
    required this.base,
    required this.desc,
    this.cost = 0,
    this.need = const {},
    this.mic,
    this.pc,
    this.risky = false,
    this.calm = false,
  });

  final String id;
  final String name;
  final String icon;
  final int energy;
  final double base;
  final String desc;
  final int cost;

  /// 필요한 장비 단계
  final Map<String, int> need;

  /// 해당 장비가 화질 점수에 주는 가중치
  final double? mic;
  final double? pc;
  final bool risky;
  final bool calm;
}

const contents = [
  Content(id: 'talk', name: '잡담 방송', icon: '💬', energy: 18, base: 1.0, desc: '부담 없이 수다 떨기. 말빨이 늘수록 재밌어진다.'),
  Content(id: 'study', name: '공부 방송', icon: '📚', energy: 14, base: 0.75, calm: true, desc: '조용히 같이 공부. 수익은 적지만 이미지가 좋아진다.'),
  Content(id: 'mukbang', name: '먹방', icon: '🍜', energy: 24, base: 1.3, cost: 20000, desc: '식비 2만 원. 잘 먹는 것도 재능이다.'),
  Content(id: 'sing', name: '노래 방송', icon: '🎤', energy: 26, base: 1.1, mic: 2.2, desc: '마이크가 좋을수록 빛난다.'),
  Content(id: 'game', name: '게임 방송', icon: '🎮', energy: 22, base: 1.25, need: {'pc': 1}, pc: 1.6, desc: 'PC가 필요하다. 사양이 좋을수록 시청자가 늘어난다.'),
  Content(id: 'react', name: '리액션 방송', icon: '😲', energy: 20, base: 1.15, need: {'pc': 1}, risky: true, desc: '화제성은 높지만 사고도 잦다.'),
  Content(id: 'vlog', name: '일상 브이로그', icon: '🎬', energy: 26, base: 1.2, need: {'camera': 2}, desc: '좋은 카메라가 필요하다. 감성이 곧 조회수.'),
  Content(id: 'asmr', name: 'ASMR', icon: '🎧', energy: 14, base: 1.2, need: {'mic': 2}, mic: 2.5, calm: true, desc: '콘덴서 마이크 이상이 필요하다.'),
  Content(id: 'pet', name: '펫 방송', icon: '🐾', energy: 16, base: 1.35, calm: true, desc: '반려동물과 함께하는 힐링 방송. 반려동물이 있어야 한다.'),
];

Content contentOf(String id) => contents.firstWhere((c) => c.id == id, orElse: () => contents.first);

// ───── 등급과 기념일 ─────
class Rank {
  const Rank(this.min, this.name);
  final int min;
  final String name;
}

const ranks = [
  Rank(0, '방구석 방송인'),
  Rank(100, '새싹 스트리머'),
  Rank(1000, '떠오르는 스트리머'),
  Rank(10000, '중소 스트리머'),
  Rank(100000, '인기 스트리머'),
  Rank(500000, '대형 스트리머'),
  Rank(1000000, '레전드 스트리머'),
];

class Milestone {
  const Milestone(this.at, this.title, this.text);
  final int at;
  final String title;
  final String text;
}

const milestones = [
  Milestone(100, '구독자 100명!', '드디어 세 자릿수. 고정 시청자 닉네임을 외우기 시작했다.'),
  Milestone(1000, '수익화 달성!', '구독자 1,000명. 이제 방송마다 광고 수익이 들어온다.'),
  Milestone(10000, '실버 버튼 도착!', '구독자 1만 명. 택배로 온 실버 버튼을 선반에 올려두었다.'),
  Milestone(100000, '골드 버튼 도착!', '구독자 10만 명. 길에서 알아보는 사람이 생겼다.'),
  Milestone(1000000, '다이아 버튼 도착!', '구독자 100만 명. 이제 당신은 명실상부 레전드 스트리머다.'),
];

// ───── 방송 중 채팅 ─────
const chatLines = <String, List<String>>{
  'any': ['ㅋㅋㅋㅋㅋ', '하이요~', 'ㅎㅇㅎㅇ', '오늘 텐션 좋네', '첫 방문입니다!', '{name} 왔다', 'ㄹㅇㅋㅋ', '아 개웃겨', '출첵', 'ㅇㅈ', '와 진짜?', '😂😂😂', '👍', '구독 박고 갑니다', '알림 보고 옴'],
  'talk': ['썰 더 풀어줘요', '그래서 그 다음엔?', '목소리 좋다', '공감 100%'],
  'study': ['오늘도 같이 공부해요', '📖', '집중!', '저 시험 3일 남음...'],
  'pet': ['귀여워 ㅠㅠㅠ', '애기 이름 뭐예요?', '심장 아파 너무 귀엽다', '간식 사 주세요 후원함', '얼굴 보여 줘요!!', '랜선 집사 왔습니다'],
  'mukbang': ['와 한입 크기 뭐야', '저거 어디 거예요?', '배고프다...', '소리 미쳤다'],
  'sing': ['고음 미쳤다', '앵콜!!', '소름 돋았어요', '신청곡 받나요?'],
  'game': ['오른쪽!!', '아 그걸 왜 ㅋㅋ', '고수다', '보스 피 얼마 안 남음'],
  'react': ['리액션 장인', '아 이거 봤는데 ㅋㅋ', '표정 ㅋㅋㅋㅋ', '다음 영상 고고'],
  'vlog': ['브금 뭐예요?', '감성 미쳤다', '방 예쁘다', '편집 장인'],
  'asmr': ['팅글 온다...', '자기 전에 틀어놔요', '소리 너무 좋다', '💤'],
  'lowcam': ['화질 무슨 감자임?', '얼굴이 모자이크 같아요', '화질 좀...'],
  'lowmic': ['소리 지직거려요', '마이크 너무 웅웅거림', '소리 작아요'],
  'dark': ['얼굴이 너무 어두워요', '조명 좀 켜주세요'],
};

/// 방송 중 후원 메시지
const donationMsgs = ['오늘 텐션 미쳤다', '치킨 사 드세요 ㅋㅋ', '첫 후원입니다!', '목소리 너무 좋아요', '맨날 보러 올게요', '이거 보고 힘내요', '노래 한 곡만!', '장비 바꾸는 데 보태세요', '퇴근길에 보는 낙', '사랑해요 ❤'];

// ───── SNS 공통 문구 ─────
const snsPool = <String, List<String>>{
  'hate': [
    '솔직히 {name} 거품 맞음',
    '이걸 쉴드치는 사람들 이해 안 감',
    '{name} 원래 이런 사람이었음. 몰랐음?',
    '구독 취소 박고 갑니다 ㅂㅂ',
    '인성 나오네 ㅋㅋ',
    '요즘 {name} 좀 변한 듯',
    '관심 끌려고 별짓을 다 하네',
    '이래서 방송인은 뜨면 안 됨',
  ],
  'shield': [
    '이게 이렇게까지 욕먹을 일인가?',
    '{name} 방송 꾸준히 보면 그런 사람 아닌 거 앎',
    '앞뒤 맥락 다 자르고 퍼오지 마세요',
    '악플 다는 사람들 방송 한 번도 안 봤을 듯',
    '{name} 힘내요 ㅠㅠ 항상 응원함',
    '사람이 실수할 수도 있지',
    '꼬투리 잡을 거 찾는 사람들 피곤하다',
  ],
  'neutral': [
    '{name}이 누군데 트렌드에 있음?',
    '양쪽 다 일리는 있는 듯',
    '팝콘 각 🍿',
    '이거 원본 클립 어디서 봄?',
    '타임라인 {name} 얘기밖에 없네',
    '일단 지켜봅시다',
  ],
};

/// 방송만 하고 이벤트가 없을 때 피드에 올라오는 글
const snsStream = <String, List<String>>{
  'talk': ['{name} 잡담 방송 듣다가 잠듦 ㅋㅋ 목소리 ASMR급', '오늘도 {name} 썰 미쳤다', '{name} 토크 들으면 하루 피로가 풀림'],
  'study': ['{name} 공부방송 틀어놓고 3시간 공부함. 효과 ㄹㅇ', '{name} 공방 보면서 자격증 땄다 고마워요', '공부방송인데 왜 이렇게 힐링되지'],
  'mukbang': ['{name} 먹방 보다가 야식 시킴. 책임져라', '{name} 한입 크기 실화냐', '{name} 먹는 소리 중독됨'],
  'sing': ['{name} 노래 원곡보다 좋은 듯', '{name} 오늘 고음 소름 돋음', '음정 살짝 나갔는데 그것도 귀여움'],
  'game': ['{name} 겜 실력 실화냐 ㅋㅋㅋ', '{name} 보스전 30트째 보는 중', '{name} 샷 클립 따놨다'],
  'react': ['{name} 리액션 보려고 영상 다시 봄', '{name} 표정 짤 저장함 ㅋㅋ', '리액션 장인 인정'],
  'vlog': ['{name} 브이로그 감성 미쳤다', '{name} 방 꾸민 거 너무 예쁨', '{name} 일상 보면서 대리만족 중'],
  'asmr': ['{name} ASMR 틀자마자 기절함', '불면증 있는데 {name} 덕에 잠', '{name} 팅글 장인'],
  'lowcam': ['{name} 방송 재밌는데 화질이 너무 아쉬움', '{name} 캠 좀 바꿨으면 ㅠ 얼굴이 안 보임'],
  'lowmic': ['{name} 마이크 바꾸면 진짜 뜰 듯', '{name} 방송 소리가 너무 웅웅거려서 못 보겠음'],
  'dark': ['{name} 조명만 사면 완벽할 듯', '{name} 방 너무 어두움 ㅋㅋ 동굴 방송'],
  'flop': ['{name} 오늘 방송 좀 노잼이었다', '{name} 컨디션 안 좋아 보이던데'],
  'viral': ['알고리즘이 {name} 띄워줌 ㅋㅋ', '{name} 클립 조회수 터졌네', '갑자기 {name} 영상이 추천에 계속 뜸', '{name} 떡상 축하합니다!!'],
};

const snsMilestone = <int, List<String>>{
  100: ['{name} 구독자 100명 축하해요! 1호팬입니다', '{name} 처음부터 봤는데 벌써 100명이라니 ㅠ'],
  1000: ['{name} 수익화 축하!! 이제 장비 바꾸자', '{name} 1천 명 축하해요 🎉', '고인물 인증합니다. {name} 100명일 때부터 봄'],
  10000: ['{name} 실버 버튼 축하합니다!!', '{name} 1만이라니... 내가 키웠다', '{name} 요즘 진짜 잘 나가네'],
  100000: ['{name} 골드 버튼 ㄷㄷ', '{name} 10만 축하! 초심 잃지 마요', '{name} 길에서 봤는데 실물 미쳤음'],
  1000000: ['{name} 100만 실화냐', '{name} 다이아 버튼 축하해요 ㅠㅠㅠ', '{name} 방구석 시절부터 봤다고 자랑 중'],
};

/// 성별마다 다른 말투. {sib}은 부르는 말로 바뀐다.
/// (남자 팬 → 형/누나, 여자 팬 → 오빠/언니)
const snsGendered = <String, Map<String, List<String>>>{
  'shield': {
    'm': ['{sib} 기죽지 마라 ㄹㅇ', '우리 {sib} 건드리지 마라', '{sib} 방송 10년 더 본다', '{sib} 이 정도로 안 무너짐 ㅇㅇ'],
    'f': ['{sib} 힘내요ㅠㅠ 항상 응원해요', '{sib} 상처받지 마요 ㅠㅠ', '우리 {sib} 꽃길만 걷자', '{sib} 악플 보지 마요 ㅠㅠ'],
  },
  'hate': {
    'm': ['{sib} 이번엔 좀 실망이다', '{sib} 초심 어디 감?', '{sib} 이러면 나도 못 쉴드침'],
    'f': ['{sib} 이건 아니지…', '{sib} 진짜 실망했어요', '{sib} 믿었는데 ㅠ'],
  },
  'fan': {
    'm': ['{sib} 오늘 방송 레전드', '{sib} 폼 미쳤다', '{sib} 클립 따놨다 ㅋㅋ'],
    'f': ['{sib} 오늘도 귀여웠다 ㅠㅠ', '{sib} 목소리 듣고 힐링함', '{sib} 웃는 거 보고 하루 버팀'],
  },
};

/// 팬이 방송인을 부르는 말
String sibling(String fanGender, String streamerGender) =>
    fanGender == 'm' ? (streamerGender == 'm' ? '형' : '누나') : (streamerGender == 'm' ? '오빠' : '언니');

// ───── 방송 중 말실수 (드물게) ─────
class Gaffe {
  const Gaffe(this.text, this.quote);

  /// 무슨 일이 있었는지
  final String text;

  /// SNS에 박제되는 말
  final String quote;
}

const gaffes = [
  Gaffe('채팅이 느리게 올라오자 무심코 말해 버렸다.', '"아 오늘 시청자들 왜 이렇게 노잼이야"'),
  Gaffe('경쟁 스트리머 얘기가 나오자 비꼬는 말이 튀어나왔다.', '"걔는 솔직히 얼굴로 뜬 거잖아ㅋㅋ"'),
  Gaffe('게임에서 어이없이 지는 바람에 욕설이 튀어나왔다.', '"아 ×× 이게 말이 돼?"'),
  Gaffe('후원 메시지를 읽다가 후원자를 놀리는 말을 해 버렸다.', '"이 정도 후원으로 뭘 바라세요ㅋㅋ"'),
  Gaffe('지역 이야기를 하다가 선을 넘는 농담을 했다.', '"거기 사는 사람들은 원래 좀…ㅋㅋ"'),
];

/// 말실수 직후 채팅
const chatGaffe = ['??', '방금 뭐라고 함?', '와 선 넘네', '클립 땄다', '사과 안 함?', '언팔합니다', '실망이다 진짜', 'ㅋㅋㅋ 이게 맞냐', '박제 완료'];

/// 사과 방송 중 채팅
const chatApology = ['사과 받아요', '다음부터 조심해요', '진정성 있네', '울지 마요 ㅠㅠ', '사과문 읽는 거 아님?', '이미 늦었음', '힘내세요', '그래도 사과는 하네'];

/// 사과 없이 강행했을 때 SNS
const snsGaffeIgnore = SnsTopic(
  tag: '{name}_사과해',
  headline: '{name}, 생방송 중 막말… 사과 없이 방송 강행',
  tone: -0.45,
  hate: ['사과 한마디가 그렇게 어렵나', '{name} 인성 드디어 드러남', '이거 그냥 넘어가면 안 됨', '박제해 둠. 나중에 딴말하기 없기', '언팔하고 왔다'],
  shield: ['방송하다 보면 말실수할 수도 있지', '맥락 보면 그렇게 심한 말 아님', '불편러들 또 몰려왔네', '{name}은 원래 저런 캐릭터임'],
  neutral: ['원본 클립 어디서 봄?', '사과 방송 할까 안 할까', '팝콘 각 🍿'],
);

/// 사과 방송을 했을 때 SNS
const snsGaffeApology = SnsTopic(
  tag: '{name}_사과방송',
  headline: '{name}, 말실수 직후 방송 중단하고 사과',
  tone: 0.3,
  hate: ['크로마키 깔고 사과하는 거 웃기네 ㅋㅋ', '사과하면 다 끝남?', '사과문 대본 티 남', '이미 한 말은 주워 담을 수 없음'],
  shield: ['바로 사과한 건 인정', '사과까지 했는데 그만 까자', '진정성 느껴졌음', '실수 인정하는 게 쉬운 일 아님'],
  neutral: ['크로마키 사과 방송 밈 되겠다', '사과 방송 시청자 더 많았다던데'],
);

// ───── SNS 대응 (내 계정으로) ─────
const myExplain = ['해명드립니다. 오해가 생긴 부분에 대해 솔직하게 말씀드릴게요.', '제 입장을 정리해서 올립니다. 끝까지 읽어 주세요.', '많은 분들이 걱정해 주셔서 직접 설명드리려 합니다.'];
const mySue = ['도를 넘은 악성 댓글과 허위 사실 유포에 대해 법적 대응을 시작합니다.', '선처 없습니다. 악플 자료 모두 수집해 고소 진행합니다.'];
const myPin = ['이 댓글 보고 힘냈어요. 고마워요 ❤', '늘 응원해 주셔서 감사합니다 ❤'];

const snsExplainOk = SnsTopic(tag: '', headline: '', tone: 0.6, shield: ['해명 깔끔하네', '이제 오해 풀렸다', '역시 {name}', '이 정도면 충분히 설명했음'], hate: ['그래도 좀 찝찝함', '해명이 길다'], neutral: ['해명문 정독함']);
const snsExplainBad = SnsTopic(tag: '', headline: '', tone: -0.6, hate: ['해명이 아니라 변명이네', '불난 데 기름 붓기', '가만히 있었으면 중간이라도 가지', '읽을수록 더 별로'], shield: ['그래도 입장 밝힌 건 용기임', '말꼬리 잡지 마요'], neutral: ['해명문 박제됨']);
const snsSue = SnsTopic(tag: '', headline: '', tone: 0.2, shield: ['고소 잘했다', '악플러들 이제 조용해지겠네', '선처 없이 가자'], hate: ['고소는 좀 과한 듯', '비판도 악플 취급하네', '입막음 아님?'], neutral: ['고소 공지 떴다 ㄷㄷ']);

/// 자숙을 마치고 복귀할 때 SNS
const snsComeback = SnsTopic(
  tag: '{name}_복귀',
  headline: '{name}, 3주 자숙 끝내고 복귀 방송',
  tone: 0.25,
  hate: ['벌써 복귀?', '자숙이 아니라 휴가였네', '반성한 거 맞음?'],
  shield: ['기다렸어요 ㅠㅠ', '반성했으면 됐지', '복귀 축하해요!!', '이제 실수하지 말자'],
  neutral: ['복귀 방송 시청자 몇 명이었음?', '자숙 3주면 적당한 듯'],
);

/// 구독자에 따라 돈 단위가 커지도록
int scaleMoney(GameState s, int base) => ((base * pow(1 + s.followers / 4000, 0.55)) / 1000).round() * 1000;

String won(int n) => '${_comma(n.abs())}원';

String _comma(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ───── 이벤트 ─────

/// 선택 결과로 바뀌는 수치. followers는 현재 구독자 대비 비율.
class Fx {
  const Fx({this.money = 0, this.followers = 0, this.image = 0, this.heat = 0, this.mental = 0, this.energy = 0, this.flag, this.unflag, this.quit});
  final int money;
  final double followers;
  final int image;
  final int heat;
  final int mental;
  final int energy;
  final String? flag;
  final String? unflag;

  /// 그만두는 직원 id
  final String? quit;
}

/// SNS 반응. tone은 -1(악플 위주) ~ 1(쉴드 위주)
class SnsTopic {
  const SnsTopic({required this.tag, required this.headline, required this.tone, this.hate = const [], this.shield = const [], this.neutral = const [], this.oppositeTone = 0});
  final String tag;
  final String headline;
  final double tone;

  /// 방송인과 성별이 다른 팬에게 더해지는 tone (열애설처럼 이성 팬이 더 민감한 주제는 음수)
  final double oppositeTone;
  final List<String> hate;
  final List<String> shield;
  final List<String> neutral;

  List<String> lines(String side) => switch (side) {
        'hate' => hate,
        'shield' => shield,
        _ => neutral,
      };
}

class EventChoice {
  const EventChoice({required this.label, required this.result, required this.fx, this.sns, this.chance, this.lose});
  final String label;
  final String result;
  final Fx Function(GameState s) fx;
  final SnsTopic? sns;

  /// 결과가 운에 달린 선택지: 성공 확률. 실패하면 [lose]가 대신 일어난다
  final double Function(GameState s)? chance;
  final EventChoice? lose;
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.where,
    required this.title,
    required this.weight,
    required this.when,
    required this.text,
    required this.choices,
  });

  final String id;

  /// 'live'(방송 중), 'news'(아침에 터지는 소식), 'rank'(순위 상위권일 때 아침 소식),
  /// 'crisis'(유명해질수록 자주 오는 위기)
  final String where;
  final String title;
  final int weight;
  final bool Function(GameState s) when;
  final String Function(GameState s) text;
  final List<EventChoice> choices;
}

Fx _none(GameState s) => const Fx();

/// 어젯밤 기준 내 인기 순위 (아직 없으면 99)
int rankNow(GameState s) => s.lastRanks['me'] ?? 99;

/// 이만큼 구독자가 생기면 전업 방송인: 알바를 그만둔다
const proFollowers = 10000;

const snsParentShop = SnsTopic(
  tag: '{name}_부모님가게',
  headline: '{name} 부모님 치킨집, 팬들 성지 순례 코스 등극',
  tone: 0.6,
  hate: ['가족 장사 시작이네', '방송으로 가게 홍보는 좀…', '팬들 지갑 털기'],
  shield: ['효자/효녀 인정', '치킨 맛있더라 진짜', '부모님 너무 친절하심', '이런 홍보는 환영'],
  neutral: ['가게 위치 어디임?', '주말엔 줄 서야 한대'],
);

/// 평소 평판이 좋을수록 높아지는 확률 (이미지 -100 ~ 100 → base ± 0.25)
double byImage(GameState s, double base) => (base + s.image / 400).clamp(0.15, 0.9);

/// 갑질 고소를 한 직원 (편집자가 있으면 편집자)
String accuser(GameState s) => s.staff.contains('editor') ? 'editor' : 'manager';

final gameEvents = <GameEvent>[
  GameEvent(
    id: 'hater',
    where: 'live',
    title: '악플러 등장',
    weight: 4,
    when: (s) => s.followers >= 20,
    text: (s) => '채팅창에 "{name} 방송 왜 봄? 노잼인데 ㅋ" 라는 채팅이 계속 올라온다.',
    choices: [
      EventChoice(
        label: '웃으며 받아친다',
        result: '"노잼인데 끝까지 보고 계시네요? 고정 시청자 감사합니다~" 채팅창이 ㅋㅋㅋ로 뒤덮였다.',
        fx: (s) => const Fx(image: 5, followers: 0.04),
        sns: const SnsTopic(
          tag: '{name}_사이다',
          headline: '{name}, 악플러에게 웃으며 받아쳐 화제',
          tone: 0.6,
          hate: ['받아치는 거 좀 비꼬는 느낌이던데', '저걸 사이다라고 하는 게 웃김'],
          shield: ['{name} 멘탈 갑 ㅋㅋㅋ 저게 정답임', '악플러 참교육 레전드', '저렇게 웃으면서 받아치기 쉽지 않음'],
          neutral: ['그 클립 벌써 조회수 터짐'],
        ),
      ),
      EventChoice(
        label: '정색하고 강퇴한다',
        result: '"그런 채팅은 사양할게요." 분위기가 잠시 싸해졌다.',
        fx: (s) => const Fx(image: -1, heat: 6, mental: -3),
        sns: const SnsTopic(
          tag: '{name}_정색',
          headline: '{name}, 방송 중 시청자 강퇴하며 정색',
          tone: 0,
          hate: ['시청자를 저렇게 대하네', '{name} 표정 관리 안 되는 거 처음 봄', '강퇴까지 할 일인가'],
          shield: ['악플러 강퇴가 왜 논란임?', '자기 방송에서 자기 규칙 지키는 거지', '저 정도면 참은 거임'],
          neutral: ['정색 클립 돌고 있던데'],
        ),
      ),
      EventChoice(
        label: '못 본 척 방송을 이어간다',
        result: '아무렇지 않은 척했지만 그 채팅이 계속 머릿속에 맴돈다.',
        fx: (s) => const Fx(mental: -7, image: 1),
      ),
    ],
  ),
  GameEvent(
    id: 'spicy',
    where: 'live',
    title: '도네이션 미션',
    weight: 3,
    when: (s) => s.followers >= 50,
    text: (s) => '큰손 시청자가 후원 메시지를 보냈다. "매운 라면 5봉 먹으면 ${won(scaleMoney(s, 150000))} 쏩니다 ㅋㅋ"',
    choices: [
      EventChoice(
        label: '도전한다!',
        result: '눈물 콧물 다 쏟으며 5봉을 비웠다. 후원이 쏟아졌지만 배가 너무 아프다.',
        fx: (s) => Fx(money: scaleMoney(s, 150000), followers: 0.05, energy: -15, mental: -4, heat: 3),
        sns: const SnsTopic(
          tag: '{name}_매운라면',
          headline: '{name}, 후원 미션으로 매운 라면 5봉 완식',
          tone: 0.2,
          hate: ['돈 받고 건강 파는 방송 보기 불편함', '저런 미션 받아주니까 시청자들이 계속 시키지', '자극적인 것만 찾네'],
          shield: ['본인이 하겠다는데 뭐 어때', '{name} 근성 미쳤다 ㅋㅋㅋ', '얼굴 빨개진 거 귀여웠음'],
          neutral: ['다음 날 화장실 썰 기대함', '보는 내가 다 맵다'],
        ),
      ),
      EventChoice(
        label: '건강이 먼저라며 거절한다',
        result: '"마음만 받을게요! 대신 다음에 맛있는 거 먹을 때 같이 봐요." 시청자들이 박수를 보냈다.',
        fx: (s) => const Fx(image: 4, mental: 2),
        sns: const SnsTopic(
          tag: '{name}_소신',
          headline: '{name}, 고액 후원 미션 거절',
          tone: 0.6,
          hate: ['돈 주는데 거절하는 척은 ㅋㅋ', '재미 없게 왜 거절함'],
          shield: ['자극 방송 안 하는 게 {name} 매력', '이런 방송인이 오래 감', '거절도 기분 안 나쁘게 하네'],
          neutral: ['후원자 머쓱하겠다 ㅋㅋ'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'diet_ad',
    where: 'live',
    title: '수상한 광고 제안',
    weight: 3,
    when: (s) => s.followers >= 300 && !s.flags.contains('hiddenAd'),
    text: (s) => '방송 중 DM이 왔다. "저희 다이어트 젤리 소개해주시면 ${won(scaleMoney(s, 300000))} 드려요. 광고 표시는 안 하셔도 됩니다^^"',
    choices: [
      EventChoice(
        label: "'유료 광고'를 표시하고 소개한다",
        result: "화면 구석에 '유료 광고 포함'을 띄우고 젤리를 소개했다.",
        fx: (s) => Fx(money: scaleMoney(s, 300000), image: -2),
        sns: const SnsTopic(
          tag: '{name}_광고',
          headline: '{name}, 다이어트 젤리 유료 광고 진행',
          tone: 0.1,
          hate: ['광고충 됐네 ㅋㅋ', '저 젤리 효과 없다던데', '{name}도 결국 돈인가'],
          shield: ['광고 표시 제대로 했으면 된 거 아님?', '방송인도 먹고 살아야지', '투명하게 해서 오히려 좋음'],
          neutral: ['젤리 맛은 궁금하다'],
        ),
      ),
      EventChoice(
        label: "광고 표시 없이 '내돈내산'인 척한다",
        result: '"요즘 제가 진짜 먹는 건데요~" 돈은 더 받았지만 마음 한구석이 찜찜하다.',
        fx: (s) => Fx(money: scaleMoney(s, 480000), flag: 'hiddenAd'),
        sns: const SnsTopic(
          tag: '{name}_추천템',
          headline: '{name}이 먹는 다이어트 젤리 품절 대란',
          tone: 0.7,
          hate: ['갑자기 젤리 홍보? 냄새나는데', '이거 광고 아님?'],
          shield: ['{name}이 쓰는 거면 믿고 삼', '내돈내산 추천이라 더 믿음감', '벌써 주문함 ㅋㅋ'],
          neutral: ['그 젤리 어디서 팔아요?'],
        ),
      ),
      EventChoice(
        label: '거절한다',
        result: '"검증 안 된 제품은 소개 안 해요." 시청자들이 엄지를 올렸다.',
        fx: (s) => const Fx(image: 5),
        sns: const SnsTopic(
          tag: '{name}_클린',
          headline: '{name}, 뒷광고 제안 공개 거절',
          tone: 0.7,
          hate: ['거절했다고 굳이 말하는 거 이미지 메이킹 아님?'],
          shield: ['뒷광고 판치는데 {name}은 클린하다', '이런 방송인 믿고 봄', '광고주가 누군지 궁금하네 ㄷㄷ'],
          neutral: ['요즘 저런 DM 많이 온대'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'doxx',
    where: 'live',
    title: '방송 사고',
    weight: 2,
    when: (s) => s.followers >= 100,
    text: (s) => '방송 화면에 택배 상자가 잡혔다. 송장에 주소가 그대로 보인다!',
    choices: [
      EventChoice(
        label: '바로 가리고 퍼가지 말아 달라고 부탁한다',
        result: '급히 상자를 치우고 다시보기도 잘라냈다. 시청자들이 오히려 걱정해 줬다.',
        fx: (s) => const Fx(mental: -4, image: 2),
        sns: const SnsTopic(
          tag: '{name}_주소노출',
          headline: '{name}, 방송 중 택배 송장 노출… 빠르게 대처',
          tone: 0.5,
          hate: ['저런 기본적인 실수를 함?', '이미 캡처한 사람 있을 듯'],
          shield: ['캡처 돌리는 사람 신고합시다', '{name} 대처 빨랐음 다행', '다들 퍼가지 맙시다 진짜'],
          neutral: ['방송인들 택배 진짜 조심해야 함'],
        ),
      ),
      EventChoice(
        label: '별일 아니라며 넘어간다',
        result: '그냥 넘어갔다. 방송이 끝난 뒤, 모르는 번호로 문자가 오기 시작했다.',
        fx: (s) => const Fx(mental: -15, heat: 6),
        sns: const SnsTopic(
          tag: '{name}_주소',
          headline: '{name} 주소 캡처 커뮤니티에 확산',
          tone: -0.2,
          hate: ['본인이 공개했는데 뭐 ㅋㅋ', '관종이라 일부러 보여준 거 아님?'],
          shield: ['주소 퍼나르는 사람들 이거 범죄예요', '{name} 괜찮은 거 맞나 걱정됨', '제발 캡처 지워주세요'],
          neutral: ['이거 신고해야 하는 거 아님?'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'collab',
    where: 'live',
    title: '합방 제안',
    weight: 3,
    when: (s) => s.followers >= 500,
    text: (s) => '구독자 30만의 대형 스트리머 "찐텐형"이 채팅창에 나타났다. "{name}님 다음 주에 합방 한번 하실래요?"',
    choices: [
      EventChoice(
        label: '좋아요! 수락한다',
        result: '합방은 대성공. 찐텐형의 시청자들이 우르르 넘어왔다.',
        fx: (s) => const Fx(followers: 0.12, energy: -10, image: 2),
        sns: const SnsTopic(
          tag: '찐텐형X{name}',
          headline: '찐텐형×{name} 합방, 케미 폭발',
          tone: 0.6,
          hate: ['{name} 찐텐형 등에 업혀가네', '합방으로 떡상하려는 거 티남'],
          shield: ['둘이 케미 미쳤다 고정 합방 해줘', '찐텐형이 먼저 제안한 거임 ㅇㅇ', '{name} 원래 재밌는 사람이었음'],
          neutral: ['다음 합방 언제임?'],
        ),
      ),
      EventChoice(
        label: '아직 실력이 부족하다며 정중히 거절한다',
        result: '정중히 거절했다. 일부 시청자는 아쉬워했다.',
        fx: (s) => const Fx(image: -1, mental: 3),
        sns: const SnsTopic(
          tag: '{name}_합방거절',
          headline: '{name}, 찐텐형 합방 제안 거절',
          tone: -0.1,
          hate: ['대형 스트리머 제안을 거절? 건방지네', '기회를 걷어차네 ㅋㅋ'],
          shield: ['본인 페이스대로 가는 거 좋음', '거절도 정중하게 했던데', '합방 안 해도 {name}은 뜸'],
          neutral: ['찐텐형 반응 궁금하다'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'politics',
    where: 'live',
    title: '민감한 질문',
    weight: 2,
    when: (s) => s.followers >= 2000,
    text: (s) => '채팅창에 질문이 올라왔다. "{name}님 이번 선거 누구 뽑으셨어요? 솔직하게 ㄱㄱ"',
    choices: [
      EventChoice(
        label: '소신껏 대답한다',
        result: '솔직하게 대답하자 채팅창이 둘로 갈라졌다. 채팅 속도가 평소의 다섯 배다.',
        fx: (s) => const Fx(followers: 0.03, heat: 28, image: -8, mental: -6),
        sns: const SnsTopic(
          tag: '{name}_정치발언',
          headline: '{name}, 생방송 중 정치 성향 발언 파문',
          tone: -0.3,
          hate: ['방송인이 정치 얘기를 왜 함', '{name} 이제 안 봄', '선 넘었네', '이런 사람이었구나 실망'],
          shield: ['물어봐서 대답한 게 죄임?', '소신 있는 게 뭐가 문제', '질문한 사람이 판 깐 거잖아'],
          neutral: ['정치 얘기는 어디서든 싸움 남', '댓글창 전쟁터네'],
        ),
      ),
      EventChoice(
        label: '웃으며 넘긴다',
        result: '"비밀투표의 원칙! 다음 질문 받을게요~" 무난하게 넘어갔다.',
        fx: (s) => const Fx(image: 1),
        sns: const SnsTopic(
          tag: '{name}_비밀투표',
          headline: '{name}, 정치 질문 센스 있게 회피',
          tone: 0.4,
          hate: ['답 회피하는 거 비겁함'],
          shield: ['저게 정답이지', '센스 좋네 ㅋㅋ', '방송인은 저래야 함'],
          neutral: ['질문한 사람 의도가 뻔했음'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'wrong_donation',
    where: 'live',
    title: '실수 후원',
    weight: 2,
    when: (s) => s.followers >= 200,
    text: (s) => '${won(scaleMoney(s, 1000000))} 후원이 들어왔다! 잠시 후 DM이 온다. "제발요… 0을 하나 더 눌렀어요. 등록금인데 환불 가능할까요?"',
    choices: [
      EventChoice(
        label: '전액 환불해 준다',
        result: '바로 환불했다. 후원자는 울면서 고맙다는 메시지를 보냈다.',
        fx: (s) => const Fx(image: 12, followers: 0.03, mental: 4),
        sns: const SnsTopic(
          tag: '{name}_인성',
          headline: "{name}, 실수 후원 전액 환불 '훈훈'",
          tone: 0.85,
          hate: ['당연한 걸 미담으로 만드네', '환불 안 해주면 그게 이상한 거임'],
          shield: ['{name} 인성 미쳤다', '이래서 {name} 봄', '요즘 같은 세상에 감동이다 ㅠ', '이게 진짜 방송인'],
          neutral: ['후원자분 다행이다'],
        ),
      ),
      EventChoice(
        label: '못 본 척한다',
        result: 'DM을 읽지 않은 척했다. 다음 날 커뮤니티에 캡처가 올라왔다.',
        fx: (s) => Fx(money: scaleMoney(s, 1000000), heat: 25, image: -18, mental: -5),
        sns: const SnsTopic(
          tag: '{name}_먹튀',
          headline: "{name}, 대학생 등록금 실수 후원 '읽씹' 논란",
          tone: -0.8,
          hate: ['이건 진짜 선 넘었다', '등록금을 꿀꺽? ㅋㅋㅋ', '{name} 손절합니다', '인성 바닥이네'],
          shield: ['후원은 원래 환불 안 되는 거 아님?', '본인이 실수한 거잖아', 'DM 못 봤을 수도 있지'],
          neutral: ['플랫폼에서 환불 처리 안 해주나?'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'charity',
    where: 'live',
    title: '기부 방송 제안',
    weight: 2,
    when: (s) => s.followers >= 1000,
    text: (s) => '시청자들이 제안했다. "연말인데 오늘 수익 기부 방송 어때요?"',
    choices: [
      EventChoice(
        label: '오늘 수익 전액을 기부한다',
        result: '방송 수익 전액을 보육원에 기부했다. 마음이 따뜻해진다.',
        fx: (s) => Fx(money: -scaleMoney(s, 200000), image: 14, mental: 8),
        sns: const SnsTopic(
          tag: '{name}_기부',
          headline: '{name}, 방송 수익 전액 기부',
          tone: 0.6,
          hate: ['기부도 콘텐츠로 쓰네', '보여주기식 기부 아님?', '조용히 하면 될 걸'],
          shield: ['보여주기면 어때 기부는 기부지', '{name} 덕분에 나도 기부함', '까는 사람들은 얼마 기부함?'],
          neutral: ['어디에 기부했는지 궁금'],
        ),
      ),
      const EventChoice(
        label: '다음에 하자고 넘긴다',
        result: '"다음에 제대로 준비해서 할게요!" 아무 일도 일어나지 않았다.',
        fx: _none,
      ),
    ],
  ),
  GameEvent(
    id: 'review',
    where: 'live',
    title: '협찬 게임 리뷰',
    weight: 2,
    when: (s) => s.followers >= 800 && s.gear['pc']! >= 1,
    text: (s) => '협찬받은 신작 게임을 해봤는데… 솔직히 너무 재미없다. 개발사 담당자가 방송을 보고 있다.',
    choices: [
      EventChoice(
        label: '솔직하게 혹평한다',
        result: '"버그가 너무 많네요. 아직은 추천 못 하겠어요." 담당자가 방을 나갔다.',
        fx: (s) => const Fx(image: 7, heat: 5),
        sns: const SnsTopic(
          tag: '{name}_솔직리뷰',
          headline: '{name}, 협찬 게임 생방송 혹평',
          tone: 0.4,
          hate: ['협찬받고 저러면 상도덕이 없는 거지', '게임 팬들 화났다 ㅋㅋ', '본인이 못하는 걸 게임 탓'],
          shield: ['협찬이어도 솔직한 게 리뷰지', '{name} 리뷰는 믿고 봄', '개발사가 반성해야 함'],
          neutral: ['그 게임 진짜 버그 많긴 함'],
        ),
      ),
      EventChoice(
        label: '좋은 점만 골라서 포장한다',
        result: '"그래픽이 정말 예쁘네요~" 협찬비가 두둑이 들어왔다.',
        fx: (s) => Fx(money: scaleMoney(s, 250000), image: -5),
        sns: const SnsTopic(
          tag: '{name}_협찬리뷰',
          headline: '{name} 리뷰 믿고 샀다가 낭패… 시청자 불만',
          tone: -0.3,
          hate: ['{name} 리뷰 보고 샀는데 환불함', '협찬이라고 빨아주네', '이제 {name} 리뷰 안 믿음'],
          shield: ['협찬 표시 했잖아요', '취향 차이일 수도', '게임 하나로 사람 매도하지 맙시다'],
          neutral: ['그래픽은 예쁘긴 함 ㅋㅋ'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'dating',
    where: 'live',
    title: '열애설',
    weight: 2,
    when: (s) => s.followers >= 3000,
    text: (s) => '방송 화면 뒤로 커플 머그잔이 잡혔다. 채팅창이 "???"로 도배되기 시작한다.',
    choices: [
      EventChoice(
        label: '솔직하게 연애 중이라고 밝힌다',
        result: '"네, 만나는 사람 있어요. 예쁘게 봐주세요." 축하와 배신감이 동시에 쏟아졌다.',
        fx: (s) => const Fx(followers: -0.03, image: 5, heat: 6),
        sns: const SnsTopic(
          tag: '{name}_열애',
          headline: '{name}, 생방송 중 열애 인정',
          tone: 0.2,
          oppositeTone: -0.6,
          hate: ['그동안 솔로인 척한 거임?', '배신감 든다 ㅠ', '후원한 돈 데이트 비용으로 쓰는 거?'],
          shield: ['연애하는 게 죄임?', '솔직해서 더 좋아짐', '{name} 축하해요!! 행복하세요', '이걸로 욕하는 사람들 정상 아님'],
          neutral: ['상대 누군지 궁금하다', '머그잔 어디 거임 ㅋㅋ'],
        ),
      ),
      EventChoice(
        label: '"동생 거예요"라고 둘러댄다',
        result: '대충 둘러댔다. 일단은 넘어간 것 같다… 일단은.',
        fx: (s) => const Fx(flag: 'lieDating', heat: 3),
        sns: const SnsTopic(
          tag: '{name}_머그잔',
          headline: '{name} 커플 머그잔? "동생 것" 해명',
          tone: 0.3,
          oppositeTone: -0.3,
          hate: ['동생 거라는 거 누가 믿음 ㅋㅋ', '거짓말 티 나던데'],
          shield: ['동생 거라는데 왜 의심함', '사생활 캐지 맙시다', '머그잔 하나로 소설 쓰네'],
          neutral: ['탐정들 출동했다 ㅋㅋ'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'copy',
    where: 'live',
    title: '표절 의혹',
    weight: 2,
    when: (s) => s.followers >= 1500,
    text: (s) => "채팅창에 \"이거 '먹보대장' 콘텐츠 그대로 베낀 거 아님?\" 이라는 말이 퍼지고 있다.",
    choices: [
      EventChoice(
        label: '참고한 게 맞다며 사과하고 출처를 밝힌다',
        result: '참고한 채널을 소개하고 사과했다. 먹보대장 쪽에서도 괜찮다는 답이 왔다.',
        fx: (s) => const Fx(image: 3, heat: -4),
        sns: const SnsTopic(
          tag: '{name}_표절',
          headline: '{name}, 콘텐츠 표절 의혹에 즉시 인정·사과',
          tone: 0.4,
          hate: ['걸리니까 인정하는 거지', '아이디어 도둑'],
          shield: ['바로 인정하는 거 쉽지 않음', '먹보대장도 괜찮다잖아', '콘텐츠 포맷은 다 비슷함'],
          neutral: ['둘이 합방하면 재밌겠다'],
        ),
      ),
      EventChoice(
        label: '우연의 일치라고 반박한다',
        result: '"전혀 몰랐던 채널인데요?" 반박하자 비교 영상이 만들어지기 시작했다.',
        fx: (s) => const Fx(heat: 12, image: -4),
        sns: const SnsTopic(
          tag: '{name}_표절의혹',
          headline: '{name} vs 먹보대장 콘텐츠 비교 영상 화제',
          tone: -0.3,
          hate: ['비교 영상 보니까 빼박인데', '몰랐다는 게 더 괘씸함', '구독자 목록에 먹보대장 있던데?'],
          shield: ['먹방 포맷이 다 거기서 거기지', '억지로 끼워 맞춘 비교 영상임', '{name}이 먼저 했던 것도 있음'],
          neutral: ['비교 영상 조회수 터짐 ㅋㅋ'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'letter',
    where: 'live',
    title: '팬의 선물',
    weight: 2,
    when: (s) => s.followers >= 300,
    text: (s) => '팬에게서 손편지와 직접 뜬 목도리가 도착했다. "{name}님 방송 덕분에 힘든 시기를 버텼어요."',
    choices: [
      EventChoice(
        label: '방송에서 편지를 읽어준다',
        result: '편지를 읽다가 목이 메었다. 채팅창도 함께 울었다.',
        fx: (s) => const Fx(image: 5, mental: 12, followers: 0.02),
        sns: const SnsTopic(
          tag: '{name}_손편지',
          headline: '{name}, 팬 손편지 읽다 눈물',
          tone: 0.8,
          hate: ['감성팔이 그만', '우는 거 연기 아님?'],
          shield: ['나도 같이 울었다 ㅠㅠ', '이런 게 방송의 힘이지', '{name} 진심이 느껴짐'],
          neutral: ['목도리 퀄리티 뭐임 장인이다'],
        ),
      ),
      EventChoice(
        label: '방송이 끝나고 혼자 읽는다',
        result: '방송이 끝난 뒤 조용히 편지를 읽었다. 힘이 난다.',
        fx: (s) => const Fx(mental: 15),
      ),
    ],
  ),
  GameEvent(
    id: 'raid',
    where: 'live',
    title: '채팅 테러',
    weight: 2,
    when: (s) => s.followers >= 1000,
    text: (s) => '다른 방송 시청자들이 몰려와 채팅창을 도배하기 시작했다!',
    choices: [
      EventChoice(
        label: '슬로우 모드를 켜고 차분하게 진행한다',
        result: '채팅을 정리하고 평소처럼 방송했다. 테러범들은 금세 흥미를 잃었다.',
        fx: (s) => const Fx(image: 4, mental: -3),
        sns: const SnsTopic(
          tag: '{name}_테러',
          headline: '{name} 방송에 채팅 테러… 침착한 대응',
          tone: 0.5,
          hate: ['관리 못해서 테러당한 거 아님?'],
          shield: ['테러한 쪽이 잘못이지', '{name} 대응 깔끔했음', '어느 방송 시청자들인지 다 앎'],
          neutral: ['요즘 테러 유행인가'],
        ),
      ),
      EventChoice(
        label: '같이 맞불을 놓는다',
        result: '시청자들과 함께 반격했다. 방송은 난장판이 됐지만 시청자 수는 최고를 찍었다.',
        fx: (s) => const Fx(followers: 0.06, heat: 15, image: -5),
        sns: const SnsTopic(
          tag: '{name}_맞불',
          headline: '{name}, 채팅 테러에 맞불… 방송 간 갈등 격화',
          tone: -0.2,
          hate: ['방송 수준 진짜 ㅋㅋ', '시청자들 끌고 싸움 붙이네', '똑같은 사람 되는 거임'],
          shield: ['먼저 건드린 게 누군데', '가만히 맞고만 있으라는 거?', '{name} 시원했다 ㅋㅋ'],
          neutral: ['두 방송 팬들 싸움 아직도 하는 중'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'old_post',
    where: 'news',
    title: '과거 글 박제',
    weight: 2,
    when: (s) => s.followers >= 5000 && !s.flags.contains('oldPostDone'),
    text: (s) => '커뮤니티에 당신이 7년 전 쓴 흑역사 글이 박제되어 돌고 있다. 지금 보면 꽤 무례한 내용이다.',
    choices: [
      EventChoice(
        label: '사과문을 올린다',
        result: '어렸을 때의 잘못을 인정하는 사과문을 올렸다.',
        fx: (s) => const Fx(image: -3, heat: 4, flag: 'oldPostDone'),
        sns: const SnsTopic(
          tag: '{name}_사과문',
          headline: '{name}, 7년 전 게시글 논란에 사과',
          tone: 0.3,
          hate: ['사과문 복붙 느낌', '그때 본성이 지금도 있겠지', '사과하면 끝임?'],
          shield: ['7년 전 글까지 파는 건 너무함', '누구나 흑역사 있음', '사과 진정성 느껴졌다'],
          neutral: ['요즘 과거 글 파기 유행이네'],
        ),
      ),
      EventChoice(
        label: '해명문을 올린다',
        result: '글의 맥락을 해명했다. 그런데 해명이 또 다른 해명을 부르고 있다.',
        fx: (s) => const Fx(image: -6, heat: 14, flag: 'oldPostDone'),
        sns: const SnsTopic(
          tag: '{name}_해명',
          headline: '{name} 해명문, 오히려 역풍',
          tone: -0.3,
          hate: ['해명이 아니라 변명', '사과를 해야지 왜 가르치려 듦', '해명할수록 늪이네'],
          shield: ['맥락 보면 이해 감', '해명할 권리도 없음?', '여론 몰이 무섭다'],
          neutral: ['원본 글 아직 남아있음?'],
        ),
      ),
      EventChoice(
        label: '무대응한다',
        result: '아무 말도 하지 않았다. 침묵이 길어질수록 소문이 커진다.',
        fx: (s) => const Fx(heat: 18, image: -4, mental: -8, flag: 'oldPostDone'),
        sns: const SnsTopic(
          tag: '{name}_침묵',
          headline: '{name}, 과거 글 논란에 묵묵부답',
          tone: -0.4,
          hate: ['무대응이 답이라고 생각하나', '숨는 거 보니 찔리나 봄', '구독자들 기만'],
          shield: ['대응할 가치도 없는 논란이라 그런 듯', '본인도 생각할 시간이 필요하지', '곧 입장 내겠지'],
          neutral: ['오늘 방송 켤까?'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'hidden_ad_exposed',
    where: 'news',
    title: '뒷광고 폭로',
    weight: 6,
    when: (s) => s.flags.contains('hiddenAd'),
    text: (s) => '"[단독] 인기 방송인 {name}, 다이어트 젤리 뒷광고 정황" 기사가 포털 메인에 올랐다.',
    choices: [
      EventChoice(
        label: '사과하고 광고비를 전액 환원한다',
        result: '광고비를 시청자 이벤트로 환원하고 고개를 숙였다.',
        fx: (s) => Fx(money: -scaleMoney(s, 480000), image: -10, heat: 15, unflag: 'hiddenAd', mental: -10),
        sns: const SnsTopic(
          tag: '{name}_뒷광고',
          headline: '{name}, 뒷광고 인정하고 사과·환원',
          tone: -0.2,
          hate: ['내돈내산이라더니 ㅋㅋㅋ', '젤리 산 사람들은 뭐가 됨', '환원하면 끝? 신뢰는?'],
          shield: ['빨리 인정한 건 잘했다', '업계 관행이었다잖아', '한 번은 기회 줘야지'],
          neutral: ['뒷광고 또 터졌네 요즘 왜 이럼'],
        ),
      ),
      EventChoice(
        label: '끝까지 부인한다',
        result: '"사실무근입니다." 그러자 광고주와 주고받은 메시지가 공개됐다.',
        fx: (s) => const Fx(image: -25, heat: 40, followers: -0.08, unflag: 'hiddenAd', mental: -18),
        sns: const SnsTopic(
          tag: '{name}_거짓말',
          headline: '{name} "사실무근" 반박 직후 DM 공개… 거짓 해명 논란',
          tone: -0.9,
          hate: ['거짓말까지 함 ㅋㅋㅋ 끝났다', '{name} 은퇴해라', '팬들 기만한 거 실망', '증거 나오니까 조용하네'],
          shield: ['그래도 그동안 방송은 재밌었는데…', '조작된 DM일 수도 있지 않음?'],
          neutral: ['역대급 사건이네', '이번 주 실검 1위'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'dating_exposed',
    where: 'news',
    title: '열애 사진 유출',
    weight: 5,
    when: (s) => s.flags.contains('lieDating'),
    text: (s) => "연인과 데이트하는 사진이 찍혀 커뮤니티에 올라왔다. '동생 거'라던 그 머그잔도 함께 찍혀 있다.",
    choices: [
      EventChoice(
        label: '거짓말한 것을 사과한다',
        result: '사생활을 지키고 싶었다며 거짓말에 대해 사과했다.',
        fx: (s) => const Fx(image: -6, heat: 10, unflag: 'lieDating'),
        sns: const SnsTopic(
          tag: '{name}_머그잔의진실',
          headline: '{name} 열애 사진 공개… "거짓말 죄송"',
          tone: 0.1,
          oppositeTone: -0.5,
          hate: ['동생 거라며 ㅋㅋㅋㅋ', '거짓말한 게 문제지', '팬들을 바보로 아나'],
          shield: ['사생활 지키려고 그런 거잖아', '사진 찍어 올린 사람이 더 문제', '연애는 축하할 일이지'],
          neutral: ['머그잔 밈 됐다 ㅋㅋ'],
        ),
      ),
      EventChoice(
        label: '사생활이라며 선을 긋는다',
        result: '"사생활은 말씀드리지 않겠습니다." 짧은 입장만 냈다.',
        fx: (s) => const Fx(image: -3, heat: 16, followers: -0.03, unflag: 'lieDating'),
        sns: const SnsTopic(
          tag: '{name}_사생활',
          headline: '{name}, 열애 사진에 "사생활" 일축',
          tone: -0.1,
          oppositeTone: -0.5,
          hate: ['거짓말해놓고 사생활 타령', '팬들한테 미안하단 말도 없네'],
          shield: ['사생활 맞잖아', '파파라치 문화 진짜 별로다', '{name} 행복하면 됐음'],
          neutral: ['이제 동생 거 밈 못 쓰겠다'],
        ),
      ),
    ],
  ),
  // ───── 성장 단계별 사건 (한 판에 한 번씩) ─────

  // 초반: 대형 스트리머가 방송에 깜짝 등장
  GameEvent(
    id: 'big_visit',
    where: 'live',
    title: '대형 스트리머 등장',
    weight: 4,
    when: (s) => s.followers >= 10 && s.followers < 1500 && !s.flags.contains('bigVisitDone'),
    text: (s) => '채팅창이 갑자기 술렁인다. 구독자 80만의 게임 스트리머 "갓겜민수"가 방송에 들어왔다! "오 여기 재밌네ㅋㅋ"',
    choices: [
      EventChoice(
        label: '반갑게 인사하고 평소처럼 진행한다',
        result: '"어서 오세요! 편하게 보고 가세요~" 침착하게 방송을 이어가자 민수가 한참을 머물다 갔다. 민수 시청자들이 따라 들어왔다.',
        fx: (s) => const Fx(followers: 0.35, image: 3, flag: 'bigVisitDone'),
        sns: const SnsTopic(
          tag: '{name}_갓겜민수',
          headline: '갓겜민수, 신입 스트리머 {name} 방송에 깜짝 등장',
          tone: 0.6,
          hate: ['민수 덕에 뜨려는 거 보이네', '민수 시청자들 금방 빠짐'],
          shield: ['평소처럼 하는 거 보고 반함', '{name} 원래 재밌었음 ㅇㅇ', '민수가 괜히 들어간 게 아니네'],
          neutral: ['민수 요즘 신입 방송 돌아다닌대'],
        ),
      ),
      EventChoice(
        label: '너무 긴장해서 민수 얘기만 한다',
        result: '"헐 민수님이다… 저 팬이에요…" 방송 내내 민수 얘기만 하다 끝났다. 그래도 화제는 됐다.',
        fx: (s) => const Fx(followers: 0.15, image: -2, flag: 'bigVisitDone'),
        sns: const SnsTopic(
          tag: '{name}_성덕',
          headline: "{name}, 갓겜민수 등장에 방송 내내 '민수 얘기'",
          tone: -0.1,
          hate: ['방송이 아니라 팬미팅이네 ㅋㅋ', '자기 방송인데 왜 민수만 찾음'],
          shield: ['신입이면 저럴 수 있지', '성덕 된 거 축하해요 ㅋㅋ', '귀엽기만 하던데'],
          neutral: ['민수 반응 웃겼음'],
        ),
      ),
      EventChoice(
        label: '"합방해 주세요!" 바로 들이댄다',
        result: '"민수님 저랑 합방 한 번만요!!" 민수는 웃으며 "생각해 볼게요ㅋㅋ"라고 남겼다. 패기냐 무례냐로 말이 많다.',
        fx: (s) => const Fx(followers: 0.25, heat: 4, image: -1, flag: 'bigVisitDone'),
        sns: const SnsTopic(
          tag: '{name}_들이대기',
          headline: '{name}, 갓겜민수에게 즉석 합방 요청… "패기 vs 무례"',
          tone: 0.0,
          hate: ['선배한테 저렇게 들이대는 건 좀', '관종력 대단하네'],
          shield: ['패기 좋다 ㅋㅋㅋ', '민수도 웃던데 뭐가 문제', '이런 신입이 뜸'],
          neutral: ['민수 답장 올까?'],
        ),
      ),
    ],
  ),

  // 초반: 대형 스트리머와의 합방 초대
  GameEvent(
    id: 'big_collab',
    where: 'live',
    title: '대형 유튜버 합방 초대',
    weight: 3,
    when: (s) => s.followers >= 100 && s.followers < 5000 && !s.flags.contains('bigCollabDone'),
    text: (s) => "구독자 120만 먹방 유튜버 \"대식가 하나\"에게서 DM이 왔다. \"이번 주 '신인 발굴 합방'에 같이 나와 주실래요?\"",
    choices: [
      EventChoice(
        label: '밤새 준비해서 나간다',
        result: '리액션, 토크 주제, 먹방 순서까지 다 준비해 갔다. 합방이 끝나자 하나가 "다음에 또 해요!"라고 했다.',
        fx: (s) => const Fx(followers: 0.3, energy: -20, mental: -3, image: 4, flag: 'bigCollabDone'),
        sns: const SnsTopic(
          tag: '하나X{name}',
          headline: '대식가 하나 신인 발굴 합방, {name} 존재감 폭발',
          tone: 0.6,
          hate: ['하나 옆이라 더 초라해 보임', '준비한 티 너무 남'],
          shield: ['{name} 리액션 미쳤다', '하나가 왜 뽑았는지 알겠다', '합방 보고 구독함'],
          neutral: ['다음 신인은 누구?'],
        ),
      ),
      EventChoice(
        label: '준비 없이 그냥 나간다',
        result: '막상 카메라 앞에 서니 할 말이 생각나지 않았다. 하나가 열심히 말을 걸어 줬지만 분위기가 어색했다.',
        fx: (s) => const Fx(followers: 0.1, image: -4, flag: 'bigCollabDone'),
        sns: const SnsTopic(
          tag: '{name}_합방민폐',
          headline: "하나 합방 나온 {name}, '준비 부족' 지적",
          tone: -0.3,
          hate: ['하나 방송에 민폐', '저러면 다음 기회 없음', '말도 거의 안 하던데'],
          shield: ['처음이라 긴장했겠지', '하나가 잘 챙겨주더라', '그래도 귀여웠음'],
          neutral: ['편집본은 괜찮게 나왔대'],
        ),
      ),
      EventChoice(
        label: '아직은 때가 아니라며 정중히 거절한다',
        result: '"실력을 더 쌓고 꼭 다시 연락드릴게요!" 하나는 응원 이모티콘을 보내왔다.',
        fx: (s) => const Fx(mental: 3, flag: 'bigCollabDone'),
      ),
    ],
  ),

  // 중반: 굿즈 출시
  GameEvent(
    id: 'goods',
    where: 'news',
    title: '굿즈 제작 제안',
    weight: 3,
    when: (s) => s.followers >= 30000 && !s.flags.contains('goodsDone'),
    text: (s) => '굿즈 제작 업체에서 연락이 왔다. "{name}님 캐릭터가 들어간 굿즈 내 보실래요?"',
    choices: [
      EventChoice(
        label: '비싸도 좋은 재질로 만든다',
        result: '샘플을 세 번이나 다시 받아 가며 만들었다. 첫 판매분이 하루 만에 다 팔렸다.',
        fx: (s) => Fx(money: scaleMoney(s, 400000), image: 6, flag: 'goodsDone'),
        sns: const SnsTopic(
          tag: '{name}_굿즈',
          headline: '{name} 첫 굿즈 완판… "퀄리티 미쳤다"',
          tone: 0.6,
          hate: ['굿즈 장사 시작이네', '가격 좀 세다'],
          shield: ['실물 보니까 돈값 함', '포장까지 신경 썼더라', '두 개 삼 ㅋㅋ'],
          neutral: ['재판매 언제 함?'],
        ),
      ),
      EventChoice(
        label: '원가를 확 줄여 많이 남긴다',
        result: '돈은 많이 남았다. 그런데 "세탁 한 번에 프린트가 다 벗겨졌다"는 후기가 올라오기 시작했다.',
        fx: (s) => Fx(money: scaleMoney(s, 900000), image: -8, heat: 8, flag: 'goodsDone'),
        sns: const SnsTopic(
          tag: '{name}_굿즈품질',
          headline: '{name} 굿즈 품질 논란… "세탁 한 번에 프린트 다 벗겨져"',
          tone: -0.4,
          hate: ['이 가격에 이 퀄?', '팬들 호구로 보나', '환불 해줘라'],
          shield: ['업체 잘못 아님?', '{name}이 직접 만든 것도 아닌데', '첫 굿즈니까 봐주자'],
          neutral: ['굿즈 후기 사진 레전드'],
        ),
      ),
      EventChoice(
        label: '아직은 이르다며 거절한다',
        result: '"굿즈는 더 준비되면 할게요." 업체는 아쉬워하며 돌아갔다.',
        fx: (s) => const Fx(flag: 'goodsDone'),
      ),
    ],
  ),

  // 대형 스트리머: 팬미팅
  GameEvent(
    id: 'fanmeeting',
    where: 'news',
    title: '팬미팅 요청 쇄도',
    weight: 5,
    when: (s) => s.followers >= 100000 && !s.flags.contains('fanmeetDone'),
    text: (s) => '팬카페에 "{name} 팬미팅 해 주세요!!" 글이 수백 개 올라왔다. 공연장 대관 제안까지 들어왔다.',
    choices: [
      EventChoice(
        label: '큰 공연장을 빌려 성대하게 연다',
        result: '2천 석이 1분 만에 매진됐다. 무대 위에서 팬들의 함성을 들으며 눈물을 참지 못했다.',
        fx: (s) => Fx(money: -scaleMoney(s, 800000), followers: 0.08, image: 10, mental: 15, energy: -20, flag: 'fanmeetDone'),
        sns: const SnsTopic(
          tag: '{name}_팬미팅',
          headline: '{name} 첫 팬미팅 매진… 팬들과 눈물의 2시간',
          tone: 0.7,
          hate: ['팬미팅까지 할 급인가?', '티켓팅 실패해서 화남', '연예인 병 걸림'],
          shield: ['직접 한 명 한 명 인사해 줌 ㅠㅠ', '{name} 실물 영접 성공', '평생 잊지 못할 하루'],
          neutral: ['다음 팬미팅은 지방도 해주세요'],
        ),
      ),
      EventChoice(
        label: '추첨으로 무료 소규모 팬미팅을 연다',
        result: '추첨으로 뽑은 팬 100명과 작은 카페에서 만났다. 간식도 직접 준비했다.',
        fx: (s) => Fx(money: -scaleMoney(s, 150000), followers: 0.04, image: 14, mental: 10, flag: 'fanmeetDone'),
        sns: const SnsTopic(
          tag: '{name}_무료팬미팅',
          headline: '{name}, 추첨으로 팬 100명 초대한 무료 팬미팅',
          tone: 0.8,
          hate: ['추첨 떨어져서 슬픔', '100명은 너무 적다'],
          shield: ['무료라니 천사냐', '팬 사랑 진짜다', '간식까지 직접 준비했대'],
          neutral: ['당첨자 후기 올라옴'],
        ),
      ),
      EventChoice(
        label: '티켓값 15만 원 VIP 팬미팅을 연다',
        result: '수익은 엄청났다. 하지만 티켓값을 두고 팬카페가 둘로 갈라졌다.',
        fx: (s) => Fx(money: scaleMoney(s, 2000000), image: -10, heat: 15, followers: -0.02, flag: 'fanmeetDone'),
        sns: const SnsTopic(
          tag: '{name}_티켓값',
          headline: '{name} 팬미팅 VIP석 15만 원… 가격 논란',
          tone: -0.5,
          hate: ['팬들 지갑이 ATM이냐', '15만 원이면 콘서트 감', '돈독 올랐네'],
          shield: ['가고 싶은 사람만 가면 됨', '대관비 생각하면 그럴 수도', '다녀온 팬들은 만족하던데'],
          neutral: ['VIP 혜택이 뭔지가 중요할 듯'],
        ),
      ),
    ],
  ),

  // 대형 스트리머: 예능 출연
  GameEvent(
    id: 'tv_show',
    where: 'news',
    title: '예능 출연 제안',
    weight: 3,
    when: (s) => s.followers >= 300000 && !s.flags.contains('tvDone'),
    text: (s) => '방송국에서 연락이 왔다. 인기 예능 "놀러 와 방구석"에 게스트로 나와 달라고 한다.',
    choices: [
      EventChoice(
        label: '출연해서 몸 사리지 않고 웃긴다',
        result: '방송이 나간 다음 날, 동네 마트에서 "어? 그 예능 나온 분!" 소리를 들었다.',
        fx: (s) => const Fx(followers: 0.1, image: 6, energy: -20, flag: 'tvDone'),
        sns: const SnsTopic(
          tag: '{name}_예능',
          headline: "{name}, 지상파 예능 첫 출연에 '예능 신생아' 등극",
          tone: 0.5,
          hate: ['TV에서는 별로던데', '방송 버릇 못 고침'],
          shield: ['{name} 예능감 미쳤다', '고정 시켜줘라', '엄마가 {name} 알아봄 ㅋㅋ'],
          neutral: ['편집 많이 됐다던데'],
        ),
      ),
      EventChoice(
        label: '거절하고 내 방송에 집중한다',
        result: '"저는 제 방이 제일 편해요." 시청자들은 의리 있다며 좋아했다.',
        fx: (s) => const Fx(mental: 5, image: 2, flag: 'tvDone'),
      ),
    ],
  ),

  // 대형 스트리머: 시상식
  GameEvent(
    id: 'award',
    where: 'news',
    title: '크리에이터 어워즈',
    weight: 4,
    when: (s) => s.followers >= 500000 && !s.flags.contains('awardDone'),
    text: (s) => '"올해의 크리에이터 어워즈" 신인상 후보에 올랐다! 시상식 초대장이 도착했다.',
    choices: [
      EventChoice(
        label: '참석해서 팬들에게 공을 돌린다',
        result: '신인상을 받았다. "방구석에서 스마트폰 하나로 시작했어요. 다 여러분 덕분이에요."',
        fx: (s) => const Fx(image: 10, followers: 0.05, mental: 10, flag: 'awardDone'),
        sns: const SnsTopic(
          tag: '{name}_신인상',
          headline: '{name}, 크리에이터 어워즈 신인상 "팬들 덕분"',
          tone: 0.6,
          hate: ['상 줄 만한가?', '시상식 공정성 의문'],
          shield: ['수상 소감에 울었다', '받을 만한 사람이 받았다', '방구석 시절부터 봤는데 감격'],
          neutral: ['드레스코드 화제'],
        ),
      ),
      EventChoice(
        label: '수상 소감에서 다른 후보를 저격한다',
        result: '"솔직히 다른 후보들은 좀…" 객석이 얼어붙었다. 영상은 순식간에 퍼졌다.',
        fx: (s) => const Fx(followers: 0.04, heat: 20, image: -10, flag: 'awardDone'),
        sns: const SnsTopic(
          tag: '{name}_수상소감',
          headline: '{name} 수상 소감 중 다른 후보 저격… 시상식 발칵',
          tone: -0.5,
          hate: ['상 받고 저게 뭐냐', '인성 다 드러남', '시상식 분위기 망침'],
          shield: ['할 말 한 거지', '사이다였다 ㅋㅋ', '그 후보도 문제 있었음'],
          neutral: ['짤 벌써 돈다'],
        ),
      ),
    ],
  ),

  // ───── 인기 순위 이벤트 (순위표 상위권이 되면 아침에 찾아온다) ─────
  GameEvent(
    id: 'cf_model',
    where: 'rank',
    title: '📺 CF 광고 모델 제안',
    weight: 4,
    when: (s) => rankNow(s) <= 6 && !s.flags.contains('cfDone'),
    text: (s) => '인기 순위 ${rankNow(s)}위에 오르자 음료 회사에서 연락이 왔다. "{name}님을 이번 여름 광고 모델로 모시고 싶습니다!"',
    choices: [
      EventChoice(
        label: '내 스타일대로 재밌게 찍는다',
        result: '대본을 살짝 비틀어 애드리브를 넣었다. 광고가 "광고인데 끝까지 봄"으로 화제가 됐다.',
        fx: (s) => Fx(money: scaleMoney(s, 3000000), followers: 0.05, image: 6, energy: -15, flag: 'cfDone'),
        sns: const SnsTopic(
          tag: '{name}_광고',
          headline: '"광고인데 끝까지 봤다"… {name} 음료 CF 화제',
          tone: 0.6,
          hate: ['광고 찍더니 변했네', '저 음료 맛없던데'],
          shield: ['광고마저 웃기네 ㅋㅋ', '편의점 갔다가 {name} 얼굴 보고 놀람', '광고 모델 할 만하다'],
          neutral: ['모델료 얼마일까'],
        ),
      ),
      EventChoice(
        label: '모델료를 두 배로 부른다',
        result: '회사는 고민 끝에 받아들였다. 대신 "갑질했다"는 소문이 업계에 돌았다.',
        fx: (s) => Fx(money: scaleMoney(s, 6000000), image: -6, heat: 10, flag: 'cfDone'),
        sns: const SnsTopic(
          tag: '{name}_모델료',
          headline: '{name}, 광고 모델료 두 배 요구설… "몸값 올랐다"',
          tone: -0.3,
          hate: ['벌써 돈맛 들었네', '갑질 아님?', '초심 어디 감'],
          shield: ['몸값 올리는 게 프로지', '회사가 받아들였으면 끝', '소문일 뿐'],
          neutral: ['광고 나오면 확인해 봄'],
        ),
      ),
      EventChoice(
        label: '팬들이 싫어할 것 같아 거절한다',
        result: '"광고보다 방송이 먼저예요." 팬들은 의리 있다며 좋아했다.',
        fx: (s) => const Fx(image: 4, mental: 3, flag: 'cfDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'news_interview',
    where: 'rank',
    title: '📰 9시 뉴스 인터뷰',
    weight: 4,
    when: (s) => rankNow(s) <= 5 && !s.flags.contains('newsDone'),
    text: (s) => '공중파 9시 뉴스 기자에게 연락이 왔다. "요즘 MZ세대가 가장 많이 보는 방송인"으로 {name}을(를) 인터뷰하고 싶다고 한다.',
    choices: [
      EventChoice(
        label: '반지하 시절 이야기를 솔직하게 한다',
        result: '"스마트폰 하나로 반지하에서 시작했어요." 짧은 인터뷰였지만 부모님 단톡방까지 퍼졌다.',
        fx: (s) => const Fx(followers: 0.06, image: 10, mental: 6, flag: 'newsDone'),
        sns: const SnsTopic(
          tag: '{name}_9시뉴스',
          headline: '9시 뉴스에 나온 {name}… "반지하에서 스마트폰 하나로"',
          tone: 0.7,
          hate: ['뉴스까지 나올 급?', '감성팔이 아님?'],
          shield: ['엄마가 뉴스 보고 {name} 물어봄 ㅋㅋ', '진짜 자수성가네', '인터뷰 태도 좋더라'],
          neutral: ['자막에 이름 틀렸던데'],
        ),
      ),
      EventChoice(
        label: '카메라 앞에서 방송 홍보만 한다',
        result: '"구독 좋아요 알림 설정!" 기자의 표정이 굳었다. 인터뷰는 3초만 나갔다.',
        fx: (s) => const Fx(followers: 0.02, image: -4, heat: 6, flag: 'newsDone'),
        sns: const SnsTopic(
          tag: '{name}_뉴스홍보',
          headline: '9시 뉴스 인터뷰에서 구독 홍보한 {name}… "3초 출연"',
          tone: -0.1,
          hate: ['뉴스에서 구독 홍보라니', '방송이랑 뉴스 구분 못 함', '창피하다'],
          shield: ['3초여도 웃겼음 ㅋㅋ', '그게 {name} 캐릭터지', '밈 됐네'],
          neutral: ['그 3초 짤 돈다'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'idol_variety',
    where: 'rank',
    title: '📡 공중파 예능 고정 출연',
    weight: 4,
    when: (s) => rankNow(s) <= 4 && !s.flags.contains('varietyDone'),
    text: (s) => '공중파 토요 예능 "아이돌 대작전" PD에게서 연락이 왔다. 아이돌들과 함께 고정 멤버로 출연해 달라고 한다!',
    choices: [
      EventChoice(
        label: '고정 출연한다 (매주 촬영)',
        result: '아이돌들과 게임 대결을 하며 예능감을 뽐냈다. 촬영은 힘들었지만 시청률이 올랐다.',
        fx: (s) => Fx(money: scaleMoney(s, 2000000), followers: 0.12, image: 8, energy: -30, mental: -6, flag: 'varietyDone'),
        sns: const SnsTopic(
          tag: '{name}_공중파',
          headline: '{name}, 공중파 예능 고정 발탁… "인터넷 방송인 최초"',
          tone: 0.5,
          oppositeTone: -0.15,
          hate: ['아이돌 팬들 화났다', '분량 뺏지 마라', '공중파 수준 떨어짐'],
          shield: ['{name} 예능감 공중파에서도 통함', '아이돌이랑 케미 좋더라', '본방 사수 중'],
          neutral: ['시청률 몇 나옴?'],
        ),
      ),
      EventChoice(
        label: '한 번만 게스트로 나간다',
        result: '부담 없이 한 회만 나갔다. 짧았지만 "다음에 또 나와 주세요" 반응이 많았다.',
        fx: (s) => const Fx(followers: 0.05, image: 5, energy: -10, flag: 'varietyDone'),
      ),
      EventChoice(
        label: '내 방송이 먼저라며 거절한다',
        result: '"저는 제 방구석이 무대예요." 시청자들은 감동했지만 기회는 다른 스트리머에게 갔다.',
        fx: (s) => const Fx(image: 3, mental: 4, flag: 'varietyDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'rank1_crown',
    where: 'rank',
    title: '👑 실시간 인기 1위',
    weight: 10,
    when: (s) => rankNow(s) == 1 && !s.flags.contains('crownDone'),
    text: (s) => '드디어 스트리머 인기 순위 1위! 포털 실시간 검색어에 "{name}"이(가) 올랐다. 기념 방송을 해야 할 것 같다.',
    choices: [
      EventChoice(
        label: '팬들과 밤새 1위 기념 방송',
        result: '"여러분이 만든 1위예요!" 기념 방송 동시 시청자가 역대 최고를 찍었다.',
        fx: (s) => Fx(money: scaleMoney(s, 1500000), followers: 0.05, image: 6, mental: 12, energy: -25, flag: 'crownDone'),
        sns: const SnsTopic(
          tag: '{name}_1위',
          headline: '{name}, 스트리머 인기 순위 1위 등극',
          tone: 0.6,
          hate: ['1위 할 정도는 아닌데', '조작 아님?', '거품 곧 빠짐'],
          shield: ['반지하부터 본 사람 울고 있음', '1위 축하해!!', '받을 사람이 받았다'],
          neutral: ['2위랑 차이 얼마 안 남'],
        ),
      ),
      EventChoice(
        label: '조용히 감사 글만 올린다',
        result: '"아직 부족해요. 더 열심히 할게요." 겸손한 글에 칭찬이 쏟아졌다.',
        fx: (s) => const Fx(image: 10, mental: 6, flag: 'crownDone'),
      ),
    ],
  ),

  // ───── 위기 (유명해질수록 자주 찾아온다. 한 판에 한 번씩) ─────
  GameEvent(
    id: 'staff_gapjil',
    where: 'crisis',
    title: '🚨 갑질 고소',
    weight: 5,
    when: (s) => s.staff.isNotEmpty && !s.flags.contains('gapjilDone'),
    text: (s) =>
        '${staffOf(accuser(s)).name}가 "갑질을 당했다"며 고소장을 냈다. 밤 11시에 수정 요청을 보낸 카톡 캡처가 커뮤니티에 돌고 있다. ${staffOf(accuser(s)).name}는 오늘부로 일을 그만뒀다.',
    choices: [
      EventChoice(
        label: '💰 합의금을 주고 조용히 끝낸다',
        result: '합의금을 보내고 서로 더 말하지 않기로 했다. 그런데 "합의 = 인정 아니냐"는 말이 나온다.',
        fx: (s) => Fx(money: -scaleMoney(s, 300000), image: -3, heat: 6, quit: accuser(s), flag: 'gapjilDone'),
        sns: const SnsTopic(
          tag: '{name}_갑질합의',
          headline: '{name}, 전 직원 갑질 고소 합의로 마무리',
          tone: -0.2,
          hate: ['합의했다는 건 찔리는 게 있다는 거지', '돈으로 입막음 ㅋㅋ', '밤 11시 카톡은 선 넘었다'],
          shield: ['일 커지기 전에 정리한 게 현명', '양쪽 말 다 들어봐야 함', '프리랜서 일이 원래 그렇지'],
          neutral: ['합의금 얼마일까'],
        ),
      ),
      EventChoice(
        label: '⚖️ 변호사를 선임해 맞선다 (평판이 좋을수록 유리)',
        result: '대화 기록 전체를 제출했다. 수정 요청은 계약서에 있던 내용이었고, 결과는 무혐의!',
        chance: (s) => byImage(s, 0.5),
        fx: (s) => Fx(money: -scaleMoney(s, 150000), image: 8, heat: -10, mental: -5, quit: accuser(s), flag: 'gapjilDone'),
        sns: const SnsTopic(
          tag: '{name}_무혐의',
          headline: '{name} 갑질 고소 무혐의… "계약대로 일했을 뿐"',
          tone: 0.6,
          hate: ['무혐의라도 인성은 별개', '변호사빨이지'],
          shield: ['역시 아니었네', '대화 기록 보니까 정상이던데', '고소한 쪽이 사과해라'],
          neutral: ['요즘 이런 폭로 많네'],
        ),
        lose: EventChoice(
          label: '⚖️ 변호사를 선임해 맞선다',
          result: '재판에서 다른 직원들의 증언까지 나왔다. 패소… 변호사비와 배상금을 모두 물었다.',
          fx: (s) => Fx(money: -scaleMoney(s, 700000), image: -15, heat: 25, followers: -0.04, mental: -12, quit: accuser(s), flag: 'gapjilDone'),
          sns: const SnsTopic(
            tag: '{name}_갑질패소',
            headline: '{name} 갑질 소송 패소… 추가 증언까지',
            tone: -0.7,
            hate: ['결국 사실이었네', '직원한테 저러는 사람이 방송에선 착한 척', '구독 취소함', '소송까지 건 게 더 괘씸'],
            shield: ['판결 내용 다 나온 거 아님', '항소하면 모름'],
            neutral: ['판결문 요약 올라옴'],
          ),
        ),
      ),
      EventChoice(
        label: '🙇 잘못은 없지만 일단 사과한다',
        result: '"오해의 여지를 드려 죄송합니다." 사과문을 올렸다. 억울했지만 논란은 금방 식었다.',
        fx: (s) => Fx(image: -6, heat: 4, mental: -10, quit: accuser(s), flag: 'gapjilDone'),
        sns: const SnsTopic(
          tag: '{name}_갑질사과',
          headline: '{name}, 갑질 논란에 "오해 드려 죄송" 사과',
          tone: -0.1,
          hate: ['사과했다는 건 인정한 거네', '오해 드려 죄송은 사과가 아님'],
          shield: ['빨리 사과한 건 잘했다', '억울해도 사과하는 게 쉽나', '이제 그만 놓아주자'],
          neutral: ['사과문 맞춤법 검사 완료'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'school_violence',
    where: 'crisis',
    title: '🚨 학폭 논란',
    weight: 4,
    when: (s) => s.followers >= 20000 && !s.flags.contains('schoolDone'),
    text: (s) => '"[폭로] {name}, 중학교 때 저를 괴롭혔습니다" 익명 커뮤니티 글이 올라왔다. 증거는 없지만 조회수가 폭발 중이다.',
    choices: [
      EventChoice(
        label: '📂 동창 증언과 생활기록부를 공개한다',
        result: '동창 10명이 실명으로 "그런 일 없었다"고 증언했다. 글쓴이는 계정을 지우고 사라졌다.',
        chance: (s) => byImage(s, 0.65),
        fx: (s) => const Fx(image: 10, heat: -15, followers: 0.02, flag: 'schoolDone'),
        sns: const SnsTopic(
          tag: '{name}_학폭허위',
          headline: '{name} 학폭 의혹, 동창 증언으로 허위 판명',
          tone: 0.7,
          hate: ['그래도 찜찜함', '동창들이 친구라서 감싸는 거 아님?'],
          shield: ['허위 폭로한 사람 처벌해라', '생기부까지 깠으면 끝난 거지', '마녀사냥한 사람들 사과해'],
          neutral: ['요즘 학폭 폭로 진짜 많다'],
        ),
        lose: EventChoice(
          label: '📂 동창 증언과 생활기록부를 공개한다',
          result: '한 동창이 "장난이 좀 심하긴 했다"고 말했다. 해명은 오히려 불에 기름을 부었다.',
          fx: (s) => const Fx(image: -14, heat: 22, followers: -0.05, mental: -12, flag: 'schoolDone'),
          sns: const SnsTopic(
            tag: '{name}_학폭',
            headline: '{name} 학폭 해명 역풍… "장난이 심했다" 동창 증언',
            tone: -0.7,
            hate: ['장난이었다고 하면 다냐', '피해자는 평생 기억함', '방송 접어라', '이래서 해명은 신중해야'],
            shield: ['한 명 말로 단정하지 말자', '다른 동창들은 아니라잖아'],
            neutral: ['진실은 아무도 모름'],
          ),
        ),
      ),
      EventChoice(
        label: '⚖️ 허위사실 유포로 고소한다',
        result: '고소장을 내자 작성자가 글을 내리고 "지어낸 이야기였다"며 사과했다.',
        chance: (s) => byImage(s, 0.55),
        fx: (s) => Fx(money: -scaleMoney(s, 150000), image: 6, heat: -12, flag: 'schoolDone'),
        sns: const SnsTopic(
          tag: '{name}_학폭고소',
          headline: '{name} 학폭 폭로자, 고소 후 "지어낸 글" 자백',
          tone: 0.6,
          hate: ['고소로 겁줘서 내린 거 아님?'],
          shield: ['허위 폭로 처벌 꼭 받길', '{name} 마음고생 했겠다', '역시 아니었음'],
          neutral: ['폭로 글 캡처 다 지워짐'],
        ),
        lose: EventChoice(
          label: '⚖️ 허위사실 유포로 고소한다',
          result: '"고소로 입막음하냐"는 반발이 커졌다. 다른 익명 글까지 올라오기 시작했다.',
          fx: (s) => Fx(money: -scaleMoney(s, 150000), image: -10, heat: 18, followers: -0.03, flag: 'schoolDone'),
          sns: const SnsTopic(
            tag: '{name}_입막음',
            headline: '{name}, 학폭 폭로자 고소… "입막음" 반발',
            tone: -0.6,
            hate: ['피해자를 고소하네', '고소부터 하는 거 보니 찔리나 봄', '추가 폭로 기다린다'],
            shield: ['허위면 고소하는 게 당연하지', '증거 없는 폭로가 더 문제'],
            neutral: ['법적 공방 길어질 듯'],
          ),
        ),
      ),
      EventChoice(
        label: '🙇 기억은 안 나지만 상처받았다면 사과한다',
        result: '"기억나지 않지만, 상처받으셨다면 죄송합니다." 사과문은 "인정한 셈"이라며 퍼졌다.',
        fx: (s) => const Fx(image: -10, heat: 12, followers: -0.03, mental: -8, flag: 'schoolDone'),
        sns: const SnsTopic(
          tag: '{name}_학폭사과',
          headline: '{name}, 학폭 의혹에 "기억 안 나지만 죄송"',
          tone: -0.4,
          hate: ['기억 안 난다는 게 제일 무서움', '사과 = 인정', '가해자는 원래 기억 못 함'],
          shield: ['일단 사과한 건 용기', '증거도 없는데 사과까지 했잖아'],
          neutral: ['사과문 해석 논쟁 중'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'impersonator',
    where: 'crisis',
    title: '🚨 사칭 계정 사기',
    weight: 4,
    when: (s) => s.followers >= 8000 && !s.flags.contains('fakeDone'),
    text: (s) => '{name}을(를) 사칭한 계정이 팬들에게 "팬미팅 선입금"을 받고 잠적했다. 피해자가 수십 명이다.',
    choices: [
      EventChoice(
        label: '💸 피해 팬들에게 직접 보상한다',
        result: '내 잘못은 아니지만 피해 금액을 직접 돌려줬다. 팬들은 감동했다.',
        fx: (s) => Fx(money: -scaleMoney(s, 250000), image: 12, mental: 4, flag: 'fakeDone'),
        sns: const SnsTopic(
          tag: '{name}_사칭보상',
          headline: '{name}, 사칭 사기 피해 팬들에게 사비로 보상',
          tone: 0.8,
          hate: ['이미지 관리 오지네'],
          shield: ['자기 잘못도 아닌데 보상이라니', '이런 사람이라 좋아함', '사기꾼 꼭 잡혀라'],
          neutral: ['사칭 계정 신고 부탁'],
        ),
      ),
      EventChoice(
        label: '📢 공지만 올리고 경찰에 맡긴다',
        result: '"저와 무관한 계정입니다." 공지를 올렸다. "너무 차갑다"는 반응도 있었다.',
        fx: (s) => const Fx(image: -3, heat: 6, flag: 'fakeDone'),
        sns: const SnsTopic(
          tag: '{name}_사칭',
          headline: '{name} 사칭 계정 사기 피해 속출… "무관" 공지',
          tone: -0.1,
          hate: ['팬들 피해 봤는데 공지 한 줄?', '좀 더 신경 써 줬으면'],
          shield: ['본인 잘못 아니잖아', '사기꾼이 나쁜 거지'],
          neutral: ['사칭 계정 아직 살아 있음'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'friend_expose',
    where: 'crisis',
    title: '🚨 옛 친구의 폭로',
    weight: 4,
    when: (s) => s.followers >= 30000 && !s.flags.contains('friendDone'),
    text: (s) => '옛 친구가 영상을 올렸다. "{name}, 반지하 시절에 나한테 300만 원 빌리고 안 갚았어요. 유명해지더니 연락도 안 받네요."',
    choices: [
      EventChoice(
        label: '🧾 이체 내역을 공개한다',
        result: '3년 전에 모두 갚은 이체 내역을 공개했다. 친구는 "기억이 잘못됐다"며 영상을 내렸다.',
        chance: (s) => byImage(s, 0.6),
        fx: (s) => const Fx(image: 8, heat: -10, flag: 'friendDone'),
        sns: const SnsTopic(
          tag: '{name}_이체내역',
          headline: '{name}, 이체 내역 공개… "3년 전에 다 갚았다"',
          tone: 0.6,
          hate: ['친구랑 돈 얘기 공개하는 것도 좀'],
          shield: ['증거 나오니까 조용해졌네', '유명해지면 별 사람 다 꼬인다', '{name} 억울했겠다'],
          neutral: ['친구 영상 삭제됨'],
        ),
        lose: EventChoice(
          label: '🧾 이체 내역을 공개한다',
          result: '갚은 건 절반뿐이었다는 게 드러났다. 나머지는 까맣게 잊고 있었다.',
          fx: (s) => const Fx(image: -12, heat: 20, followers: -0.03, mental: -8, flag: 'friendDone'),
          sns: const SnsTopic(
            tag: '{name}_빚투',
            headline: '{name} 빚투 해명 역풍… "절반만 갚아"',
            tone: -0.6,
            hate: ['절반은 어디 감?', '돈 벌면서 친구 돈은 안 갚네', '내역 공개가 자폭'],
            shield: ['잊었을 수도 있지', '지금이라도 갚으면 됨'],
            neutral: ['빚투 또 터졌네'],
          ),
        ),
      ),
      EventChoice(
        label: '🤝 조용히 다시 갚고 화해한다',
        result: '친구를 만나 밥을 사고 돈을 보냈다. 친구가 "오해였다"는 영상을 다시 올렸다.',
        fx: (s) => Fx(money: -scaleMoney(s, 150000), image: 2, heat: -6, mental: 5, flag: 'friendDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'channel_hack',
    where: 'crisis',
    title: '🚨 채널 해킹',
    weight: 3,
    when: (s) => s.followers >= 50000 && !s.flags.contains('hackDone'),
    text: (s) => '자고 일어나니 내 채널에서 코인 사기 방송이 24시간째 송출되고 있다! 채널 이름도 바뀌어 있다.',
    choices: [
      EventChoice(
        label: '🔐 보안 업체에 긴급 의뢰한다',
        result: '보안 업체가 몇 시간 만에 채널을 되찾아 줬다. 피해 공지도 빠르게 올렸다.',
        fx: (s) => Fx(money: -scaleMoney(s, 250000), followers: -0.005, flag: 'hackDone'),
      ),
      EventChoice(
        label: '📞 밤새 플랫폼 고객센터에 매달린다',
        result: '사흘 만에 채널을 되찾았다. 그사이 구독자가 꽤 빠져나갔다.',
        fx: (s) => const Fx(energy: -40, mental: -12, followers: -0.03, heat: 5, flag: 'hackDone'),
        sns: const SnsTopic(
          tag: '{name}_해킹',
          headline: '{name} 채널 해킹… 사흘간 코인 사기 방송',
          tone: 0.1,
          hate: ['보안 관리 좀 하지', '코인 방송 보고 돈 넣은 사람 어쩔'],
          shield: ['{name}도 피해자임', '플랫폼 대응 너무 느림', '복구 기다릴게'],
          neutral: ['요즘 대형 채널 해킹 유행'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'tax_audit',
    where: 'crisis',
    title: '🚨 세무조사',
    weight: 3,
    when: (s) => s.followers >= 100000 && !s.flags.contains('taxDone'),
    text: (s) => '"[단독] 억대 수입 방송인 {name}, 세무조사 착수" 기사가 떴다. 후원금 신고 누락 의혹이다.',
    choices: [
      EventChoice(
        label: '🧮 세무사를 고용해 성실히 소명한다',
        result: '장부를 꼼꼼히 정리해 제출했다. 결과는 "문제없음". 오히려 성실 납세자로 알려졌다.',
        chance: (s) => byImage(s, 0.7),
        fx: (s) => Fx(money: -scaleMoney(s, 300000), image: 5, heat: -8, flag: 'taxDone'),
        sns: const SnsTopic(
          tag: '{name}_세무조사',
          headline: '{name} 세무조사 "문제없음" 결론',
          tone: 0.5,
          hate: ['조사받은 것 자체가 좀', '얼마나 버는 거야 대체'],
          shield: ['깔끔하네', '성실 납세 인정', '기사 쓴 기자 정정해라'],
          neutral: ['방송인 수입 공개 논쟁'],
        ),
        lose: EventChoice(
          label: '🧮 세무사를 고용해 성실히 소명한다',
          result: '해외 플랫폼 후원금 일부가 신고에서 빠져 있었다. 추징금을 물었다.',
          fx: (s) => Fx(money: -scaleMoney(s, 1500000), image: -10, heat: 16, flag: 'taxDone'),
          sns: const SnsTopic(
            tag: '{name}_추징금',
            headline: '{name}, 후원금 신고 누락으로 추징금',
            tone: -0.5,
            hate: ['팬들 돈으로 탈세?', '세금은 내고 방송해라', '실망이다'],
            shield: ['고의는 아니었다잖아', '추징금 다 냈으면 된 거지'],
            neutral: ['방송인 세금 교육 필요'],
          ),
        ),
      ),
      EventChoice(
        label: '🙇 먼저 추징금을 내고 사과문을 올린다',
        result: '조사가 끝나기도 전에 추징금을 내고 사과했다. "시원하게 인정했다"는 반응도 있었다.',
        fx: (s) => Fx(money: -scaleMoney(s, 1000000), image: -4, heat: 6, flag: 'taxDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'stalker',
    where: 'crisis',
    title: '🚨 사생팬',
    weight: 3,
    when: (s) => s.followers >= 200000 && !s.flags.contains('stalkerDone'),
    text: (s) => '방송에 비친 창밖 풍경으로 집 주소가 알려졌다. 오늘 아침 문 앞에 모르는 사람이 서 있었다.',
    choices: [
      EventChoice(
        label: '🚓 경찰에 신고하고 경호 업체를 부른다',
        result: '경호원이 집 앞을 지키기 시작했다. 돈은 들었지만 마음이 놓였다.',
        fx: (s) => Fx(money: -scaleMoney(s, 500000), mental: 6, flag: 'stalkerDone'),
      ),
      EventChoice(
        label: '🙏 방송에서 자제를 부탁한다',
        result: '"제 공간은 지켜 주세요." 진심이 통했는지 팬들이 서로 자제를 부탁하기 시작했다.',
        chance: (s) => byImage(s, 0.5),
        fx: (s) => const Fx(mental: 2, image: 4, flag: 'stalkerDone'),
        lose: EventChoice(
          label: '🙏 방송에서 자제를 부탁한다',
          result: '부탁은 소용없었다. 밤마다 초인종이 울렸고, 잠을 이루지 못했다.',
          fx: (s) => const Fx(mental: -20, energy: -20, flag: 'stalkerDone'),
        ),
      ),
    ],
  ),

  // ───── 초반 방송 사고 (작은 방송인일 때만) ─────
  GameEvent(
    id: 'hot_mic',
    where: 'live',
    title: '🎙️ 방송이 안 꺼졌다',
    weight: 4,
    when: (s) => s.followers >= 30 && s.followers < 3000 && !s.flags.contains('hotMicDone'),
    text: (s) => '방송을 끈 줄 알고 기지개를 켜며 혼잣말을 했다. "아 오늘 시청자 왜 이렇게 없어… 다들 어디 간 거야" 그런데 채팅창이 움직이고 있다. "다 들려요 ㅋㅋㅋ"',
    choices: [
      EventChoice(
        label: '😂 "다 들었어요?" 웃으며 받아친다 (센스에 달림)',
        result: '"들었으면 구독 좀 해 주세요 ㅋㅋ" 클립이 "현실 스트리머"라며 퍼졌다.',
        chance: (s) => byImage(s, 0.6),
        fx: (s) => const Fx(followers: 0.08, image: 3, flag: 'hotMicDone'),
        sns: const SnsTopic(
          tag: '{name}_방송안꺼짐',
          headline: '방송 안 꺼진 줄 모르고 혼잣말한 {name}… "현실 스트리머"',
          tone: 0.6,
          hate: ['시청자 탓하네', '평소 본심 나옴'],
          shield: ['너무 웃김 ㅋㅋㅋ', '현실 스트리머 공감', '받아치는 거 센스 있다'],
          neutral: ['클립 조회수 터짐'],
        ),
        lose: EventChoice(
          label: '😂 "다 들었어요?" 웃으며 받아친다',
          result: '어색한 웃음만 나왔다. "시청자 탓하는 스트리머" 클립이 돌기 시작했다.',
          fx: (s) => const Fx(image: -6, heat: 8, mental: -6, flag: 'hotMicDone'),
          sns: const SnsTopic(
            tag: '{name}_본심',
            headline: '{name} 방송 안 꺼진 줄 모르고 시청자 탓',
            tone: -0.3,
            hate: ['본심 나왔네', '시청자 없는 게 우리 탓?', '구독 취소'],
            shield: ['혼잣말인데 뭘', '작은 방송인 현실이지'],
            neutral: ['방송 끄는 버튼 두 번 확인하자'],
          ),
        ),
      ),
      EventChoice(
        label: '🙇 바로 사과한다',
        result: '"죄송해요, 와 주신 분들께 감사한 마음뿐이에요." 남아 있던 시청자들이 응원해 줬다.',
        fx: (s) => const Fx(image: 1, mental: -3, flag: 'hotMicDone'),
      ),
      EventChoice(
        label: '🔌 못 본 척 방송을 끈다',
        result: '황급히 방송을 껐다. 다음 날 커뮤니티에 "도망간 스트리머" 글이 올라왔다.',
        fx: (s) => const Fx(image: -4, heat: 6, flag: 'hotMicDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'family_intrude',
    where: 'live',
    title: '🚪 가족 난입',
    weight: 4,
    when: (s) => s.followers >= 10 && s.followers < 3000 && !s.flags.contains('familyDone'),
    text: (s) => '방송 중에 방문이 벌컥 열렸다. "${s.look.male ? '아들' : '딸'}! 밥 먹으라니까 몇 번을 불러!" 엄마의 목소리가 그대로 송출됐다.',
    choices: [
      EventChoice(
        label: '👩 엄마를 방송에 소개한다',
        result: '엄마가 수줍게 손을 흔들었다. 채팅창이 "어머님 안녕하세요!!"로 도배됐다.',
        fx: (s) => const Fx(followers: 0.06, image: 5, mental: 4, flag: 'familyDone'),
        sns: const SnsTopic(
          tag: '{name}_어머님',
          headline: '{name} 방송에 어머니 깜짝 등장… "어머님 팬 됐어요"',
          tone: 0.8,
          hate: ['가족 팔이 시작'],
          shield: ['어머님 너무 귀여우셔 ㅋㅋㅋ', '이게 찐 가족 방송이지', '어머님 고정 출연 가자'],
          neutral: ['반찬 뭐였는지 궁금'],
        ),
      ),
      EventChoice(
        label: '🙈 황급히 방송을 끈다',
        result: '부랴부랴 방송을 껐다. 시청자 몇 명이 "아쉽다"며 나갔다.',
        fx: (s) => const Fx(followers: -0.01, mental: -3, flag: 'familyDone'),
      ),
      EventChoice(
        label: '🤫 "5분만!" 하고 계속한다 (운에 달림)',
        result: '엄마가 한숨 쉬며 나갔다. "어머님 화나셨다 ㅋㅋ" 채팅이 오히려 터졌다.',
        chance: (s) => 0.5,
        fx: (s) => const Fx(followers: 0.03, flag: 'familyDone'),
        lose: EventChoice(
          label: '🤫 "5분만!" 하고 계속한다',
          result: '등짝 스매싱 소리가 그대로 송출됐다. 클립은 웃겼지만 등이 아프다.',
          fx: (s) => const Fx(followers: 0.04, mental: -6, energy: -10, flag: 'familyDone'),
        ),
      ),
    ],
  ),

  // ───── MCN ─────
  GameEvent(
    id: 'mcn_offer',
    where: 'news',
    title: '🏢 MCN 소속 제안',
    weight: 4,
    when: (s) => s.followers >= 15000 && !s.flags.contains('mcnOffered') && !s.flags.contains('mcn') && !s.flags.contains('mcnSlaveDone'),
    text: (s) => 'MCN 회사 "스타웨이브"에서 소속 제안이 왔다. 계약금 ${won(scaleMoney(s, 400000))}에 광고·홍보를 맡아 주는 대신, 앞으로 후원·광고 수익의 30%를 가져간다.',
    choices: [
      EventChoice(
        label: '✍️ 계약한다 (시청자 +15%, 수익 30% 수수료)',
        result: '계약서에 사인했다. 회사 홍보 덕분에 방송이 여기저기 노출되기 시작했다.',
        fx: (s) => Fx(money: scaleMoney(s, 400000), image: 2, flag: 'mcn'),
      ),
      EventChoice(
        label: '🙅 혼자 하겠다며 거절한다',
        result: '"아직은 혼자 해 볼게요." 회사는 아쉬워하며 명함을 두고 갔다.',
        fx: (s) => const Fx(mental: 2, flag: 'mcnOffered'),
      ),
    ],
  ),
  GameEvent(
    id: 'mcn_slave',
    where: 'crisis',
    title: '🚨 노예계약 논란',
    weight: 6,
    when: (s) => s.flags.contains('mcn') && s.followers >= 60000 && !s.flags.contains('mcnSlaveDone'),
    text: (s) => '계약서를 다시 읽다가 독소조항을 발견했다. "계약 기간 10년, 위약금은 수익의 5배." 같은 회사 스트리머들도 술렁이고 있다.',
    choices: [
      EventChoice(
        label: '💸 위약금을 내고 탈퇴한다',
        result: '큰돈이 나갔지만 자유를 되찾았다. 수수료도 이제 없다.',
        fx: (s) => Fx(money: -scaleMoney(s, 800000), image: 4, mental: 6, unflag: 'mcn', flag: 'mcnSlaveDone'),
      ),
      EventChoice(
        label: '📢 계약서를 공개하고 폭로한다 (평판에 달림)',
        result: '여론이 내 편이 됐다. 회사는 사과문을 내고 계약을 해지해 줬다.',
        chance: (s) => byImage(s, 0.55),
        fx: (s) => const Fx(image: 10, heat: 5, followers: 0.03, unflag: 'mcn', flag: 'mcnSlaveDone'),
        sns: const SnsTopic(
          tag: '{name}_노예계약',
          headline: '{name}, MCN 노예계약 폭로… 회사 사과',
          tone: 0.6,
          hate: ['계약할 땐 좋다고 했으면서', '계약서 안 읽은 본인 잘못'],
          shield: ['10년 계약은 선 넘었다', '용기 있다', '다른 스트리머들도 나서야'],
          neutral: ['MCN 계약 실태 조사 필요'],
        ),
        lose: EventChoice(
          label: '📢 계약서를 공개하고 폭로한다',
          result: '회사가 "계약 위반"이라며 소송을 걸었다. 결국 위약금에 소송비까지 물었다.',
          fx: (s) => Fx(money: -scaleMoney(s, 1200000), heat: 15, image: -5, mental: -10, unflag: 'mcn', flag: 'mcnSlaveDone'),
        ),
      ),
      EventChoice(
        label: '😶 그냥 참고 남는다',
        result: '조용히 남기로 했다. 수수료는 계속 나간다.',
        fx: (s) => const Fx(mental: -10, flag: 'mcnSlaveDone'),
      ),
    ],
  ),

  // ───── 인간관계 ─────
  GameEvent(
    id: 'friend_feud',
    where: 'crisis',
    title: '🚨 절친 스트리머의 저격',
    weight: 4,
    when: (s) => s.followers >= 10000 && !s.flags.contains('feudDone'),
    text: (s) => '같이 합방하던 절친 스트리머 "새벽감성 수아"가 저격 방송을 했다. "뜨더니 연락도 씹고, 내 콘텐츠까지 따라 하더라."',
    choices: [
      EventChoice(
        label: '🔥 맞저격 방송을 한다',
        result: '서로의 카톡까지 공개되는 진흙탕 싸움이 됐다. 시청자는 늘었지만…',
        fx: (s) => const Fx(followers: 0.04, heat: 22, image: -8, mental: -8, flag: 'feudDone'),
        sns: const SnsTopic(
          tag: '{name}_수아_저격전',
          headline: '{name} vs 수아, 절친에서 저격전으로',
          tone: -0.3,
          hate: ['둘 다 똑같음', '친구 사이 저렇게 공개 싸움?', '팝콘 각'],
          shield: ['{name} 카톡 보니까 억울할 만함', '수아가 먼저 시작함'],
          neutral: ['저격 타임라인 정리 올라옴'],
        ),
      ),
      EventChoice(
        label: '🤝 직접 만나 화해한다 (운에 달림)',
        result: '술 한잔하며 오해를 풀었다. 다음 주에 "화해 합방"을 하기로 했다!',
        chance: (s) => byImage(s, 0.6),
        fx: (s) => const Fx(followers: 0.03, image: 6, mental: 6, flag: 'feudDone'),
        sns: const SnsTopic(
          tag: '{name}_수아_화해',
          headline: '{name}·수아 화해 합방 예고… "오해였다"',
          tone: 0.7,
          hate: ['짜고 친 거 아님?'],
          shield: ['둘이 다시 보니 좋다', '어른스럽게 풀었네', '화해 합방 본방 사수'],
          neutral: ['저격 영상은 삭제됨'],
        ),
        lose: EventChoice(
          label: '🤝 직접 만나 화해한다',
          result: '만나서 한 이야기까지 녹음돼 방송에 나갔다. 더 큰 싸움이 됐다.',
          fx: (s) => const Fx(heat: 14, mental: -12, image: -4, flag: 'feudDone'),
        ),
      ),
      EventChoice(
        label: '🤐 대응하지 않는다',
        result: '아무 말도 하지 않았다. 마음은 괴롭지만 논란은 서서히 식었다.',
        fx: (s) => const Fx(mental: -8, heat: 4, flag: 'feudDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'ex_expose',
    where: 'crisis',
    title: '🚨 전 연인의 폭로',
    weight: 4,
    when: (s) => s.followers >= 25000 && !s.flags.contains('exDone'),
    text: (s) => '전 연인이 SNS에 긴 글을 올렸다. "방송에선 착한 척하지만, 사귈 때는 완전 다른 사람이었어요."',
    choices: [
      EventChoice(
        label: '🧱 사생활이라며 선을 긋는다',
        result: '"개인적인 일이라 말씀드리지 않겠습니다." 짧은 입장만 냈다.',
        fx: (s) => const Fx(heat: 8, image: -3, flag: 'exDone'),
      ),
      EventChoice(
        label: '📱 반박 증거를 공개한다 (운에 달림)',
        result: '헤어질 때 주고받은 메시지를 공개했다. 폭로 글은 과장이었다는 게 드러났다.',
        chance: (s) => byImage(s, 0.5),
        fx: (s) => const Fx(image: 6, heat: -8, flag: 'exDone'),
        lose: EventChoice(
          label: '📱 반박 증거를 공개한다',
          result: '공개한 메시지에서 오히려 내 말투가 문제가 됐다. 역풍이 불었다.',
          fx: (s) => const Fx(image: -12, heat: 18, followers: -0.03, flag: 'exDone'),
          sns: const SnsTopic(
            tag: '{name}_전연인',
            headline: '{name}, 전 연인 폭로 반박하다 역풍',
            tone: -0.6,
            hate: ['반박한다고 깐 게 자폭', '말투 무섭다', '방송이랑 딴판이네'],
            shield: ['연애사는 둘만 아는 거', '한쪽 말만 듣지 말자'],
            neutral: ['연애 폭로 시즌인가'],
          ),
        ),
      ),
      EventChoice(
        label: '🙇 상처 줬다면 미안하다고 사과한다',
        result: '"부족했던 저 때문에 상처받았다면 미안합니다." 사과에 반응이 엇갈렸다.',
        fx: (s) => const Fx(image: -5, heat: 5, mental: -6, flag: 'exDone'),
        sns: const SnsTopic(
          tag: '{name}_사과',
          headline: '{name}, 전 연인 폭로에 사과',
          tone: -0.1,
          oppositeTone: -0.3,
          hate: ['사과하는 거 보니 사실인가 봄', '연애 숨긴 것도 실망'],
          shield: ['사과한 건 어른스럽다', '연애는 사생활이지'],
          neutral: ['전 연인 글 삭제됨'],
        ),
      ),
    ],
  ),
  GameEvent(
    id: 'wrecker',
    where: 'crisis',
    title: '🚨 사이버 렉카',
    weight: 4,
    when: (s) => s.followers >= 15000 && !s.flags.contains('wreckerDone'),
    text: (s) => '이슈 유튜버 "팩트폭격기"가 내 방송을 짜깁기해 "{name}의 충격적인 두 얼굴"이라는 영상을 올렸다. 조회수 100만.',
    choices: [
      EventChoice(
        label: '⚖️ 명예훼손으로 고소한다 (운에 달림)',
        result: '렉카 유튜버가 영상을 내리고 사과문을 올렸다. 다른 렉카들도 조용해졌다.',
        chance: (s) => 0.65,
        fx: (s) => Fx(money: -scaleMoney(s, 200000), image: 8, heat: -12, flag: 'wreckerDone'),
        sns: const SnsTopic(
          tag: '렉카_{name}_사과',
          headline: '렉카 유튜버, {name} 짜깁기 영상 삭제·사과',
          tone: 0.7,
          hate: ['고소 남발'],
          shield: ['렉카들 다 고소당해야 함', '짜깁기였구나', '{name} 고생했다'],
          neutral: ['렉카 규제 필요'],
        ),
        lose: EventChoice(
          label: '⚖️ 명예훼손으로 고소한다',
          result: '렉카가 "고소당했다"며 2탄을 올렸다. 조회수는 더 늘었다.',
          fx: (s) => Fx(money: -scaleMoney(s, 200000), heat: 12, image: -5, mental: -8, flag: 'wreckerDone'),
        ),
      ),
      EventChoice(
        label: '🎬 원본을 공개하는 해명 영상 (평판에 달림)',
        result: '원본과 나란히 놓으니 짜깁기가 한눈에 보였다. 해명 영상이 더 많이 퍼졌다.',
        chance: (s) => byImage(s, 0.55),
        fx: (s) => const Fx(image: 8, heat: -10, followers: 0.02, flag: 'wreckerDone'),
        lose: EventChoice(
          label: '🎬 원본을 공개하는 해명 영상',
          result: '원본에도 애매한 장면이 있었다. "해명이 더 문제"라는 반응이 나왔다.',
          fx: (s) => const Fx(image: -8, heat: 14, flag: 'wreckerDone'),
        ),
      ),
      EventChoice(
        label: '🤐 무시한다',
        result: '대응하지 않았다. 일주일쯤 지나자 렉카는 다른 사람을 찾아 떠났다.',
        fx: (s) => const Fx(heat: 8, image: -3, mental: -5, flag: 'wreckerDone'),
      ),
    ],
  ),

  // ───── 부모님 가게 (전업 방송인이 되면 알바 대신 가게 홍보) ─────
  GameEvent(
    id: 'parent_shop',
    where: 'news',
    title: '🍗 부모님 가게 오픈',
    weight: 6,
    when: (s) => s.followers >= proFollowers && !s.flags.contains('parentShop'),
    text: (s) => '부모님이 동네에 작은 치킨집을 차리셨다! 엄마가 전화로 조심스럽게 물었다. "혹시… 네 방송에서 한 번 소개해 줄 수 있니?"',
    choices: [
      EventChoice(
        label: '🙌 "당연하지! 내가 홍보할게!"',
        result: '가게 개업식에 꽃다발을 들고 갔다. 이제 시간 날 때 가게 홍보를 할 수 있다. (알바 버튼 → 가게 홍보)',
        fx: (s) => const Fx(mental: 6, image: 2, flag: 'parentShop'),
      ),
      EventChoice(
        label: '😅 "방송이랑은 따로 하는 게 좋을 것 같아"',
        result: '엄마는 "그래, 네 말이 맞다"며 웃으셨다. 마음이 쓰이면 언제든 홍보를 도울 수 있다. (알바 버튼 → 가게 홍보)',
        fx: (s) => const Fx(mental: -2, flag: 'parentShop'),
      ),
    ],
  ),

  // ───── 반려동물 사건 ─────
  GameEvent(
    id: 'pet_keyboard',
    where: 'live',
    title: '🐾 반려동물 난입',
    weight: 5,
    when: (s) => s.pet != null && !s.flags.contains('petKeyboardDone'),
    text: (s) => '방송 중에 ${petOf(s.pet!).name}가 책상 위로 올라왔다! 키보드를 밟자 채팅창에 "ㅁㄴㅇㄹㅁㄴㅇㄹ"가 올라갔다.',
    choices: [
      EventChoice(
        label: '🥰 카메라 앞에 데려와 소개한다',
        result: '시청자들이 난리가 났다. "얼굴 보여 줘서 고마워요!" 후원이 쏟아졌다.',
        fx: (s) => Fx(money: scaleMoney(s, 40000), followers: 0.04, image: 4, mental: 5, flag: 'petKeyboardDone'),
        sns: snsPet,
      ),
      EventChoice(
        label: '😅 조심스럽게 내려놓고 방송을 이어간다',
        result: '"잠깐만요~" 하고 내려놓았다. 채팅창은 "펫 보여 줘요!"로 가득했다.',
        fx: (s) => const Fx(followers: 0.01, flag: 'petKeyboardDone'),
      ),
    ],
  ),
  GameEvent(
    id: 'pet_sick',
    where: 'news',
    title: '🏥 반려동물이 아프다',
    weight: 4,
    when: (s) => s.pet != null && !s.flags.contains('petSickDone'),
    text: (s) => '아침에 일어나 보니 ${petOf(s.pet!).name}가 밥을 먹지 않는다. 기운이 하나도 없어 보인다.',
    choices: [
      EventChoice(
        label: '🏥 바로 동물병원에 간다',
        result: '다행히 큰 병은 아니었다. 병원비는 들었지만 마음이 놓였다.',
        fx: (s) => Fx(money: -scaleMoney(s, 150000), mental: 4, energy: -15, flag: 'petSickDone'),
      ),
      EventChoice(
        label: '📢 방송에서 걱정을 털어놓는다',
        result: '팬들이 함께 걱정해 줬다. "빨리 병원 가 보세요!" 응원 후원이 이어졌다.',
        fx: (s) => Fx(money: -scaleMoney(s, 80000), image: 3, mental: 2, flag: 'petSickDone'),
      ),
    ],
  ),
];

// ───── 결말 ─────
class Ending {
  const Ending(this.title, this.type, this.text);
  final String title;

  /// true(진) / good / normal / bad
  final String type;
  final String text;
}

const endings = <String, Ending>{
  'scandal': Ending('자숙 엔딩', 'bad', '논란이 걷잡을 수 없이 커졌다. 당신은 "당분간 자숙하겠습니다"라는 글을 남기고 방송을 내려놓았다.'),
  'burnout': Ending('번아웃 엔딩', 'bad', '악플과 과로에 지쳐 더는 카메라 앞에 설 수 없었다. 당신은 조용히 휴방 공지를 올렸다.'),
  'celeb_good': Ending('국민 스트리머', 'true', "구독자 100만, 그리고 좋은 평판. 광고 섭외가 줄을 잇고, 사람들은 당신을 '믿고 보는 방송인'이라 부른다."),
  'celeb_bad': Ending('악명 높은 스트리머', 'normal', "구독자 100만을 넘었지만 당신 이름 옆에는 늘 '논란'이 붙어 다닌다. 그래도 사람들은 계속 본다."),
  'big': Ending('인기 스트리머', 'good', '10만 명이 넘는 사람들이 당신의 방송을 기다린다. 방구석에서 시작한 방송이 이제는 직업이 되었다.'),
  'mid': Ending('중소 스트리머', 'good', '1만 명의 구독자와 함께하는 아담한 방송. 화려하진 않지만 단단하다.'),
  'small': Ending('소소한 방송인', 'normal', '구독자는 많지 않지만, 매일 찾아오는 고정 시청자들이 있다. 방송은 계속된다.'),
  'zero': Ending('방구석 방송인', 'bad', '방송을 내려놓기로 했다. 보는 사람은 손에 꼽았지만, 스마트폰 하나로 도전했던 날들은 남았다.'),
  'top': Ending('탑 스트리머', 'true', '스트리머 인기 순위 1위. 반지하 방에서 스마트폰 하나로 시작한 방송이 이제 대한민국에서 가장 많이 보는 방송이 되었다.'),
};

// ───── DM ─────
/// DM으로 오는 제안. [after]는 이 콘텐츠로 방송한 뒤에 온다 (null이면 아무 방송 뒤)
class DmOffer {
  const DmOffer({
    required this.id,
    required this.from,
    required this.color,
    required this.after,
    required this.minFollowers,
    required this.chance,
    required this.text,
    required this.accept,
    required this.fx,
    required this.result,
    required this.declined,
    this.sns,
  });
  final String id;
  final String from;
  final int color;
  final String? after;
  final int minFollowers;
  final double chance;
  final String Function(GameState s) text;

  /// 수락 버튼 글
  final String accept;
  final Fx Function(GameState s) fx;
  final String result;
  final String declined;
  final SnsTopic? sns;
}

final dmOffers = <DmOffer>[
  DmOffer(
    id: 'idol_collab',
    from: '스타라이트 엔터테인먼트',
    color: 0xFF8B5CF6,
    after: 'sing',
    minFollowers: 3000,
    chance: 0.25,
    text: (s) => '안녕하세요, 아이돌 그룹 "루미너스" 소속사입니다 🙂 방금 노래 방송 잘 봤어요! 이번 컴백 신곡 커버 콜라보 영상을 함께 찍고 싶은데 가능하실까요? 출연료 ${won(scaleMoney(s, 300000))} 드립니다.',
    accept: '콜라보 수락',
    fx: (s) => Fx(money: scaleMoney(s, 300000), followers: 0.06, energy: -15, image: 3),
    result: '아이돌 멤버들과 신곡 커버 영상을 찍었다. 영상이 올라가자마자 아이돌 팬들이 몰려왔다.',
    declined: '"다음에 기회가 되면 꼭 함께해요!" 소속사는 정중히 답장했다.',
    sns: const SnsTopic(
      tag: '{name}_루미너스',
      headline: '{name}, 아이돌 "루미너스"와 신곡 커버 콜라보',
      tone: 0.4,
      oppositeTone: -0.3,
      hate: ['우리 오빠들 옆에 왜 저 사람이', '아이돌 인기에 숟가락 얹기', '콜라보 각도 너무 가깝다'],
      shield: ['{name} 노래 아이돌이랑 붙어도 안 밀림', '케미 좋더라', '{name} 덕분에 루미너스 입덕함'],
      neutral: ['소속사가 먼저 연락했대'],
    ),
  ),
  DmOffer(
    id: 'game_company',
    from: '넥스트플레이 게임즈',
    color: 0xFF0EA5E9,
    after: 'game',
    minFollowers: 2000,
    chance: 0.2,
    text: (s) => '안녕하세요! 게임 방송 재밌게 보고 있어요 🎮 이번에 나온 신작 "던전 오브 레전드" 방송 한 번 해 주시면 ${won(scaleMoney(s, 200000))} 드릴게요. "유료 광고" 표시는 꼭 부탁드려요!',
    accept: '광고 방송 수락',
    fx: (s) => Fx(money: scaleMoney(s, 200000), energy: -10, followers: 0.01),
    result: '"유료 광고 포함" 표시를 달고 신작 게임을 했다. 생각보다 재밌어서 시청자들도 좋아했다.',
    declined: '"아쉽지만 다음 기회에!" 게임 회사는 쿠폰 코드만 보내왔다.',
  ),
  DmOffer(
    id: 'restaurant',
    from: '할매손 국밥집',
    color: 0xFFF97316,
    after: 'mukbang',
    minFollowers: 1000,
    chance: 0.2,
    text: (s) => '먹방 너무 맛있게 드셔서 연락드려요 ㅎㅎ 저희 가게 와서 한 번 드셔 주시면 음식값은 당연히 무료고 ${won(scaleMoney(s, 100000))} 사례할게요!',
    accept: '방문 먹방 수락',
    fx: (s) => Fx(money: scaleMoney(s, 100000), followers: 0.02, energy: -10, mental: 3),
    result: '국밥 세 그릇을 비웠다. 영상이 나간 뒤 가게 앞에 줄이 생겼다는 소식이 들려왔다.',
    declined: '"언제든 놀러 오세요~" 사장님이 웃는 이모티콘을 보냈다.',
  ),
  DmOffer(
    id: 'brand_deal',
    from: '글로우업 코스메틱',
    color: 0xFFEC4899,
    after: null,
    minFollowers: 10000,
    chance: 0.07,
    text: (s) => '{name}님 이미지가 저희 브랜드와 딱 맞아서요! 신제품 협찬 영상 한 편에 ${won(scaleMoney(s, 400000))} 제안드립니다 ✨',
    accept: '협찬 수락',
    fx: (s) => Fx(money: scaleMoney(s, 400000), image: 1, energy: -10),
    result: '협찬 영상을 올렸다. "광고인데 솔직해서 좋다"는 댓글이 많았다.',
    declined: '"다음 시즌에 다시 연락드릴게요!"',
  ),
  DmOffer(
    id: 'rival_collab',
    from: '찐텐형',
    color: 0xFF22C55E,
    after: null,
    minFollowers: 500,
    chance: 0.05,
    text: (s) => '{name}님 요즘 방송 잘 보고 있어요 ㅋㅋ 다음 주에 같이 합방 한 번 하실래요? 시청자들 좋아할 것 같은데!',
    accept: '합방 수락',
    fx: (s) => const Fx(followers: 0.05, energy: -15, mental: 4),
    result: '찐텐형과 합방을 했다. 서로의 시청자들이 오가며 채팅창이 터졌다.',
    declined: '"ㅇㅋㅇㅋ 언제든 연락 줘요!"',
    sns: const SnsTopic(
      tag: '{name}_찐텐형_합방',
      headline: '{name} × 찐텐형 깜짝 합방… 시청자 폭주',
      tone: 0.5,
      hate: ['찐텐형 버스 탔네', '합방 텐션 따라가느라 힘들어 보임'],
      shield: ['둘이 케미 미쳤다', '합방 정규 편성 가자', '{name} 안 밀리던데'],
      neutral: ['다음 합방 언제?'],
    ),
  ),
];

DmOffer dmOfferOf(String id) => dmOffers.firstWhere((o) => o.id == id);

/// 말실수·논란 뒤에 오는 욕 DM
const dmHate = [
  '야 너 방송에서 그런 말 해도 되냐?',
  '진짜 실망이다. 구독 취소함',
  '사과문 쓸 시간에 반성이나 해라',
  '너 같은 게 무슨 방송을 함',
  '그 말 캡처해 뒀다 평생 박제할 거임',
  '팬이었는데 이제 안티 됨',
  '방송 접어라 진심으로',
  '돈 벌더니 사람이 변했네',
  '니 방송 보는 애들 다 수준 알겠다',
  '이번 일 절대 안 잊음',
];

/// 좋은 방송 뒤에 오는 응원 DM
const dmFan = [
  '{name}님 방송 보고 하루가 행복해졌어요 ㅠㅠ',
  '힘든 시기였는데 {name} 덕분에 많이 웃었어요',
  '오늘 방송 레전드였어요!! 다음 방송 기다릴게요',
  '처음 들어왔는데 바로 구독했어요 ㅎㅎ',
  '항상 응원해요! 아프지 말고 오래 방송해 주세요',
  '{name}님 보고 저도 방송 시작했어요!',
  '시험 끝나고 {name} 방송 보는 게 유일한 낙이에요',
];

/// 자숙 중에 오는 응원 DM
const dmComfort = [
  '실수할 수도 있죠. 기다릴게요',
  '반성하는 모습 보기 좋았어요. 꼭 돌아와 주세요',
  '{name}님 없으니까 허전해요 ㅠ',
];

// ───── 방송 중 시청자 질문 ─────
class ChatAnswer {
  const ChatAnswer(this.label, this.reactions, {this.fx = const Fx(), this.core = 0, this.hype = 0});
  final String label;

  /// 대답 뒤 채팅창 반응
  final List<String> reactions;
  final Fx fx;

  /// 찐팬 변화 (구독자 대비 %가 아니라 명 단위 비율: core × 구독자/100)
  final int core;

  /// 방송 분위기 (채팅 반응 성공처럼 결과를 키운다)
  final int hype;
}

class ChatQuestion {
  const ChatQuestion(this.id, this.question, this.answers, {this.min = 0});
  final String id;
  final String question;
  final List<ChatAnswer> answers;

  /// 구독자 수가 이만큼 되어야 나온다
  final int min;
}

const chatQuestions = [
  ChatQuestion('age', '근데 나이 몇 살이에요??', [
    ChatAnswer('솔직하게 말한다', ['오 생각보다 어리다', '동갑이네요!!', '솔직해서 좋음'], core: 2),
    ChatAnswer('"영원한 열일곱 살~"', ['ㅋㅋㅋㅋㅋㅋ', '17살 n년차', '주민등록증 보여주세요 ㅋㅋ'], hype: 1),
    ChatAnswer('"그건 비밀이에요"', ['궁금한데…', '비밀 많네', 'ㅇㅋㅇㅋ'], fx: Fx(image: -1)),
  ]),
  ChatQuestion('dating', '애인 있어요??? 솔직히 말해주세요', [
    ChatAnswer('"여러분이 제 애인이죠~"', ['꺄아아악', '심쿵', '나만의 애인 ㅠㅠ'], core: 3, hype: 1),
    ChatAnswer('"지금은 없어요"', ['오 ㄹㅇ?', '다행이다 ㅋㅋ', '그럼 저랑…'], core: 1),
    ChatAnswer('"사실… 있어요"', ['헐', '축하해요!!', '실망이다…'], fx: Fx(image: 3, followers: -0.01, heat: 3)),
  ]),
  ChatQuestion('income', '방송으로 한 달에 얼마 벌어요?', [
    ChatAnswer('대충 공개한다', ['헐 생각보다 많다', '부럽다…', '나도 방송할까'], fx: Fx(heat: 4), hype: 1),
    ChatAnswer('"여러분 덕분에 밥은 먹어요"', ['겸손 ㅋㅋ', '앞으로 더 벌어요!', '후원 각'], core: 2),
    ChatAnswer('못 본 척 넘어간다', ['읽씹 ㅋㅋ', '민감한 질문이었나', '패스~'], fx: Fx()),
  ]),
  ChatQuestion('politics', '이번 선거 누구 뽑아요?', [
    ChatAnswer('솔직하게 대답한다', ['아…', '그쪽이야?', '방송 나감'], fx: Fx(heat: 12, followers: -0.01, image: -3), hype: 1),
    ChatAnswer('"방송에선 정치 얘기 안 해요"', ['프로답다', '현명함', '그게 맞지'], fx: Fx(image: 2)),
    ChatAnswer('"저는 치킨 당입니다"', ['ㅋㅋㅋㅋ', '치킨당 입당합니다', '센스 보소'], hype: 1, core: 1),
  ], min: 300),
  ChatQuestion('rival', '찐텐형 방송 어때요? 솔직히', [
    ChatAnswer('칭찬한다', ['훈훈하다', '합방 해 주세요!', '인성 굿'], fx: Fx(image: 2)),
    ChatAnswer('"솔직히 좀 시끄럽죠 ㅋㅋ"', ['ㅋㅋㅋ 저격?', '클립 땄다', '찐텐형 팬 화남'], fx: Fx(heat: 8), hype: 2),
    ChatAnswer('"누군지 잘 몰라요"', ['모르는 척 ㅋㅋ', '설마', '진짜 모름?'], fx: Fx(heat: 2)),
  ], min: 500),
  ChatQuestion('event', '구독자 이벤트 해 주세요!!!', [
    ChatAnswer('"이번 주에 바로 할게요!"', ['오예!!', '역시 최고', '약속했다?'], fx: Fx(money: -20000), core: 4),
    ChatAnswer('"구독자 목표 달성하면 할게요"', ['좋아 목표 달성 간다', '영업 시작', 'ㄱㄱ'], core: 1, hype: 1),
    ChatAnswer('"다음에~"', ['맨날 다음에래', '아쉽다', '언젠간 하겠지'], fx: Fx(image: -1)),
  ]),
  ChatQuestion('sing', '노래 한 소절만 불러 주세요!!', [
    ChatAnswer('부른다', ['오 잘 부르는데?', '귀 호강', '한 곡 더!'], fx: Fx(energy: -5), hype: 1, core: 1),
    ChatAnswer('"저 음치예요…" 하고 부른다', ['ㅋㅋㅋㅋㅋ 음치 맞네', '귀엽다', '용기에 박수'], hype: 2),
    ChatAnswer('거절한다', ['아쉽…', '다음엔 꼭', 'ㅠㅠ'], fx: Fx()),
  ]),
  ChatQuestion('late', '오늘 왜 늦게 켰어요? 기다렸잖아요', [
    ChatAnswer('"기다리게 해서 미안해요!"', ['괜찮아요~', '기다린 보람 있다', '빨리 시작해요'], core: 2),
    ChatAnswer('"늦잠 잤어요 ㅎㅎ"', ['ㅋㅋㅋ 솔직', '부럽다 늦잠', '귀엽게 봐 줌'], hype: 1),
    ChatAnswer('"제 맘이죠~"', ['오 당당', '건방져 ㅋㅋ', '좀 서운함'], fx: Fx(image: -2), hype: 1),
  ]),
  ChatQuestion('birthday', '저 오늘 생일이에요!! 축하해 주세요ㅠㅠ', [
    ChatAnswer('생일 축하 노래를 불러 준다', ['감동이다 ㅠㅠ', '나도 생일인데!!', '이런 스트리머 어디 없음'], core: 3, hype: 1),
    ChatAnswer('채팅으로 축하해 준다', ['생축!!', '🎂🎂🎂', '축하해요~'], core: 1),
    ChatAnswer('"저도 오늘 생일인데요?" 장난친다', ['진짜요?? ㅋㅋ', '거짓말 ㄴㄴ', '아 장난이구나'], hype: 1, fx: Fx(image: -1)),
  ]),
  ChatQuestion('hater', '[악플] 방송 노잼이네 시간 아까움', [
    ChatAnswer('재치 있게 받아친다', ['ㅋㅋㅋㅋㅋ 사이다', '참교육', '클립각'], hype: 2, fx: Fx(heat: 3)),
    ChatAnswer('무시하고 방송한다', ['무시가 답', '멘탈 갑', '신경 쓰지 마요'], core: 1),
    ChatAnswer('강퇴한다', ['잘 가~', '깔끔', '매니저 일 잘하네'], core: 1, fx: Fx(mental: 2)),
  ]),
  ChatQuestion('home', '고향 어디예요? 사투리 써 주세요!', [
    ChatAnswer('사투리를 쓴다', ['ㅋㅋㅋ 찐이다', '고향 사람 손!', '사투리 귀여움'], hype: 1, core: 1),
    ChatAnswer('"서울 토박이예요"', ['ㅇㅎ', '서울 사람이었구나', '노잼 ㅋㅋ'], fx: Fx()),
    ChatAnswer('"개인 정보는 비밀!"', ['조심성 굿', '그래 그게 맞다', '사생팬 조심'], fx: Fx(image: 1)),
  ], min: 100),
];

// ───── 오늘의 미션 ─────
class MissionKind {
  const MissionKind(this.id, this.icon, this.label);
  final String id;
  final String icon;

  /// {n}은 목표 수치
  final String label;
}

const missionKinds = [
  MissionKind('stream', '📺', '방송 {n}번 하기'),
  MissionKind('night', '🌙', '밤 방송 하기'),
  MissionKind('gain', '👥', '구독자 {n}명 늘리기'),
  MissionKind('donation', '💰', '후원 {n} 받기'),
  MissionKind('react', '💬', '채팅 반응 {n}번 성공'),
  MissionKind('question', '🙋', '시청자 질문에 대답하기'),
  MissionKind('upload', '✂️', '영상 업로드 하기'),
  MissionKind('rest', '🛋️', '휴식으로 멘탈 챙기기'),
];

MissionKind missionKindOf(String id) => missionKinds.firstWhere((k) => k.id == id);

// ───── 사업 ─────
class Business {
  const Business(this.id, this.name, this.icon, this.minFollowers, this.cost, this.base, this.perFan, this.desc);
  final String id;
  final String name;
  final String icon;
  final int minFollowers;
  final int cost;

  /// 하루 수입 = base + 구독자 × perFan (이미지·논란에 따라 오르내림)
  final int base;
  final double perFan;
  final String desc;
}

const businesses = [
  Business('goods', '굿즈샵', '🛍️', 10000, 3000000, 50000, 1.0, '내 캐릭터 굿즈를 파는 온라인 샵. 매일 조금씩 팔린다.'),
  Business('cafe', '팬 카페', '☕', 100000, 20000000, 300000, 1.0, '팬들이 찾아오는 내 이름의 카페. 성지 순례 코스.'),
  Business('beauty', '뷰티 브랜드', '💄', 300000, 60000000, 500000, 2.0, '내 이름을 건 화장품. 이미지가 좋을수록 잘 팔린다.'),
  Business('agency', '크리에이터 회사', '🏢', 800000, 200000000, 1000000, 3.0, '후배 스트리머를 키우는 회사. 이제 나도 대표님.'),
];

Business businessOf(String id) => businesses.firstWhere((b) => b.id == id);

// ───── 업적 ─────
class Achievement {
  const Achievement(this.id, this.icon, this.title, this.desc, this.check);
  final String id;
  final String icon;
  final String title;
  final String desc;
  final bool Function(GameState s) check;
}

final achievements = <Achievement>[
  Achievement('first', '📱', '첫 방송', '스마트폰으로 첫 방송을 켰다', (s) => s.streams >= 1),
  Achievement('silver', '🥈', '실버 버튼', '구독자 1만 명', (s) => s.followers >= 10000),
  Achievement('gold', '🥇', '골드 버튼', '구독자 10만 명', (s) => s.followers >= 100000),
  Achievement('diamond', '💎', '다이아 버튼', '구독자 100만 명', (s) => s.followers >= 1000000),
  Achievement('viral', '🚀', '알고리즘의 선택', '방송이 떡상했다', (s) => s.flags.contains('viral')),
  Achievement('penthouse', '🏙️', '반지하에서 펜트하우스로', '펜트하우스에 입주했다', (s) => s.house == 'penthouse'),
  Achievement('rank1', '👑', '스트리머 1위', '인기 순위 1위를 찍었다', (s) => s.lastRanks['me'] == 1),
  Achievement('fired', '🚫', '알바 해고 엔딩', '알바 브이로그 찍다가 잘렸다', (s) => s.flags.contains('fired')),
  Achievement('hiatus', '🙇', '자숙의 시간', '사과하고 3주 자숙했다', (s) => s.flags.contains('hiatus')),
  Achievement('cleared', '⚖️', '무혐의', '갑질 고소에서 무혐의를 받았다', (s) => s.flags.contains('staff_gapjilWon')),
  Achievement('truth', '📂', '진실은 밝혀진다', '학폭 의혹이 허위로 밝혀졌다', (s) => s.flags.contains('school_violenceWon')),
  Achievement('idol', '🎤', '아이돌과 한 무대', '아이돌 소속사 콜라보를 했다', (s) => s.flags.contains('offer_idol_collab')),
  Achievement('tv', '📡', '공중파 스타', '공중파 예능에 출연했다', (s) => s.flags.contains('idol_variety#0') || s.flags.contains('idol_variety#1')),
  Achievement('team', '🧑‍🤝‍🧑', '우리 팀', '편집자와 매니저를 모두 고용했다', (s) => s.staff.length >= 2),
  Achievement('boss', '🛍️', '사업가', '첫 사업을 열었다', (s) => s.business.isNotEmpty),
  Achievement('tycoon', '🏢', '재벌 스트리머', '사업을 3개 이상 운영했다', (s) => s.business.length >= 3),
  Achievement('core', '💖', '찐팬 부자', '찐팬 1만 명', (s) => s.coreFans >= 10000),
  Achievement('promise', '📅', '약속은 지킨다', '방송 예고를 10번 지켰다', (s) => s.schedKept >= 10),
  Achievement('missions', '🎯', '미션 마스터', '오늘의 미션 30개 완료', (s) => s.missionsDone >= 30),
  Achievement('mom', '👩', '어머님 팬클럽', '엄마를 방송에 소개했다', (s) => s.flags.contains('family_intrude#0')),
  Achievement('pet', '🐾', '랜선 집사', '반려동물을 분양했다', (s) => s.pet != null),
  Achievement('fashion', '👗', '패셔니스타', '뷰티샵 아이템 5개를 모았다', (s) => s.owned.length >= 5),
];

Achievement achievementOf(String id) => achievements.firstWhere((a) => a.id == id);

// ───── 다회차 혜택 ─────
class Perk {
  const Perk(this.icon, this.text, this.need, this.unlocked);
  final String icon;
  final String text;

  /// 열리는 조건 설명
  final String need;
  final bool Function(int endings, int achievements) unlocked;
}

final perks = <Perk>[
  Perk('💰', '시작 자금 +5만 원', '엔딩 1개', (e, a) => e >= 1),
  Perk('✨', '시작 이미지 +10', '업적 5개', (e, a) => a >= 5),
  Perk('📷', '웹캠을 들고 시작', '엔딩 3개', (e, a) => e >= 3),
  Perk('💖', '찐팬 20명·구독자 50명으로 시작', '업적 10개', (e, a) => a >= 10),
  Perk('🎙️', '핀 마이크를 들고 시작', '엔딩 5개', (e, a) => e >= 5),
  Perk('🏠', '원룸에서 시작', '업적 15개', (e, a) => a >= 15),
];

// ───── 뷰티샵 (헤어·염색·옷·액세서리) ─────
class StyleItem {
  const StyleItem(this.id, this.kind, this.name, this.price, {this.value = '', this.color = 0, this.accent = 0, this.bonus = 0, this.desc = ''});
  final String id;

  /// hair(머리 모양) / dye(염색) / outfit(옷) / acc(액세서리)
  final String kind;
  final String name;
  final int price;

  /// 머리 모양·옷 무늬·액세서리 이름
  final String value;

  /// 염색 색, 옷 색 (0이면 처음 고른 색)
  final int color;

  /// 옷의 포인트 색 (넥타이, 벨트 등)
  final int accent;

  /// 방송 품질 보너스 (시청자 수에 곱해진다)
  final double bonus;
  final String desc;
}

const styleItems = [
  StyleItem('hair_short', 'hair', '숏컷', 0, value: 'short', desc: '기본 머리'),
  StyleItem('hair_long', 'hair', '장발', 0, value: 'long', desc: '기본 머리'),
  StyleItem('hair_bob', 'hair', '보브컷', 50000, value: 'bob', bonus: 0.01, desc: '앞머리를 내린 단정한 단발'),
  StyleItem('hair_pony', 'hair', '포니테일', 50000, value: 'pony', bonus: 0.01, desc: '발랄하게 묶은 머리'),
  StyleItem('hair_twoblock', 'hair', '투블럭', 80000, value: 'twoblock', bonus: 0.02, desc: '옆을 짧게 쳐 올린 머리'),
  StyleItem('hair_spiky', 'hair', '뾰족머리', 80000, value: 'spiky', bonus: 0.02, desc: '왁스로 세운 머리'),
  StyleItem('dye_black', 'dye', '흑발', 20000, color: 0x2A2230),
  StyleItem('dye_brown', 'dye', '갈색', 30000, color: 0x6B4226),
  StyleItem('dye_blond', 'dye', '금발', 60000, color: 0xE8C66A, bonus: 0.01),
  StyleItem('dye_pink', 'dye', '핑크', 100000, color: 0xF58BB0, bonus: 0.02),
  StyleItem('dye_mint', 'dye', '민트', 100000, color: 0x7FD8C8, bonus: 0.02),
  StyleItem('dye_silver', 'dye', '은발', 150000, color: 0xD8DCE6, bonus: 0.03),
  StyleItem('outfit_tee', 'outfit', '기본 티셔츠', 0, value: 'tee', desc: '처음부터 입던 옷'),
  StyleItem('outfit_hoodie', 'outfit', '후드티', 80000, value: 'hoodie', color: 0x8C95A8, bonus: 0.01, desc: '편한 게 최고'),
  StyleItem('outfit_shirt', 'outfit', '셔츠', 120000, value: 'shirt', color: 0x9CC3F0, bonus: 0.02, desc: '깔끔한 첫인상'),
  StyleItem('outfit_training', 'outfit', '트레이닝복', 150000, value: 'training', color: 0x2E6B4F, bonus: 0.02, desc: '양옆에 흰 줄'),
  StyleItem('outfit_dress', 'outfit', '원피스', 200000, value: 'dress', color: 0xE89BC0, bonus: 0.03, desc: '하늘하늘한 원피스'),
  StyleItem('outfit_pajama', 'outfit', '고양이 잠옷', 300000, value: 'pajama', color: 0xF3E0EA, accent: 0xFF9FC0, bonus: 0.03, desc: '침대에서 바로 방송한 느낌'),
  StyleItem('outfit_suit', 'outfit', '정장', 500000, value: 'suit', color: 0x2E3448, accent: 0xE8463C, bonus: 0.04, desc: '시상식에도 문제없다'),
  StyleItem('outfit_stage', 'outfit', '아이돌 무대의상', 2000000, value: 'stage', color: 0xF4F4F4, accent: 0xF2C14E, bonus: 0.07, desc: '반짝이는 금장 포인트'),
  StyleItem('acc_none', 'acc', '없음', 0, value: 'none', desc: '액세서리 빼기'),
  StyleItem('acc_glasses', 'acc', '뿔테 안경', 50000, value: 'glasses', bonus: 0.01, desc: '지적인 분위기'),
  StyleItem('acc_sunglasses', 'acc', '선글라스', 100000, value: 'sunglasses', bonus: 0.01, desc: '실내에서도 쓴다'),
  StyleItem('acc_cap', 'acc', '캡모자', 80000, value: 'cap', bonus: 0.01, desc: '빨간 야구모자'),
  StyleItem('acc_catears', 'acc', '고양이 귀 머리띠', 150000, value: 'catears', bonus: 0.02, desc: '방송용 필수템'),
  StyleItem('acc_headset', 'acc', '게이밍 헤드셋', 300000, value: 'headset', bonus: 0.03, desc: '초록 불빛이 나는 헤드셋'),
];

/// 처음부터 가진 아이템
const freeStyles = {'hair_short', 'hair_long', 'outfit_tee', 'acc_none'};

StyleItem styleOf(String id) => styleItems.firstWhere((x) => x.id == id);

/// 아이템을 입혀 본 모습
Look tryOn(Look look, StyleItem it) => switch (it.kind) {
      'hair' => look.copyWith(style: it.value, long: it.value == 'long'),
      'dye' => look.copyWith(hair: it.color),
      'outfit' => look.copyWith(outfit: it.value),
      _ => look.copyWith(acc: it.value),
    };

/// 지금 입은 것 중 이 아이템을 착용 중인지
bool wearing(Look look, StyleItem it) => switch (it.kind) {
      'hair' => look.hairStyle == it.value,
      'dye' => look.hair == it.color,
      'outfit' => look.outfit == it.value,
      _ => look.acc == it.value,
    };

StyleItem? _outfitItem(String v) => styleItems.where((x) => x.kind == 'outfit' && x.value == v).firstOrNull;

/// 옷 색 (기본 티셔츠는 처음 고른 색)
int outfitColor(Look look) {
  final it = _outfitItem(look.outfit);
  return it == null || it.color == 0 ? look.shirt : it.color;
}

int outfitAccent(Look look) => _outfitItem(look.outfit)?.accent ?? 0xF2C14E;

/// 꾸밈새 보너스 (방송 품질에 더해진다)
double styleBonus(Look look) {
  double b = 0;
  for (final it in styleItems) {
    if (it.bonus > 0 && it.kind != 'dye' && wearing(look, it)) b += it.bonus;
  }
  for (final it in styleItems.where((x) => x.kind == 'dye' && x.color == look.hair)) {
    b += it.bonus;
  }
  return b;
}

// ───── 펫샵 ─────
class Pet {
  const Pet(this.id, this.name, this.icon, this.price, this.food, this.body, this.shade, this.desc);
  final String id;
  final String name;
  final String icon;
  final int price;

  /// 하루 사료·간식비
  final int food;
  final int body;
  final int shade;
  final String desc;
}

const pets = [
  Pet('hamster', '햄스터', '🐹', 200000, 3000, 0xE8C08A, 0xFFF4E2, '작고 동그란 친구. 쳇바퀴 소리가 ASMR이다.'),
  Pet('cat', '고양이', '🐱', 1000000, 10000, 0xF29B4B, 0xC66F2A, '키보드 위를 걸어 다니는 게 취미.'),
  Pet('dog', '강아지', '🐶', 1000000, 10000, 0xB07A4A, 0x7A5030, '방송 중에도 꼬리를 흔든다. 가끔 짖는다.'),
];

Pet petOf(String id) => pets.firstWhere((p) => p.id == id);

const snsPet = SnsTopic(
  tag: '{name}_반려동물',
  headline: '{name} 방송에 등장한 반려동물에 시청자 심쿵',
  tone: 0.8,
  hate: ['동물로 시청자 끄는 건 좀…', '동물 학대 아님?'],
  shield: ['너무 귀여워 ㅠㅠ', '매일 보여 주세요', '이 방송은 펫이 주인공임', '랜선 집사 됨'],
  neutral: ['이름이 뭐예요?', '품종 궁금'],
);
