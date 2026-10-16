// 인플루언서 시뮬레이터 — 게임 데이터
//
// 장비, 꾸미기, 방송 종류, 이벤트, SNS 반응 문구를 모아 둔 파일.
// 문구 안의 {name}은 플레이어가 정한 방송 닉네임으로 바뀐다.

import 'dart:math';

import 'game_state.dart';

const seasonDays = 60;
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
  Rank(1000, '떠오르는 크리에이터'),
  Rank(10000, '중소 인플루언서'),
  Rank(100000, '인기 인플루언서'),
  Rank(500000, '대형 인플루언서'),
  Rank(1000000, '셀럽'),
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
  Milestone(1000000, '다이아 버튼 도착!', '구독자 100만 명. 이제 당신은 명실상부 셀럽이다.'),
];

// ───── 방송 중 채팅 ─────
const chatLines = <String, List<String>>{
  'any': ['ㅋㅋㅋㅋㅋ', '하이요~', 'ㅎㅇㅎㅇ', '오늘 텐션 좋네', '첫 방문입니다!', '{name} 왔다', 'ㄹㅇㅋㅋ', '아 개웃겨', '출첵', 'ㅇㅈ', '와 진짜?', '😂😂😂', '👍', '구독 박고 갑니다', '알림 보고 옴'],
  'talk': ['썰 더 풀어줘요', '그래서 그 다음엔?', '목소리 좋다', '공감 100%'],
  'study': ['오늘도 같이 공부해요', '📖', '집중!', '저 시험 3일 남음...'],
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
  const Fx({this.money = 0, this.followers = 0, this.image = 0, this.heat = 0, this.mental = 0, this.energy = 0, this.flag, this.unflag});
  final int money;
  final double followers;
  final int image;
  final int heat;
  final int mental;
  final int energy;
  final String? flag;
  final String? unflag;
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
  const EventChoice({required this.label, required this.result, required this.fx, this.sns});
  final String label;
  final String result;
  final Fx Function(GameState s) fx;
  final SnsTopic? sns;
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

  /// 'live'(방송 중) 또는 'news'(아침에 터지는 소식)
  final String where;
  final String title;
  final int weight;
  final bool Function(GameState s) when;
  final String Function(GameState s) text;
  final List<EventChoice> choices;
}

Fx _none(GameState s) => const Fx();

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

  // 초반: 대형 인플루언서가 방송에 깜짝 등장
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

  // 초반: 대형 인플루언서와의 합방 초대
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

  // 대형 인플루언서: 팬미팅
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

  // 대형 인플루언서: 예능 출연
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

  // 대형 인플루언서: 시상식
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
  'celeb_good': Ending('국민 인플루언서', 'true', "구독자 100만, 그리고 좋은 평판. 광고 섭외가 줄을 잇고, 사람들은 당신을 '믿고 보는 방송인'이라 부른다."),
  'celeb_bad': Ending('악명 높은 셀럽', 'normal', "구독자 100만을 넘었지만 당신 이름 옆에는 늘 '논란'이 붙어 다닌다. 그래도 사람들은 계속 본다."),
  'big': Ending('인기 인플루언서', 'good', '10만 명이 넘는 사람들이 당신의 방송을 기다린다. 방구석에서 시작한 방송이 이제는 직업이 되었다.'),
  'mid': Ending('중소 인플루언서', 'good', '1만 명의 구독자와 함께하는 아담한 방송. 화려하진 않지만 단단하다.'),
  'small': Ending('소소한 방송인', 'normal', '구독자는 많지 않지만, 매일 찾아오는 고정 시청자들이 있다. 방송은 계속된다.'),
  'zero': Ending('방구석 방송인', 'bad', '60일이 지났지만 방송을 보는 사람은 손에 꼽는다. 스마트폰을 내려놓고 이력서를 열었다.'),
};
