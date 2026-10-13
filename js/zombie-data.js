/*
 * 좀비 생존 게임 「서울, 구조까지 15일」 데이터
 *
 * 사건(events) 형식
 *   id, icon, title, text
 *   when: { loc: [장소], minDay, maxDay, comp: 동료 있어야, noComp: 동료 없어야, anyComp: 동료 1명 이상,
 *           flag, noFlag, minComps }
 *   once: true면 한 판에 한 번만, weight: 뽑힐 확률 가중치(기본 1), attack: true면 습격(바리케이드·박 상사 효과 적용)
 *   choices: [{ label, req: { ammo, med, food, water, comp, flag }, outcomes: [{ p: 확률 가중치, text, fx }] }]
 *
 * fx(효과): food, water, hp, mind, ammo, med (숫자만큼 더하거나 뺌)
 *   add: 동료 합류, remove: 동료 이탈("target"이면 사건 대상), flag / unflag: 표시 켜기·끄기,
 *   trust: 김 씨 신뢰도, move: "random"이면 근처 장소로 이동, fortify: 바리케이드,
 *   later: { days, event } 며칠 뒤 밤에 그 사건이 일어남, end: 엔딩 아이디, cause: 사망 원인
 *
 * 장소의 scavenge: 탐색할 때 찾는 물자 [종류, 최소, 최대], med: 구급약 찾을 확률, risk: 다칠 확률
 *   같은 장소를 여러 번 탐색하면 찾는 양이 점점 줄어듭니다.
 * 문장 안의 {name}은 사건 대상 동료의 이름으로 바뀝니다.
 */
