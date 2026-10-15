# 게임북

선택에 따라 이야기가 갈라지는 텍스트 게임북과 인플루언서 시뮬레이터가 있는 사이트입니다. 빌드 도구 없이 `index.html`을 브라우저로 열면 바로 실행됩니다.

## 구조
- `js/stories/*.js`: 이야기 파일 (한 파일에 이야기 하나)
  - `mansion.js`: 「자정의 저택」 장면 69개, 엔딩 30개
- `js/illustrations.js`: 장면 삽화 (SVG)
- `js/engine.js`: 게임 엔진 (장면 표시, 아이템, 저장/이어하기, 되돌리기, 사이드바)
- `js/ads.js`: Google AdSense 설정
- `css/style.css`: 스타일 (사이드바 레이아웃, 다크모드, 모바일 대응)
- `privacy.html`: 개인정보처리방침 (AdSense 승인에 필요)

## 인플루언서 시뮬레이터 (`influencer.html`)
스마트폰 하나로 방송을 시작해 60일 안에 셀럽이 되는 도트 시뮬레이션입니다. 싸이월드 미니룸처럼 방의 단면을 보여주고, 돈을 벌어 장비(카메라·마이크·조명·PC)와 소품을 사면 방에 그대로 나타납니다. 방송 중 사건(악플, 뒷광고 제안, 열애설 등)에서 고른 선택은 가상 SNS "버즈"에서 악플과 쉴드가 맞붙는 토론으로 이어집니다.

- `js/influencer/data.js`: 장비, 방송 종류, 이벤트, SNS 문구, 엔딩 (내용 추가는 여기서)
- `js/influencer/rules.js`: 시청자·구독자·수익 계산 (밸런스 조절)
- `js/influencer/sns.js`: SNS 글·댓글 토론 생성
- `js/influencer/room.js`: 아이소메트릭 도트 방 그리기 (캔버스)
- `js/influencer/game.js`: 게임 진행과 화면
- `css/influencer.css`: 스타일

이벤트를 추가하려면 `data.js`의 `IF.EVENTS`에 항목을 넣으면 됩니다. 선택지마다 `fx`(수치 변화)와 `sns`(태그, 기사 제목, `tone`: -1 악플 위주 ~ 1 쉴드 위주, 진영별 문구)를 적습니다.

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
