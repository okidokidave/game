# 게임북

선택에 따라 이야기가 갈라지는 텍스트 게임북 사이트입니다. 퍼즐, 퀴즈, 게임북을 모은 사이트입니다. 빌드 도구 없이 `index.html`을 브라우저로 열면 바로 실행됩니다.

## 구조
| 페이지 | 내용 |
|---|---|
| `index.html` | 홈: 소개, 오늘의 운세·맞춤법, 이어하기, 콘텐츠 목록 (`js/home.js`) |
| `story.html` | 게임북 (`js/engine.js`, 이야기는 `js/stories/`) |
| `sudoku.html` | 스도쿠 (`js/sudoku.js`, 문제는 매번 자동 생성) |
| `crossword.html` | 십자말풀이 (`js/crossword.js`, 문제는 `js/crosswords/`) |
| `test.html` | 심리테스트 (`js/test-engine.js`, 테스트는 `js/tests/`, 현재 없음) |
| `quiz.html` | 퀴즈 (`js/quiz-engine.js`, 퀴즈는 `js/quizzes/`) |
| `privacy.html` | 개인정보처리방침 |

공통 파일
- `js/catalog.js`: 사이트 콘텐츠 목록. 상단 메뉴와 "다른 콘텐츠" 목록이 여기서 만들어집니다.
- `js/site.js`: 저장, 알림, 설정, 메뉴, 왼쪽 칸, 삽화 그리기 등 모든 페이지 공통 기능
- `js/daily.js`: 오늘의 운세(문구·행운의 색·물건 목록)와 오늘의 맞춤법
- `js/illustrations.js`: 삽화 (SVG)
- `js/share.js`: 공유하기, `js/ads.js`: 광고 설정
- `css/style.css`: 스타일

## 새 콘텐츠 추가하기
1. 같은 종류의 기존 파일을 복사해 새 파일을 만듭니다. (예: `js/quizzes/spelling.js` → `js/quizzes/history.js`)
2. 해당 페이지 html 아래쪽의 `<script src=...>` 목록에 한 줄을 추가합니다.
3. `js/catalog.js`에 한 줄을 추가합니다. (`href`는 `quiz.html#history`처럼 `페이지#아이디`)

## 새 이야기(게임) 추가하기
게임북은 위 방법과 같고, 자세히는 다음과 같습니다.
1. `js/stories/mansion.js`를 복사해 `js/stories/새이름.js`를 만들고 `id`, `title`, `intro`, `cover`, `start`, `scenes`를 고칩니다.
2. `story.html` 아래쪽 `<script src="js/stories/mansion.js">` 밑에 한 줄을 추가합니다.

상단 헤더에 바로가기 버튼이 자동으로 생기고, `story.html#새아이디` 주소로 바로 들어갈 수 있습니다. 엔딩 도감과 저장 기록은 이야기마다 따로 관리됩니다.

## 시간 제한 (게임북)
이야기에 `clock: { start: 23 * 60 + 12, limit: 48, cost: 2, timeout: "end_midnight" }`처럼 적으면 상단에 시계가 나타나고, 선택할 때마다 시간이 흐릅니다. 제한 시간이 지나면 `timeout` 장면(엔딩)으로 갑니다. 선택지에 `time: 1`을 적으면 그 선택지만 소요 시간이 바뀝니다.

## 장면 작성법
이야기 파일의 `scenes`에 장면을 추가합니다.

```js
hall: {
  image: "hall",                     // illustrations.js의 키, 또는 "img/hall.png" 같은 이미지 경로
  text: ["문단 1", "문단 2"],
  gives: ["손전등"],                 // 도착 시 얻는 아이템 (선택)
  choices: [
    { label: "지하로 간다", next: "basement", requires: ["손전등"] }, // 아이템이 있어야 보임
    { label: "어둠 속으로", next: "end_fall", excludes: ["손전등"] }, // 아이템이 있으면 숨김
  ],
},
end_fall: {
  image: "stairs",
  ending: { title: "어둠 속 계단", type: "bad", hint: "빛 없이 내려가면 안 되는 곳이 있다." },
  text: ["..."],
},
```

## AdSense 적용
1. `privacy.html`의 문의 이메일을 채우고 사이트를 배포합니다.
2. AdSense에 사이트를 신청하고, 승인되면 `js/ads.js`에 게시자 ID와 광고 슬롯 번호를 넣습니다.
3. 사이트 루트에 `ads.txt` 파일을 만들어 AdSense가 안내하는 한 줄을 넣습니다.

## 공유하기 설정 (`js/share.js`)
| 플랫폼 | 동작 |
|---|---|
| X, 네이버 블로그·카페, 네이버 밴드 | 각 서비스의 공식 공유 창이 열림 |
| 카카오톡 | `kakaoKey`를 넣으면 카카오톡 공유 창. 없으면 휴대폰 기본 공유창, PC는 링크 복사 |
| 인스타그램, 틱톡, 다음 카페 | 웹에서 링크를 바로 올리는 공식 방법이 없어 휴대폰은 기본 공유창, PC는 링크 복사 |

- `siteUrl`: 배포한 사이트 주소. 넣지 않으면 현재 페이지 주소를 공유합니다.
- `kakaoKey`: [카카오 디벨로퍼스](https://developers.kakao.com)에서 앱을 만들고 JavaScript 키를 발급받아 넣습니다. 앱 설정 → 플랫폼 → Web에 사이트 도메인을 등록해야 합니다.
- 공유와 복사 기능은 https 주소에서만 제대로 동작합니다. 파일을 직접 열면 브라우저가 막을 수 있습니다.

## 십자말풀이 문제 만들기
`tools/words.py`에 단어와 열쇠(단서)를 추가한 뒤 아래 명령을 실행하면 서로 겹치지 않는 문제들이 만들어집니다. 만들어진 JSON을 `js/crosswords/basic.js`의 `window.CROSSWORDS = ` 뒤에 넣으면 됩니다.

```
python3 tools/gen_cross.py tools 결과.json
```

## 수정한 뒤 꼭 할 일: 버전 번호 올리기
html 파일의 css/js 주소 끝에 `?v=20261013c` 같은 버전 번호가 붙어 있습니다. css나 js를 고쳤다면 모든 html에서 이 번호를 새 값으로 바꿔 주세요. 그래야 방문자의 브라우저가 예전 파일(캐시)을 쓰지 않고 새 파일을 받아 옵니다.

## 새 소식 고치기
홈 화면 오른쪽의 "새 소식"은 `index.html`의 `<ul class="news-list">` 안에 한 줄씩 적습니다.
