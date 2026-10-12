# 게임북

선택에 따라 이야기가 갈라지는 텍스트 게임북 사이트입니다. 빌드 도구 없이 `index.html`을 브라우저로 열면 바로 실행됩니다.

## 구조
- `js/story.js`: 스토리 데이터 (장면, 선택지, 아이템, 엔딩, 엔딩 힌트)
- `js/illustrations.js`: 장면 삽화 (SVG)
- `js/engine.js`: 게임 엔진 (장면 표시, 아이템, 저장/이어하기, 되돌리기, 사이드바)
- `js/ads.js`: Google AdSense 설정
- `css/style.css`: 스타일 (사이드바 레이아웃, 다크모드, 모바일 대응)
- `privacy.html`: 개인정보처리방침 (AdSense 승인에 필요)

## 스토리 작성법
`js/story.js`의 `scenes`에 장면을 추가합니다.

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
