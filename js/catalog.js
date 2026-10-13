/*
 * 사이트 콘텐츠 목록 — 상단 메뉴와 "다른 콘텐츠" 목록이 이 순서대로 만들어집니다.
 * 새 게임북·테스트·퀴즈를 만들면 여기에 한 줄 추가하세요.
 *
 * type: "puzzle"(퍼즐) | "story"(게임북) | "test"(심리테스트) | "quiz"(퀴즈)
 */
const SITE_CATALOG = [
  { type: "puzzle", id: "sudoku", title: "스도쿠", href: "sudoku.html", desc: "매번 새로 나오는 문제, 쉬움부터 어려움까지" },
  { type: "puzzle", id: "crossword", title: "십자말풀이", href: "crossword.html", desc: "쉬운 단어로 가볍게 푸는 한글 십자말풀이" },
  { type: "quiz", id: "spelling", title: "헷갈리는 맞춤법 퀴즈", href: "quiz.html#spelling", desc: "10문제, 당신의 맞춤법 실력은?" },
  { type: "story", id: "mansion", title: "자정의 저택", href: "index.html#mansion", desc: "자정까지 48분. 엔딩 31개의 텍스트 게임북" },
];

const CATALOG_LABELS = { puzzle: "퍼즐", story: "게임북", test: "테스트", quiz: "퀴즈" };
