/*
 * 스토리 데이터
 *
 * 장면(scene) 형식:
 *   text:    문단 배열
 *   gives:   이 장면에 도착하면 얻는 아이템 (선택)
 *   ending:  { title, type: "good" | "normal" | "bad" } — 있으면 엔딩 장면 (선택)
 *   choices: [{ label, next, requires?: [아이템], excludes?: [아이템] }]
 *            requires: 모두 갖고 있어야 보이는 선택지
 *            excludes: 하나라도 갖고 있으면 숨겨지는 선택지
 */
const STORY = {
  title: "자정의 저택",
  intro: "폭우가 쏟아지는 밤, 당신의 차가 언덕 아래에서 멈춰 섰다.",
  start: "start",
  scenes: {
    start: {
      text: [
        "와이퍼가 미친 듯이 움직이지만 앞이 보이지 않는다. 엔진이 마지막으로 기침을 하더니 조용해졌다.",
        "휴대폰은 신호가 없다. 언덕 위로 희미한 불빛 하나가 보인다. 오래된 저택이다.",
      ],
      choices: [
        { label: "빗속을 뚫고 저택으로 간다", next: "gate" },
        { label: "차 안에서 비가 그치길 기다린다", next: "wait_car" },
      ],
    },

    wait_car: {
      text: [
        "얼마나 지났을까. 똑, 똑, 똑. 누군가 운전석 창문을 두드린다.",
        "고개를 돌렸지만 창밖에는 아무도 없다. 그런데 두드리는 소리는 멈추지 않는다.",
      ],
      choices: [
        { label: "문을 열고 밖을 확인한다", next: "end_vanish" },
        { label: "차를 버리고 저택으로 달린다", next: "gate" },
      ],
    },

    gate: {
      text: [
        "녹슨 철문이 반쯤 열려 있다. 잡초가 무성한 정원 한쪽에 작은 창고가 보이고, 정면에는 커다란 현관문이 있다.",
      ],
      choices: [
        { label: "창고를 살펴본다", next: "shed", excludes: ["손전등"] },
        { label: "현관문으로 들어간다", next: "hall" },
      ],
    },

    shed: {
      gives: ["손전등"],
      text: [
        "삐걱거리는 문을 열자 먼지 냄새가 훅 끼친다. 선반 위에 낡은 손전등이 놓여 있다.",
        "스위치를 누르자, 놀랍게도 불이 들어온다.",
      ],
      choices: [{ label: "현관으로 향한다", next: "hall" }],
    },

    hall: {
      text: [
        "넓은 홀에 촛불 몇 개가 꺼질 듯 흔들린다. 벽에는 엄격한 표정의 노인 초상화가 걸려 있다.",
        "2층으로 올라가는 계단, 서재로 보이는 문, 그리고 지하로 내려가는 좁은 문이 있다. 어딘가에서 째깍째깍 시계 소리가 들린다.",
      ],
      choices: [
        { label: "2층으로 올라간다", next: "upstairs" },
        { label: "서재에 들어간다", next: "library" },
        { label: "손전등을 켜고 지하로 내려간다", next: "basement", requires: ["손전등"] },
        { label: "어둠 속 지하로 더듬어 내려간다", next: "end_fall", excludes: ["손전등"] },
      ],
    },

    library: {
      text: [
        "책장이 천장까지 닿아 있다. 책상 위에는 펼쳐진 일기장이, 그 아래에는 작은 서랍이 있다.",
      ],
      choices: [
        { label: "일기장을 읽는다", next: "diary", excludes: ["일기의 단서"] },
        { label: "서랍을 열어 본다", next: "drawer", excludes: ["녹슨 열쇠"] },
        { label: "홀로 돌아간다", next: "hall" },
      ],
    },

    diary: {
      gives: ["일기의 단서"],
      text: [
        "떨리는 필체로 쓰여 있다.",
        "“시계가 열두 번 울리면 문이 닫힌다. 그 아이의 노래만이 시간을 되돌릴 수 있다.”",
      ],
      choices: [{ label: "서재를 다시 둘러본다", next: "library" }],
    },

    drawer: {
      gives: ["녹슨 열쇠"],
      text: ["서랍 안쪽에 녹슨 열쇠 하나가 굴러다닌다. 손잡이에 작은 꽃무늬가 새겨져 있다."],
      choices: [{ label: "열쇠를 챙기고 서재를 둘러본다", next: "library" }],
    },

    upstairs: {
      text: [
        "긴 복도 끝에 꽃무늬가 그려진 문이 있다. 문 너머에서 어린아이의 콧노래가 들려온다.",
      ],
      choices: [
        { label: "녹슨 열쇠로 문을 연다", next: "child_room", requires: ["녹슨 열쇠"], excludes: ["오르골"] },
        { label: "문에 귀를 대 본다", next: "listen", excludes: ["오르골"] },
        { label: "홀로 내려간다", next: "hall" },
      ],
    },

    listen: {
      text: [
        "콧노래가 뚝 멈춘다. 그리고 문 바로 너머에서 속삭임이 들린다.",
        "“…할아버지 시계를… 멈춰 줘…”",
      ],
      choices: [{ label: "한 걸음 물러선다", next: "upstairs" }],
    },

    child_room: {
      gives: ["오르골"],
      text: [
        "작은 침대와 인형들. 창가에 반투명한 소녀가 앉아 있다. 소녀는 당신에게 작은 오르골을 내민다.",
        "“이 노래를 들려주면 할아버지가 잠들 수 있어요. 열두 시가 되기 전에요.”",
        "눈을 깜빡이자 소녀는 사라지고, 오르골만 손에 남았다.",
      ],
      choices: [{ label: "서둘러 홀로 내려간다", next: "hall" }],
    },

    basement: {
      text: [
        "손전등 불빛이 거대한 괘종시계를 비춘다. 바늘은 11시 59분을 가리키고 있다.",
        "시계추가 흔들릴 때마다 저택 전체가 숨을 쉬는 것 같다. 이제 곧 열두 시다.",
      ],
      choices: [
        { label: "오르골의 태엽을 감아 시계 앞에 놓는다", next: "end_dawn", requires: ["오르골"] },
        { label: "시계추를 두 손으로 붙잡는다", next: "end_trapped" },
        { label: "뒤돌아 저택 밖으로 도망친다", next: "end_escape" },
      ],
    },

    // ───── 엔딩 ─────
    end_vanish: {
      ending: { title: "빗속으로", type: "bad" },
      text: [
        "문을 열자 차가운 빗물과 함께 무언가가 당신의 손목을 붙잡았다.",
        "다음 날 아침, 언덕 아래에는 문이 열린 빈 차 한 대만 남아 있었다.",
      ],
    },
    end_fall: {
      ending: { title: "어둠 속 계단", type: "bad" },
      text: [
        "세 번째 계단에서 발이 허공을 디뎠다. 굴러떨어지는 동안 째깍거리는 소리가 점점 커졌다.",
        "빛이 있었다면 달랐을까.",
      ],
    },
    end_trapped: {
      ending: { title: "저택의 새 주인", type: "bad" },
      text: [
        "시계추가 멈추는 순간, 손이 시계에서 떨어지지 않는다. 초상화 속 노인의 얼굴이… 당신의 얼굴로 바뀌어 간다.",
        "이제 당신이 이 저택의 시간을 지킬 차례다.",
      ],
    },
    end_escape: {
      ending: { title: "열두 번의 종소리", type: "normal" },
      text: [
        "당신은 뒤돌아보지 않고 달렸다. 등 뒤에서 종이 열두 번 울렸다.",
        "아침이 되어 돌아왔을 때 언덕 위에는 무너진 잔해만 있었다. 그 밤의 일은 아무도 믿지 않았다.",
      ],
    },
    end_dawn: {
      ending: { title: "새벽의 자장가", type: "good" },
      text: [
        "오르골의 맑은 선율이 지하실을 채운다. 시계추가 천천히, 천천히 멈춘다.",
        "어둠 속에서 노인과 소녀가 손을 잡고 미소 짓는다. “고맙네.” 두 사람은 빛이 되어 흩어졌다.",
        "눈을 뜨니 창문 너머로 새벽이 밝아 오고 있었다. 비는 그쳤다.",
      ],
    },
  },
};
