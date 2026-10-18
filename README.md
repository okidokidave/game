# 게임북

선택에 따라 이야기가 갈라지는 텍스트 게임북 사이트입니다. 빌드 도구 없이 `index.html`을 브라우저로 열면 바로 실행됩니다.

## 구조
- `js/stories/*.js`: 이야기 파일 (한 파일에 이야기 하나)
  - `mansion.js`: 「자정의 저택」 장면 69개, 엔딩 30개
- `js/illustrations.js`: 장면 삽화 (SVG)
- `js/engine.js`: 게임 엔진 (장면 표시, 아이템, 저장/이어하기, 되돌리기, 사이드바)
- `js/ads.js`: Google AdSense 설정
- `css/style.css`: 스타일 (사이드바 레이아웃, 다크모드, 모바일 대응)
- `privacy.html`: 개인정보처리방침 (AdSense 승인에 필요)

## 새 이야기(게임) 추가하기
1. `js/stories/mansion.js`를 복사해 `js/stories/새이름.js`를 만들고 `id`, `title`, `intro`, `cover`, `start`, `scenes`를 고칩니다.
2. `index.html` 아래쪽 `<script src="js/stories/mansion.js">` 밑에 한 줄을 추가합니다.

상단 헤더에 바로가기 버튼이 자동으로 생기고, `index.html#새아이디` 주소로 바로 들어갈 수 있습니다. 엔딩 도감과 저장 기록은 이야기마다 따로 관리됩니다.

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

## 갑질 사장 퇴치 대작전 (퍼즐 게임 프로토타입)
`puzzle/index.html`을 열면 실행되는 매치3 퍼즐 RPG입니다. 블록을 맞춰 직장인 4명이 팀장 → 부장 → 상무 → 사장을 차례로 물리칩니다.
- `puzzle/game.js`: 게임 전체 (판, 매치 판정, 특수 블록, 보스, 스킬, 화면)
  - 직원 능력치는 `TEAM`, 보스 체력·공격·대사는 `BOSSES`에서 고칩니다.
- `puzzle/style.css`: 세로 화면 기준 스타일 (다크모드 대응)
