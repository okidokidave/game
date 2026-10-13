/*
 * 십자말풀이 문제
 * tools/gen_cross.py 로 만들었습니다. (단어와 단서는 tools/words.py)
 *
 * 문제 형식: { rows, cols, entries: [{ n: 번호, dir: "across"(가로) | "down"(세로), row, col, answer, clue }] }
 */
window.CROSSWORDS = [
 {
  "rows": 5,
  "cols": 5,
  "entries": [
   {
    "n": 1,
    "dir": "across",
    "row": 0,
    "col": 1,
    "answer": "단풍",
    "clue": "가을에 붉고 노랗게 물드는 잎"
   },
   {
    "n": 4,
    "dir": "across",
    "row": 1,
    "col": 2,
    "answer": "선물",
    "clue": "생일에 주고받는 것"
   },
   {
    "n": 6,
    "dir": "across",
    "row": 2,
    "col": 0,
    "answer": "개미",
    "clue": "부지런함의 상징인 작은 곤충"
   },
   {
    "n": 8,
    "dir": "across",
    "row": 2,
    "col": 3,
    "answer": "고추",
    "clue": "맵기로 유명한 빨간 채소"
   },
   {
    "n": 9,
    "dir": "across",
    "row": 3,
    "col": 1,
    "answer": "소나기",
    "clue": "갑자기 세차게 쏟아지다 금방 그치는 비"
   },
   {
    "n": 2,
    "dir": "down",
    "row": 0,
    "col": 2,
    "answer": "풍선",
    "clue": "바람을 넣어 부풀리는 놀잇감"
   },
   {
    "n": 3,
    "dir": "down",
    "row": 1,
    "col": 0,
    "answer": "조개",
    "clue": "껍데기 두 장으로 몸을 감싼 바다 생물"
   },
   {
    "n": 5,
    "dir": "down",
    "row": 1,
    "col": 3,
    "answer": "물고기",
    "clue": "물속에 사는, 지느러미가 있는 동물"
   },
   {
    "n": 7,
    "dir": "down",
    "row": 2,
    "col": 1,
    "answer": "미소",
    "clue": "소리 없이 빙긋 짓는 웃음"
   },
   {
    "n": 10,
    "dir": "down",
    "row": 3,
    "col": 2,
    "answer": "나비",
    "clue": "꽃 사이를 팔랑팔랑 나는 곤충"
   }
  ]
 },
 {
  "rows": 5,
  "cols": 6,
  "entries": [
   {
    "n": 1,
    "dir": "across",
    "row": 0,
    "col": 0,
    "answer": "도시",
    "clue": "사람이 많이 모여 사는 큰 고장"
   },
   {
    "n": 2,
    "dir": "across",
    "row": 1,
    "col": 4,
    "answer": "자두",
    "clue": "새콤한 보랏빛 여름 과일"
   },
   {
    "n": 3,
    "dir": "across",
    "row": 2,
    "col": 0,
    "answer": "관광",
    "clue": "경치나 명소를 구경하러 다니는 것"
   },
   {
    "n": 5,
    "dir": "across",
    "row": 2,
    "col": 3,
    "answer": "오리",
    "clue": "꽥꽥 우는 물새"
   },
   {
    "n": 6,
    "dir": "across",
    "row": 3,
    "col": 1,
    "answer": "고양이",
    "clue": "야옹 하고 우는 동물"
   },
   {
    "n": 1,
    "dir": "down",
    "row": 0,
    "col": 0,
    "answer": "도서관",
    "clue": "책을 빌려 읽을 수 있는 곳"
   },
   {
    "n": 2,
    "dir": "down",
    "row": 1,
    "col": 4,
    "answer": "자리",
    "clue": "앉는 곳"
   },
   {
    "n": 4,
    "dir": "down",
    "row": 2,
    "col": 1,
    "answer": "광고",
    "clue": "상품을 널리 알리는 것"
   },
   {
    "n": 5,
    "dir": "down",
    "row": 2,
    "col": 3,
    "answer": "오이",
    "clue": "길쭉한 초록 채소"
   },
   {
    "n": 7,
    "dir": "down",
    "row": 3,
    "col": 2,
    "answer": "양말",
    "clue": "신발 신기 전에 발에 신는 것"
   }
  ]
 },
 {
  "rows": 6,
  "cols": 6,
  "entries": [
   {
    "n": 2,
    "dir": "across",
    "row": 1,
    "col": 0,
    "answer": "건강",
    "clue": "몸과 마음이 튼튼한 상태"
   },
   {
    "n": 5,
    "dir": "across",
    "row": 3,
    "col": 0,
    "answer": "무지개",
    "clue": "비 갠 뒤 하늘에 뜨는 일곱 빛깔 띠"
   },
   {
    "n": 7,
    "dir": "across",
    "row": 3,
    "col": 4,
    "answer": "기자",
    "clue": "취재해서 기사를 쓰는 사람"
   },
   {
    "n": 8,
    "dir": "across",
    "row": 4,
    "col": 2,
    "answer": "구급차",
    "clue": "환자를 싣고 달리는 차"
   },
   {
    "n": 9,
    "dir": "across",
    "row": 5,
    "col": 0,
    "answer": "도토리",
    "clue": "다람쥐가 좋아하는 열매"
   },
   {
    "n": 1,
    "dir": "down",
    "row": 0,
    "col": 0,
    "answer": "수건",
    "clue": "몸의 물기를 닦는 천"
   },
   {
    "n": 3,
    "dir": "down",
    "row": 1,
    "col": 1,
    "answer": "강아지",
    "clue": "개의 새끼"
   },
   {
    "n": 4,
    "dir": "down",
    "row": 2,
    "col": 5,
    "answer": "과자",
    "clue": "바삭바삭한 간식"
   },
   {
    "n": 6,
    "dir": "down",
    "row": 3,
    "col": 2,
    "answer": "개구리",
    "clue": "올챙이가 자란 동물"
   },
   {
    "n": 7,
    "dir": "down",
    "row": 3,
    "col": 4,
    "answer": "기차",
    "clue": "철길 위를 달리는 긴 탈것"
   }
  ]
 },
 {
  "rows": 6,
  "cols": 6,
  "entries": [
   {
    "n": 1,
    "dir": "across",
    "row": 0,
    "col": 2,
    "answer": "정원",
    "clue": "집 안에 꽃과 나무를 가꾸는 뜰"
   },
   {
    "n": 3,
    "dir": "across",
    "row": 2,
    "col": 3,
    "answer": "이사",
    "clue": "사는 곳을 옮기는 것"
   },
   {
    "n": 5,
    "dir": "across",
    "row": 3,
    "col": 0,
    "answer": "자전거",
    "clue": "페달을 밟아 달리는 두 바퀴 탈것"
   },
   {
    "n": 7,
    "dir": "across",
    "row": 3,
    "col": 4,
    "answer": "다리",
    "clue": "강 위를 건너게 놓은 것, 또는 몸의 일부"
   },
   {
    "n": 8,
    "dir": "across",
    "row": 4,
    "col": 2,
    "answer": "울타리",
    "clue": "집이나 밭 둘레를 막아 놓은 것"
   },
   {
    "n": 2,
    "dir": "down",
    "row": 0,
    "col": 3,
    "answer": "원숭이",
    "clue": "바나나를 좋아하는, 꼬리 긴 동물"
   },
   {
    "n": 4,
    "dir": "down",
    "row": 2,
    "col": 4,
    "answer": "사다리",
    "clue": "높은 곳에 오를 때 딛는 기구"
   },
   {
    "n": 5,
    "dir": "down",
    "row": 3,
    "col": 0,
    "answer": "자동차",
    "clue": "바퀴 넷 달린, 도로 위의 탈것"
   },
   {
    "n": 6,
    "dir": "down",
    "row": 3,
    "col": 2,
    "answer": "거울",
    "clue": "얼굴을 비춰 보는 물건"
   },
   {
    "n": 9,
    "dir": "down",
    "row": 4,
    "col": 3,
    "answer": "타조",
    "clue": "날지 못하는 가장 큰 새"
   }
  ]
 },
 {
  "rows": 6,
  "cols": 6,
  "entries": [
   {
    "n": 1,
    "dir": "across",
    "row": 0,
    "col": 1,
    "answer": "두부",
    "clue": "콩으로 만든 하얗고 네모난 음식"
   },
   {
    "n": 2,
    "dir": "across",
    "row": 2,
    "col": 1,
    "answer": "지도",
    "clue": "땅의 모습을 줄여 그린 그림"
   },
   {
    "n": 5,
    "dir": "across",
    "row": 3,
    "col": 2,
    "answer": "자장가",
    "clue": "아기를 재울 때 부르는 노래"
   },
   {
    "n": 7,
    "dir": "across",
    "row": 4,
    "col": 0,
    "answer": "선풍기",
    "clue": "여름에 바람을 일으키는 가전제품"
   },
   {
    "n": 8,
    "dir": "across",
    "row": 4,
    "col": 4,
    "answer": "방학",
    "clue": "여름과 겨울에 학교가 쉬는 기간"
   },
   {
    "n": 1,
    "dir": "down",
    "row": 0,
    "col": 1,
    "answer": "두더지",
    "clue": "땅속에 굴을 파고 사는 동물"
   },
   {
    "n": 3,
    "dir": "down",
    "row": 2,
    "col": 2,
    "answer": "도자기",
    "clue": "흙으로 빚어 구운 그릇"
   },
   {
    "n": 4,
    "dir": "down",
    "row": 3,
    "col": 0,
    "answer": "생선",
    "clue": "먹으려고 잡은 물고기"
   },
   {
    "n": 6,
    "dir": "down",
    "row": 3,
    "col": 4,
    "answer": "가방",
    "clue": "물건을 넣어 메거나 들고 다니는 것"
   },
   {
    "n": 9,
    "dir": "down",
    "row": 4,
    "col": 5,
    "answer": "학교",
    "clue": "학생들이 공부하러 가는 곳"
   }
  ]
 },
 {
  "rows": 5,
  "cols": 7,
  "entries": [
   {
    "n": 1,
    "dir": "across",
    "row": 0,
    "col": 1,
    "answer": "지하철",
    "clue": "땅속을 달리는 전철"
   },
   {
    "n": 3,
    "dir": "across",
    "row": 1,
    "col": 0,
    "answer": "야구",
    "clue": "투수와 타자가 겨루는 운동"
   },
   {
    "n": 4,
    "dir": "across",
    "row": 1,
    "col": 3,
    "answer": "새우",
    "clue": "등이 굽은 바다 생물. ___깡"
   },
   {
    "n": 6,
    "dir": "across",
    "row": 2,
    "col": 4,
    "answer": "산책",
    "clue": "가볍게 걷는 일"
   },
   {
    "n": 8,
    "dir": "across",
    "row": 3,
    "col": 5,
    "answer": "상자",
    "clue": "물건을 담는 네모난 통"
   },
   {
    "n": 1,
    "dir": "down",
    "row": 0,
    "col": 1,
    "answer": "지구",
    "clue": "우리가 사는 푸른 행성"
   },
   {
    "n": 2,
    "dir": "down",
    "row": 0,
    "col": 3,
    "answer": "철새",
    "clue": "계절에 따라 옮겨 다니는 새"
   },
   {
    "n": 5,
    "dir": "down",
    "row": 1,
    "col": 4,
    "answer": "우산",
    "clue": "비가 올 때 펴서 쓰는 것"
   },
   {
    "n": 7,
    "dir": "down",
    "row": 2,
    "col": 5,
    "answer": "책상",
    "clue": "공부할 때 앞에 두는 가구"
   },
   {
    "n": 9,
    "dir": "down",
    "row": 3,
    "col": 6,
    "answer": "자석",
    "clue": "쇠붙이를 끌어당기는 물체"
   }
  ]
 }
];