const ZOMBIE = {
  days: 15,
  start: { loc: "apartment", food: 5, water: 7, hp: 8, mind: 7, ammo: 2, med: 1 },
  max: { food: 15, water: 15, hp: 10, mind: 10, ammo: 10, med: 5 },

  locations: {
    apartment: { name: "아파트", icon: "🏢", next: ["store", "school"], desc: "익숙한 우리 집. 현관문 너머가 조용할수록 더 무섭다.", scavenge: { loot: [["food", 0, 2], ["water", 1, 2]], med: 0.1, risk: 0.15 } },
    store: { name: "편의점", icon: "🏪", next: ["apartment", "hospital", "subway"], desc: "깨진 유리문, 반쯤 빈 진열대. 아직 남은 게 있을지도.", scavenge: { loot: [["food", 1, 3], ["water", 1, 3]], med: 0.05, risk: 0.35 } },
    school: { name: "학교", icon: "🏫", next: ["apartment", "hospital"], desc: "운동장에 좀비들이 서성인다. 교실 안은 의외로 조용하다.", scavenge: { loot: [["food", 0, 2], ["water", 1, 3]], med: 0.05, risk: 0.25 } },
    hospital: { name: "병원", icon: "🏥", next: ["store", "school", "subway"], desc: "약이 있지만, 가장 먼저 무너진 곳이기도 하다.", scavenge: { loot: [["water", 0, 1], ["food", 0, 1]], med: 0.7, risk: 0.4 } },
    subway: { name: "지하철역", icon: "🚇", next: ["store", "hospital", "han"], desc: "한강으로 이어지는 터널. 어둠 속에서 무언가 움직인다.", scavenge: { loot: [["water", 0, 2], ["ammo", 0, 2]], med: 0, risk: 0.35 } },
    han: { name: "한강", icon: "🌉", next: ["subway"], desc: "구조 헬기가 올 다리 아래. 강바람에 섞여 좀비들의 신음이 들린다.", scavenge: { loot: [["water", 1, 3], ["food", 0, 1]], med: 0, risk: 0.3 } },
  },

  jobs: {
    doctor: { name: "의사", icon: "🩺", desc: "구급약 2개로 시작하고, 구급약 효과가 더 커요.", start: { med: 2 } },
    cook: { name: "요리사", icon: "🍳", desc: "식량 +3으로 시작하고, 탐색할 때 식량을 더 찾아요.", start: { food: 3 } },
    driver: { name: "택시 기사", icon: "🚕", desc: "서울 지리를 꿰고 있어 이동 중에 습격받지 않아요.", start: {} },
  },

  companions: {
    jieun: { name: "간호사 지은", short: "지은", icon: "👩‍⚕️", desc: "매일 밤 체력을 1 회복시켜 줘요." },
    minjun: { name: "고등학생 민준", short: "민준", icon: "🎒", desc: "탐색할 때 물자를 하나 더 찾아요." },
    park: { name: "전직 군인 박 상사", short: "박 상사", icon: "🪖", desc: "습격과 탐색 중 다치는 피해를 절반으로 줄여요." },
    kim: { name: "옆집 김 씨", short: "김 씨", icon: "🧔", desc: "거래에 능하지만 속을 알 수 없어요. 대화로 신뢰를 쌓으세요." },
  },

  endings: {
    starved: { title: "텅 빈 찬장", type: "bad", hint: "식량은 생각보다 빨리 떨어진다.", text: "마지막 통조림을 비운 지 사흘. 몸이 더는 말을 듣지 않았다." },
    thirst: { title: "마른 입술", type: "bad", hint: "물은 식량보다 급하다.", text: "수돗물은 끊긴 지 오래였다. 비라도 왔더라면." },
    killed: { title: "어둠 속의 손", type: "bad", hint: "체력이 바닥나면 버틸 수 없다.", text: "상처가 쌓였고, 그날 밤 문은 버티지 못했다." },
    infected: { title: "열꽃", type: "bad", hint: "물린 상처를 모른 척하면…", text: "열이 끓더니 시야가 붉게 물들었다. 마지막으로 떠오른 건 한강의 헬기였다." },
    broken: { title: "무너진 마음", type: "bad", hint: "정신력도 체력만큼 중요하다. 혼자 있으면 더 빨리 지친다.", text: "더는 아무것도 하고 싶지 않았다. 창밖의 신음이 자장가처럼 들렸다." },
    betrayal: { title: "새벽의 배신", type: "bad", hint: "김 씨와는 대화로 신뢰를 쌓자.", text: "김 씨의 손에 든 쇠파이프가 마지막으로 본 장면이었다." },
    missed: { title: "헬기는 떠났다", type: "normal", hint: "15일째에는 한강에 있어야 한다.", text: "멀리서 프로펠러 소리가 들렸다가 사라졌다. 당신은 아직 살아 있다. 하지만 다음 헬기는 언제일까." },
    alone: { title: "홀로 탈출", type: "normal", hint: "혼자서 15일을 버티고 한강에 도착하자.", text: "헬기에 오른 사람은 당신 하나였다. 창밖의 서울이 점점 작아졌다." },
    dog: { title: "둘이서", type: "good", hint: "떠돌이 개에게 먹이를 준 적이 있다면…", text: "헬기 승무원이 개는 안 된다고 했지만, 당신은 끝까지 놓지 않았다. 결국 둘 다 탔다." },
    together: { title: "함께 탈출", type: "good", hint: "동료와 함께 한강에 도착하자.", text: "헬기 안에서 서로의 얼굴을 보며 처음으로 크게 웃었다." },
    everyone: { title: "모두 함께", type: "good", hint: "동료 3명 이상과 함께 구조되자.", text: "아무도 남겨 두지 않았다. 그게 이번 15일의 유일한 자랑이었다." },
    signal: { title: "모두를 위한 신호", type: "true", hint: "무전기와 믿을 수 있는 동료들. 그리고 한강.", text: "당신의 무전을 듣고 다른 생존자들도 다리 아래로 모여들었다. 그날 헬기는 세 번 더 왔다." },
  },

  // 아침 행동 결과 문구
  actionText: {
    scavenge: ["쓸 만한 걸 찾아 조심스럽게 둘러봤다.", "버려진 가방과 서랍을 하나하나 뒤졌다.", "숨을 죽이고 구석구석을 살폈다."],
    rest: ["오랜만에 깊이 잠들었다.", "벽에 기대 눈을 감았다. 조금 살 것 같다."],
    fortify: ["가구와 판자로 입구를 단단히 막았다.", "문 앞에 캐비닛을 밀어 두고 못을 박았다."],
    talk: ["밤새 시시한 이야기를 나눴다. 오랜만에 웃었다.", "서로의 가족 이야기를 했다. 마음이 조금 가벼워졌다."],
  },

  events: [
    // ───── 어디서나 ─────
    {
      id: "attack_small", icon: "🧟", title: "문을 긁는 소리", attack: true, weight: 3,
      text: "어둠 속에서 문을 긁는 소리가 난다. 두세 마리쯤 되는 것 같다.",
      choices: [
        { label: "총으로 처리한다", req: { ammo: 1 }, outcomes: [{ text: "탕, 탕. 다시 조용해졌다.", fx: { ammo: -1, mind: 1 } }] },
        { label: "둔기를 들고 맞선다", outcomes: [
          { p: 6, text: "가까스로 쓰러뜨렸다. 팔이 욱신거린다.", fx: { hp: -1 } },
          { p: 4, text: "하나를 놓쳤다. 한참을 뒹굴고 나서야 끝났다.", fx: { hp: -3 } },
        ] },
        { label: "숨죽이고 버틴다", outcomes: [
          { p: 6, text: "긁는 소리가 멀어졌다. 한숨도 못 잤다.", fx: { mind: -1 } },
          { p: 4, text: "문이 부서졌다. 정신없이 막아 냈지만 다쳤다.", fx: { hp: -2, mind: -1 } },
        ] },
      ],
    },
    {
      id: "attack_horde", icon: "🧟‍♂️", title: "좀비 떼", attack: true, weight: 2, when: { minDay: 6 },
      text: "창밖이 온통 흔들린다. 수십 마리의 좀비 떼가 이쪽으로 밀려온다.",
      choices: [
        { label: "총알을 아끼지 않고 버틴다", req: { ammo: 2 }, outcomes: [{ text: "총성이 멎었을 때 떼는 흩어져 있었다.", fx: { ammo: -2, hp: -1 } }] },
        { label: "짐을 챙겨 다른 곳으로 도망친다", outcomes: [{ text: "뒷문으로 빠져나와 정신없이 달렸다. 챙기지 못한 물자도 있다.", fx: { move: "random", food: -1, water: -1 } }] },
        { label: "가장 깊은 곳에 숨는다", outcomes: [
          { p: 5, text: "떼는 그냥 지나갔다. 기적 같다.", fx: { mind: -2 } },
          { p: 5, text: "몇 마리가 들어왔다. 겨우 살아남았다.", fx: { hp: -4, mind: -1 } },
        ] },
      ],
    },
    {
      id: "quiet_night", icon: "🌙", title: "조용한 밤", weight: 3,
      text: "이상할 만큼 조용한 밤이다. 멀리서 개 짖는 소리만 들린다.",
      choices: [
        { label: "잠을 청한다", outcomes: [{ text: "모처럼 푹 잤다.", fx: { hp: 1 } }] },
        { label: "창가에서 보초를 선다", outcomes: [{ text: "별이 보였다. 이 와중에도 별은 예쁘다.", fx: { mind: 1 } }] },
      ],
    },
    {
      id: "rain", icon: "🌧️", title: "소나기", weight: 2,
      text: "갑자기 비가 쏟아진다. 지붕을 두드리는 빗소리가 좀비들의 발소리를 덮는다.",
      choices: [
        { label: "그릇을 모두 꺼내 빗물을 받는다", outcomes: [{ text: "물통이 가득 찼다.", fx: { water: 3 } }] },
        { label: "빗소리를 들으며 쉰다", outcomes: [{ text: "마음이 차분해졌다.", fx: { mind: 2 } }] },
      ],
    },
    {
      id: "nightmare", icon: "😱", title: "악몽", when: { minDay: 2 },
      text: "가족이 좀비가 되는 꿈을 꿨다. 식은땀에 흠뻑 젖었다.",
      choices: [
        { label: "일기를 쓰며 마음을 달랜다", outcomes: [{ text: "적고 나니 조금 나아졌다.", fx: { mind: -1, hp: 0 } }] },
        { label: "동료를 깨워 이야기한다", req: { anyComp: true }, outcomes: [{ text: "동료도 같은 꿈을 꾼다고 했다. 둘이서 웃었다.", fx: { mind: 1 } }] },
        { label: "그냥 다시 눕는다", outcomes: [{ text: "잠이 오지 않았다.", fx: { mind: -2 } }] },
      ],
    },
    {
      id: "radio_news", icon: "📻", title: "라디오 방송", once: true, when: { minDay: 3, maxDay: 9 },
      text: "지직거리는 라디오에서 목소리가 들린다. “…15일 정오, 한강 다리 아래에서 마지막 구조 헬기가… 반복합니다…”",
      choices: [
        { label: "날짜를 벽에 새긴다", outcomes: [{ text: "목표가 생겼다. 살아야 할 이유도.", fx: { mind: 3 } }] },
      ],
    },
    {
      id: "looters", icon: "🦹", title: "약탈자", when: { minDay: 4 },
      text: "무장한 사람들이 문을 두드린다. “가진 거 다 내놓으면 아무도 안 다쳐.”",
      choices: [
        { label: "김 씨가 아는 얼굴이라며 나선다", req: { comp: "kim" }, outcomes: [{ text: "김 씨와 몇 마디 나누더니 그들은 순순히 돌아갔다.", fx: { mind: 1, trust: 1 } }] },
        { label: "물자를 나눠 준다", req: { food: 2, water: 2 }, outcomes: [{ text: "그들은 물자를 챙겨 사라졌다.", fx: { food: -2, water: -2 } }] },
        { label: "총을 겨누며 맞선다", req: { ammo: 2 }, outcomes: [
          { p: 7, text: "그들은 겁을 먹고 도망쳤다. 떨어뜨린 가방까지.", fx: { ammo: -2, food: 2 } },
          { p: 3, text: "총격전 끝에 쫓아냈지만 다쳤다.", fx: { ammo: -2, hp: -2 } },
        ] },
        { label: "협상해 본다", outcomes: [
          { p: 5, text: "말이 통했다. 조금만 내주고 끝났다.", fx: { food: -1 } },
          { p: 5, text: "협상은 실패했다. 얻어맞고 물자도 빼앗겼다.", fx: { hp: -2, food: -2, water: -1 } },
        ] },
      ],
    },
    {
      id: "fever", icon: "🤒", title: "열이 난다", when: { minDay: 3 },
      text: "몸이 으슬으슬하다. 감기인지, 무언가 더 나쁜 건지.",
      choices: [
        { label: "구급약을 먹는다", req: { med: 1 }, outcomes: [{ text: "아침이 되자 열이 내렸다.", fx: { med: -1 } }] },
        { label: "물을 많이 마시고 버틴다", req: { water: 2 }, outcomes: [{ text: "밤새 앓았지만 버텼다.", fx: { water: -2, hp: -1 } }] },
        { label: "그냥 버틴다", outcomes: [
          { p: 5, text: "운이 좋았다. 아침엔 괜찮아졌다.", fx: {} },
          { p: 5, text: "열이 오래갔다.", fx: { hp: -2, cause: "illness" } },
        ] },
      ],
    },
    {
      id: "stray_dog", icon: "🐕", title: "떠돌이 개", once: true, when: { noFlag: "dog" },
      text: "삐쩍 마른 개 한 마리가 문 앞에서 꼬리를 흔든다.",
      choices: [
        { label: "먹을 걸 나눠 준다", req: { food: 1 }, outcomes: [{ text: "개는 그날부터 당신 곁을 떠나지 않았다. 좀비가 오면 먼저 으르렁거린다.", fx: { food: -1, mind: 2, flag: "dog" } }] },
        { label: "쫓아낸다", outcomes: [{ text: "개는 몇 번 뒤돌아보다 사라졌다.", fx: { mind: -1 } }] },
      ],
    },
    {
      id: "dog_warns", icon: "🐕", title: "으르렁", when: { flag: "dog" }, once: true,
      text: "자정 무렵, 개가 낮게 으르렁거린다. 창밖에 그림자가 어른거린다.",
      choices: [
        { label: "개를 믿고 미리 피한다", outcomes: [{ text: "덕분에 좀비들이 오기 전에 자리를 옮겼다.", fx: { mind: 1, fortify: true } }] },
      ],
    },
    {
      id: "photo", icon: "🖼️", title: "가족 사진", once: true,
      text: "주머니에서 구겨진 가족 사진이 나왔다. 다들 무사할까.",
      choices: [
        { label: "오래 바라본다", outcomes: [{ text: "꼭 살아서 다시 만나자고 다짐했다.", fx: { mind: 2 } }] },
        { label: "보지 않고 넣어 둔다", outcomes: [{ text: "지금은 마음이 약해지면 안 된다.", fx: { mind: -1, hp: 1 } }] },
      ],
    },
    {
      id: "supply_drop", icon: "📦", title: "보급 상자", once: true, when: { minDay: 6, maxDay: 12 },
      text: "헬기 한 대가 근처 건물 옥상에 상자를 떨어뜨리고 갔다.",
      choices: [
        { label: "위험해도 가지러 간다", outcomes: [
          { p: 7, text: "상자 안에는 통조림과 물, 약이 가득했다!", fx: { food: 4, water: 4, med: 1 } },
          { p: 3, text: "옥상에서 좀비와 마주쳤다. 상자 반만 건졌다.", fx: { food: 2, water: 2, hp: -3, cause: "attack" } },
        ] },
        { label: "함정일지 모른다. 포기한다", outcomes: [{ text: "다음 날 아침, 상자는 사라져 있었다.", fx: { mind: -1 } }] },
      ],
    },
    {
      id: "fire", icon: "🔥", title: "불길", when: { minDay: 5 },
      text: "옆 건물에서 불이 났다. 연기가 이쪽으로 밀려온다.",
      choices: [
        { label: "불길을 피해 자리를 옮긴다", outcomes: [{ text: "연기를 뚫고 겨우 빠져나왔다.", fx: { move: "random", hp: -1 } }] },
        { label: "젖은 천으로 틈을 막고 버틴다", req: { water: 2 }, outcomes: [{ text: "불길은 이쪽까지 오지 않았다.", fx: { water: -2, mind: -1 } }] },
      ],
    },
    {
      id: "bitten_self", icon: "🩸", title: "이상한 상처", once: true, when: { minDay: 3 },
      text: "낮에 긁힌 줄 알았던 상처가 검게 부어올랐다. 이빨 자국 같기도 하다.",
      choices: [
        { label: "구급약으로 소독한다", req: { med: 1 }, outcomes: [
          { p: 8, text: "소독약이 상처를 태웠다. 다행히 부기가 빠졌다.", fx: { med: -1 } },
          { p: 2, text: "소독은 했지만 왠지 불안하다.", fx: { med: -1, later: { days: 2, event: "turn_self" } } },
        ] },
        { label: "칼로 상처를 도려낸다", outcomes: [{ text: "이를 악물었다. 아프지만 이게 확실하다.", fx: { hp: -3, cause: "illness" } }] },
        { label: "별것 아니라고 생각한다", outcomes: [{ text: "그냥 긁힌 걸 거야. 그렇게 믿기로 했다.", fx: { later: { days: 2, event: "turn_self" } } }] },
      ],
    },
    {
      id: "turn_self", icon: "🩸", title: "끓는 열", forcedOnly: true,
      text: "온몸이 불덩이 같다. 상처에서 검은 핏줄이 퍼져 나간다.",
      choices: [{ label: "…", outcomes: [{ text: "", fx: { end: "infected" } }] }],
    },
    {
      id: "comp_bitten", icon: "🩹", title: "물린 동료", once: true, when: { anyComp: true, minDay: 4 },
      text: "{name}이(가) 팔을 감싸 쥐고 있다. 소매 아래로 이빨 자국이 보인다.",
      choices: [
        { label: "지은에게 치료를 맡긴다", req: { comp: "jieun", med: 1 }, outcomes: [
          { p: 7, text: "지은의 빠른 처치 덕분에 {name}은(는) 무사했다.", fx: { med: -1, mind: 1 } },
          { p: 3, text: "치료는 했지만 열이 오른다. 지켜봐야 한다.", fx: { med: -1, later: { days: 2, event: "comp_turn" } } },
        ] },
        { label: "방에 격리하고 지켜본다", outcomes: [{ text: "문을 잠그고 밤새 숨소리에 귀를 기울였다.", fx: { mind: -1, later: { days: 2, event: "comp_turn" } } }] },
        { label: "떠나 달라고 말한다", outcomes: [{ text: "{name}은(는) 아무 말 없이 고개를 끄덕이고 떠났다.", fx: { remove: "target", mind: -3 } }] },
      ],
    },
    {
      id: "comp_turn", icon: "🚪", title: "잠긴 문", forcedOnly: true, attack: true,
      text: "격리해 둔 방에서 소리가 난다.",
      choices: [{ label: "문을 연다", outcomes: [
        { p: 1, text: "{name}이(가) 멀쩡한 얼굴로 웃었다. “배고파요.” 다리가 풀렸다.", fx: { mind: 3 } },
        { p: 1, text: "{name}은(는) 더 이상 {name}이(가) 아니었다. 힘겹게 밀어냈다.", fx: { remove: "target", hp: -3, mind: -3, cause: "attack" } },
      ] }],
    },
    {
      id: "kim_betray", icon: "🎒", title: "새벽의 짐 꾸러미", once: true, when: { comp: "kim", minDay: 7, maxTrust: 1 },
      text: "새벽, 김 씨가 몰래 물자를 가방에 쓸어 담고 있다. 눈이 마주쳤다.",
      choices: [
        { label: "총을 겨눈다", req: { ammo: 1 }, outcomes: [{ text: "김 씨는 가방을 내려놓고 빈손으로 떠났다.", fx: { remove: "kim", mind: -1 } }] },
        { label: "가방을 붙잡는다", outcomes: [
          { p: 5, text: "몸싸움 끝에 김 씨가 달아났다. 가방 일부는 지켰다.", fx: { remove: "kim", hp: -2, food: -2, cause: "attack" } },
          { p: 5, text: "김 씨가 쇠파이프를 휘둘렀다.", fx: { end: "betrayal" } },
        ] },
        { label: "그냥 보내 준다", outcomes: [{ text: "김 씨는 미안하다는 말도 없이 물자를 챙겨 떠났다.", fx: { remove: "kim", food: -3, water: -3 } }] },
      ],
    },
    {
      id: "kim_gift", icon: "🥫", title: "김 씨의 비상식량", once: true, when: { comp: "kim", minDay: 6, minTrust: 2 },
      text: "김 씨가 쑥스럽게 웃으며 숨겨 둔 통조림을 꺼낸다. “사실 이거 혼자 먹으려고 숨겨 둔 거였소.”",
      choices: [{ label: "고맙다고 말한다", outcomes: [{ text: "그날 밤 통조림은 유난히 맛있었다.", fx: { food: 3, mind: 2 } }] }],
    },
    {
      id: "park_story", icon: "🪖", title: "박 상사의 이야기", once: true, when: { comp: "park" },
      text: "박 상사가 낡은 탄창을 닦으며 군 시절 이야기를 꺼낸다.",
      choices: [{ label: "끝까지 듣는다", outcomes: [{ text: "이야기가 끝나자 박 상사가 아껴 둔 탄약을 건넸다. “당신이 들고 있어요.”", fx: { ammo: 2, mind: 1 } }] }],
    },
    {
      id: "minjun_snack", icon: "🍫", title: "민준의 비밀 가방", once: true, when: { comp: "minjun" },
      text: "민준이 가방에서 과자 봉지를 잔뜩 꺼낸다. “매점 털었어요. 비상용.”",
      choices: [{ label: "다 같이 나눠 먹는다", outcomes: [{ text: "과자 부스러기까지 다 먹었다. 오랜만의 단맛.", fx: { food: 2, mind: 2 } }] }],
    },
    {
      id: "jieun_care", icon: "💉", title: "지은의 처치", once: true, when: { comp: "jieun" },
      text: "지은이 당신의 상처를 보더니 말없이 붕대를 다시 감아 준다.",
      choices: [{ label: "고맙다고 말한다", outcomes: [{ text: "“다치지 마세요. 약이 얼마 없어요.” 그녀가 웃었다.", fx: { hp: 3 } }] }],
    },
    {
      id: "quarrel", icon: "💢", title: "말다툼", when: { minComps: 2 },
      text: "식량 배분을 두고 동료들 사이에 언성이 높아졌다.",
      choices: [
        { label: "내 몫을 덜어 중재한다", req: { food: 1 }, outcomes: [{ text: "분위기가 누그러졌다.", fx: { food: -1, mind: 1 } }] },
        { label: "모두에게 화를 낸다", outcomes: [{ text: "조용해졌지만 분위기는 무거워졌다.", fx: { mind: -2 } }] },
      ],
    },
    {
      id: "survivor_food", icon: "🙏", title: "굶주린 생존자",
      text: "창백한 얼굴의 생존자가 문 앞에 쓰러지듯 앉아 있다. 먹을 것을 조금만 나눠 달란다.",
      choices: [
        { label: "음식을 나눠 준다", req: { food: 1 }, outcomes: [
          { p: 6, text: "그는 고맙다며 근처 약국 위치를 알려 줬다.", fx: { food: -1, mind: 2, med: 1 } },
          { p: 4, text: "그는 허겁지겁 먹고 떠났다. 그래도 마음은 편하다.", fx: { food: -1, mind: 2 } },
        ] },
        { label: "문을 열지 않는다", outcomes: [{ text: "아침에 보니 그는 사라지고 없었다.", fx: { mind: -2 } }] },
      ],
    },

    // ───── 아파트 ─────
    {
      id: "apt_kim", icon: "🧔", title: "옆집 아저씨", once: true, when: { loc: ["apartment"], maxDay: 5, noComp: "kim" },
      text: "옆집 김 씨가 문을 두드린다. “혼자 있으면 더 무섭잖소. 같이 있읍시다. 나 물건 구하는 재주는 있어요.”",
      choices: [
        { label: "들인다", outcomes: [{ text: "김 씨가 커다란 배낭을 메고 들어왔다. 뭐가 들었는지는 안 보여 준다.", fx: { add: "kim", water: 1 } }] },
        { label: "거절한다", outcomes: [{ text: "발소리가 멀어졌다. 잘한 걸까.", fx: { mind: -1 } }] },
      ],
    },
    {
      id: "apt_elevator", icon: "🛗", title: "멈춘 엘리베이터", once: true, when: { loc: ["apartment"] },
      text: "멈춘 엘리베이터 안에서 쿵쿵 소리가 난다. 배달 카트가 갇혀 있던 게 생각났다.",
      choices: [
        { label: "문을 비집어 연다", outcomes: [
          { p: 5, text: "배달 카트에 생수와 즉석밥이 그대로 있었다!", fx: { food: 3, water: 3 } },
          { p: 5, text: "카트 옆에 배달원이… 있었다. 겨우 문을 닫았다.", fx: { hp: -2, cause: "attack" } },
        ] },
        { label: "모른 척한다", outcomes: [{ text: "쿵쿵 소리는 밤새 이어졌다.", fx: { mind: -1 } }] },
      ],
    },
    {
      id: "apt_rooftop", icon: "🔦", title: "건너편 불빛", once: true, when: { loc: ["apartment"] },
      text: "건너편 아파트 옥상에서 손전등이 깜빡인다. 누군가 신호를 보내고 있다.",
      choices: [
        { label: "휴대폰 불빛으로 답한다", outcomes: [{ text: "한참 신호를 주고받았다. 혼자가 아니라는 게 이렇게 든든할 줄이야.", fx: { mind: 3 } }] },
        { label: "불을 끄고 숨는다", outcomes: [{ text: "불빛은 곧 꺼졌다.", fx: { mind: -1 } }] },
      ],
    },

    // ───── 편의점 ─────
    {
      id: "store_trade", icon: "🤝", title: "물물교환", when: { loc: ["store"] },
      text: "다른 생존자 무리가 편의점 앞에서 물물교환을 하자고 한다.",
      choices: [
        { label: "탄약 1개를 식량 3개로 바꾼다", req: { ammo: 1 }, outcomes: [{ text: "거래 성립.", fx: { ammo: -1, food: 3 } }] },
        { label: "식량 2개를 물 3개로 바꾼다", req: { food: 2 }, outcomes: [{ text: "거래 성립.", fx: { food: -2, water: 3 } }] },
        { label: "김 씨에게 흥정을 맡긴다", req: { comp: "kim" }, outcomes: [{ text: "김 씨가 입담으로 공짜나 다름없이 받아 냈다.", fx: { food: 2, water: 2, trust: 1 } }] },
        { label: "거래하지 않는다", outcomes: [{ text: "그들은 다른 곳으로 떠났다.", fx: {} }] },
      ],
    },
    {
      id: "store_park", icon: "🪖", title: "냉동 창고의 남자", once: true, when: { loc: ["store", "subway"], noComp: "park" },
      text: "창고 안쪽에서 낮은 목소리가 들린다. “쏘지 마시오. 박 상사요. 예비역.” 군복 차림의 남자가 손을 들고 나온다.",
      choices: [
        { label: "함께 가자고 한다", outcomes: [{ text: "박 상사가 고개를 끄덕였다. 든든한 동료가 생겼다.", fx: { add: "park" } }] },
        { label: "탄약만 조금 나눠 받는다", outcomes: [{ text: "박 상사는 탄약 몇 발을 건네고 떠났다.", fx: { ammo: 2 } }] },
      ],
    },
    {
      id: "store_alarm", icon: "🚨", title: "도난 경보", once: true, attack: true, when: { loc: ["store"] },
      text: "갑자기 도난 경보가 요란하게 울린다. 좀비들이 소리를 향해 몰려든다.",
      choices: [
        { label: "경보기를 부수고 숨는다", outcomes: [
          { p: 6, text: "경보는 멎었지만 몇 마리가 들어왔다.", fx: { hp: -2, cause: "attack" } },
          { p: 4, text: "재빨리 꺼서 무사했다.", fx: { mind: -1 } },
        ] },
        { label: "소란을 틈타 뒷문으로 나간다", outcomes: [{ text: "좀비들이 경보에 정신 팔린 사이 빠져나왔다.", fx: { move: "random" } }] },
      ],
    },

    // ───── 병원 ─────
    {
      id: "hosp_jieun", icon: "👩‍⚕️", title: "응급실의 간호사", once: true, when: { loc: ["hospital"], noComp: "jieun" },
      text: "응급실 구석에서 간호사 한 명이 환자 침대를 바리케이드 삼아 버티고 있다. “다친 데 있어요? 일단 보여 줘요.”",
      choices: [
        { label: "같이 가자고 한다", outcomes: [{ text: "지은이 약 가방을 챙겼다. “혼자 남는 것보다는 낫겠죠.”", fx: { add: "jieun", hp: 2 } }] },
        { label: "치료만 받고 떠난다", outcomes: [{ text: "지은이 약을 조금 나눠 줬다.", fx: { hp: 3, med: 1 } }] },
      ],
    },
    {
      id: "hosp_pharmacy", icon: "💊", title: "약제실", once: true, when: { loc: ["hospital"] },
      text: "잠긴 약제실 문이 보인다. 안에서 무언가 부딪히는 소리가 난다.",
      choices: [
        { label: "문을 부수고 들어간다", outcomes: [
          { p: 7, text: "약품이 그대로 남아 있었다!", fx: { med: 2 } },
          { p: 3, text: "안에 있던 건 약사였다. 아니, 약사였던 것.", fx: { med: 1, hp: -2, cause: "attack" } },
        ] },
        { label: "포기한다", outcomes: [{ text: "부딪히는 소리는 밤새 이어졌다.", fx: {} }] },
      ],
    },
    {
      id: "hosp_morgue", icon: "🥶", title: "지하 영안실", once: true, when: { loc: ["hospital"] },
      text: "지하에서 차가운 바람이 올라온다. 영안실 문이 열려 있다.",
      choices: [
        { label: "내려가 본다", outcomes: [
          { p: 5, text: "직원 휴게실에서 생수 상자를 찾았다.", fx: { water: 3, mind: -1 } },
          { p: 5, text: "보지 말아야 할 것을 봤다.", fx: { mind: -3 } },
        ] },
        { label: "문을 닫고 잠근다", outcomes: [{ text: "적어도 오늘 밤은 저쪽에서 올라오지 못한다.", fx: { fortify: true } }] },
      ],
    },

    // ───── 학교 ─────
    {
      id: "school_minjun", icon: "🎒", title: "체육관의 소년", once: true, when: { loc: ["school"], noComp: "minjun" },
      text: "체육관 매트 더미 뒤에서 교복 입은 소년이 야구 방망이를 꽉 쥐고 있다. “…좀비 아니죠?”",
      choices: [
        { label: "같이 가자고 한다", outcomes: [{ text: "민준이 고개를 끄덕였다. 학교 구석구석을 잘 안다고 한다.", fx: { add: "minjun" } }] },
        { label: "먹을 것만 나눠 준다", req: { food: 1 }, outcomes: [{ text: "민준은 고맙다며 매점 열쇠를 건넸다.", fx: { food: 1, mind: 2 } }] },
      ],
    },
    {
      id: "school_radio", icon: "📡", title: "방송실", once: true, when: { loc: ["school"], noFlag: "radio" },
      text: "방송실에 비상용 무전기가 남아 있다. 배터리도 아직 살아 있다.",
      choices: [
        { label: "무전기만 챙긴다", outcomes: [{ text: "무전기를 가방 깊숙이 넣었다. 언젠가 쓸 일이 있을 것이다.", fx: { flag: "radio" } }] },
        { label: "전교 방송으로 생존자를 찾는다", outcomes: [
          { p: 5, text: "몇몇이 응답했다. 다들 한강으로 간다고 한다. 무전기도 챙겼다.", fx: { flag: "radio", mind: 3 } },
          { p: 5, text: "스피커 소리에 좀비들이 몰려왔다. 무전기만 들고 뛰었다.", fx: { flag: "radio", hp: -2, cause: "attack" } },
        ] },
      ],
    },
    {
      id: "school_cafeteria", icon: "🍱", title: "급식실", once: true, when: { loc: ["school"] },
      text: "급식실 창고 문이 반쯤 열려 있다.",
      choices: [
        { label: "들어가 본다", outcomes: [
          { p: 6, text: "쌀포대와 생수가 남아 있었다.", fx: { food: 3, water: 2 } },
          { p: 4, text: "조리사 좀비와 마주쳤다. 국자로 싸웠다.", fx: { food: 1, hp: -2, cause: "attack" } },
        ] },
        { label: "그냥 지나친다", outcomes: [{ text: "괜히 배가 고파졌다.", fx: { mind: -1 } }] },
      ],
    },

    // ───── 지하철역 ─────
    {
      id: "sub_tunnel", icon: "🔦", title: "터널 저편의 불빛", once: true, when: { loc: ["subway"] },
      text: "선로 터널 저편에서 희미한 불빛이 흔들린다.",
      choices: [
        { label: "불빛을 따라간다", outcomes: [
          { p: 5, text: "먼저 떠난 생존자들의 은신처였다. 남은 물자를 얻었다.", fx: { ammo: 2, food: 2 } },
          { p: 5, text: "불빛은 좀비가 쥔 손전등이었다.", fx: { hp: -3, cause: "attack" } },
        ] },
        { label: "돌아선다", outcomes: [{ text: "불빛이 천천히 이쪽으로 다가오는 것 같았다.", fx: { mind: -1 } }] },
      ],
    },
    {
      id: "sub_train", icon: "🚃", title: "멈춘 열차", once: true, when: { loc: ["subway"] },
      text: "승강장에 멈춘 열차. 문이 반쯤 열린 칸이 있다.",
      choices: [
        { label: "열차 안을 뒤진다", outcomes: [
          { p: 6, text: "승객들의 가방에서 물과 간식을 찾았다.", fx: { water: 3, food: 1 } },
          { p: 4, text: "마지막 칸에 승객들이 그대로 있었다.", fx: { hp: -2, water: 1, cause: "attack" } },
        ] },
        { label: "선로를 따라 지나간다", outcomes: [{ text: "열차 창문에 손자국이 가득했다.", fx: { mind: -1 } }] },
      ],
    },

    // ───── 한강 ─────
    {
      id: "han_wait", icon: "🌉", title: "다리 아래의 밤", weight: 3, when: { loc: ["han"] }, attack: true,
      text: "강가에는 좀비가 많다. 헬기를 기다리는 밤은 길다.",
      choices: [
        { label: "다리 기둥 뒤에 숨는다", outcomes: [
          { p: 7, text: "들키지 않고 밤을 넘겼다.", fx: { mind: -1 } },
          { p: 3, text: "들켰다. 강물로 뛰어들어 겨우 피했다.", fx: { hp: -2, cause: "attack" } },
        ] },
        { label: "작게 모닥불을 피운다", outcomes: [
          { p: 6, text: "온기 덕분에 버틸 만했다.", fx: { mind: 2 } },
          { p: 4, text: "불빛을 보고 좀비들이 몰려왔다.", fx: { hp: -2, mind: 1, cause: "attack" } },
        ] },
      ],
    },
    {
      id: "han_boat", icon: "🚤", title: "버려진 보트", once: true, when: { loc: ["han"] },
      text: "강가에 묶인 작은 보트가 보인다. 물 위라면 좀비가 오지 못한다.",
      choices: [{ label: "보트에서 밤을 보낸다", outcomes: [{ text: "강물에 흔들리며 오랜만에 안심하고 잤다.", fx: { fortify: true, mind: 2, hp: 1 } }] }],
    },
    {
      id: "han_group", icon: "👥", title: "다른 생존자들", once: true, when: { loc: ["han"] },
      text: "다리 아래에 생존자 몇 명이 먼저 와 있다. 다들 같은 방송을 들었다고 한다.",
      choices: [
        { label: "함께 망을 보자고 한다", outcomes: [{ text: "교대로 잠을 잤다. 혼자가 아니다.", fx: { mind: 3, fortify: true } }] },
        { label: "거리를 둔다", outcomes: [{ text: "서로를 경계하며 밤을 보냈다.", fx: { mind: -1 } }] },
      ],
    },
  ],
};

if (typeof module !== "undefined") module.exports = ZOMBIE;
