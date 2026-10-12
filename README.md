# 게임북

선택에 따라 이야기가 갈라지는 텍스트 게임북 사이트입니다. 빌드 도구 없이 `index.html`을 브라우저로 열면 바로 실행됩니다.

## 구조
- `js/story.js`: 스토리 데이터 (장면, 선택지, 아이템, 엔딩)
- `js/engine.js`: 게임 엔진 (장면 표시, 아이템, 저장/이어하기, 엔딩 도감)
- `css/style.css`: 스타일 (다크모드, 모바일 대응)

## 스토리 작성법
`js/story.js`의 `scenes`에 장면을 추가합니다.

```js
hall: {
  text: ["문단 1", "문단 2"],
  gives: ["손전등"],                 // 도착 시 얻는 아이템 (선택)
  choices: [
    { label: "지하로 간다", next: "basement", requires: ["손전등"] }, // 아이템이 있어야 보임
    { label: "어둠 속으로", next: "end_fall", excludes: ["손전등"] }, // 아이템이 있으면 숨김
  ],
},
end_fall: {
  ending: { title: "어둠 속 계단", type: "bad" },  // good | normal | bad
  text: ["..."],
},
```
