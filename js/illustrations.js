/*
 * 장면 삽화 (SVG)
 * story.js의 image 값이 여기 있는 키 이름이면 이 그림이 쓰입니다.
 * 직접 그린 그림이나 이미지 파일을 쓰려면 image에 "img/파일이름.png"처럼 경로를 적으세요.
 * __ID__는 화면에 그릴 때 고유한 ID로 바뀝니다 (그라디언트 ID 충돌 방지).
 */
const ILLUSTRATIONS = (() => {
  const C = {
    sky: "#1b2133",
    skyLow: "#2a3148",
    ground: "#10131c",
    sil: "#0a0c12",
    stone: "#353b4c",
    wood: "#4a3324",
    woodLight: "#6b4a33",
    warm: "#f2b35b",
    warmSoft: "rgba(242,179,91,0.25)",
    moon: "#e9e2c6",
    ghost: "rgba(210,230,255,0.55)",
    paper: "#d9cfb8",
  };

  const frame = (body, { sky = C.sky, low = C.skyLow } = {}) =>
    `<svg viewBox="0 0 320 180" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
      <defs><linearGradient id="__ID__" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${sky}"/><stop offset="1" stop-color="${low}"/>
      </linearGradient></defs>
      <rect width="320" height="180" fill="url(#__ID__)"/>${body}</svg>`;

  const rain = (n = 40, color = "rgba(180,200,230,0.35)") => {
    let s = "";
    for (let i = 0; i < n; i++) {
      const x = (i * 53) % 330;
      const y = (i * 37) % 170;
      s += `<line x1="${x}" y1="${y}" x2="${x - 4}" y2="${y + 12}" stroke="${color}" stroke-width="1"/>`;
    }
    return s;
  };

  const mansionSil = (x, y, s = 1) => `
    <g transform="translate(${x} ${y}) scale(${s})">
      <rect x="0" y="30" width="120" height="60" fill="${C.sil}"/>
      <polygon points="-6,32 60,0 126,32" fill="${C.sil}"/>
      <rect x="18" y="8" width="10" height="20" fill="${C.sil}"/>
      <rect x="20" y="45" width="10" height="14" fill="${C.ground}"/>
      <rect x="55" y="45" width="10" height="14" fill="${C.warm}"/>
      <rect x="90" y="45" width="10" height="14" fill="${C.ground}"/>
      <rect x="53" y="68" width="14" height="22" fill="${C.ground}"/>
    </g>`;

  const candle = (x, y) => `
    <rect x="${x - 2}" y="${y}" width="4" height="12" fill="${C.paper}"/>
    <ellipse cx="${x}" cy="${y - 3}" rx="2" ry="4" fill="${C.warm}"/>
    <circle cx="${x}" cy="${y - 3}" r="10" fill="${C.warmSoft}"/>`;

  const bookshelf = (x, w) => {
    let s = `<rect x="${x}" y="20" width="${w}" height="140" fill="${C.wood}"/>`;
    const colors = ["#7a3b30", "#365a4a", "#6b5a2a", "#3d4a6b", "#5a3a5a"];
    for (let row = 0; row < 5; row++) {
      const y = 26 + row * 27;
      s += `<rect x="${x + 4}" y="${y + 22}" width="${w - 8}" height="3" fill="${C.woodLight}"/>`;
      for (let bx = x + 6, i = 0; bx < x + w - 10; i++) {
        const bw = 5 + ((i * 7 + row * 3) % 5);
        s += `<rect x="${bx}" y="${y + 4 + (i % 3)}" width="${bw}" height="${18 - (i % 3)}" fill="${colors[(i + row) % colors.length]}"/>`;
        bx += bw + 1;
      }
    }
    return s;
  };

  const catSil = (x, y, s = 1, color = C.sil, eyes = "#f2d14b") => `
    <g transform="translate(${x} ${y}) scale(${s})">
      <path d="M14 0 Q34 -4 30 -30 Q28 -40 36 -44" stroke="${color}" stroke-width="5" fill="none" stroke-linecap="round"/>
      <ellipse cx="0" cy="-14" rx="16" ry="18" fill="${color}"/>
      <circle cx="-2" cy="-38" r="11" fill="${color}"/>
      <polygon points="-12,-42 -10,-56 -3,-46" fill="${color}"/>
      <polygon points="8,-42 6,-56 -1,-46" fill="${color}"/>
      <ellipse cx="-6" cy="-39" rx="2.2" ry="3" fill="${eyes}"/>
      <ellipse cx="3" cy="-39" rx="2.2" ry="3" fill="${eyes}"/>
      <circle cx="-2" cy="-26" r="2.5" fill="#d9d9d9"/>
    </g>`;

  const smoke = (x, y) =>
    [0, 1, 2]
      .map(
        (i) => `<path d="M${x} ${y} q-5 -8 0 -16 q5 -8 0 -16" stroke="rgba(220,220,220,0.55)" stroke-width="2" fill="none" stroke-linecap="round">
        <animate attributeName="opacity" values="0;0.8;0" dur="3s" begin="${i}s" repeatCount="indefinite"/>
        <animateTransform attributeName="transform" type="translate" values="0 0; ${4 - i * 3} -18" dur="3s" begin="${i}s" repeatCount="indefinite"/>
      </path>`
      )
      .join("");

  return {
    garden: frame(`
      <rect y="130" width="320" height="50" fill="#141a14"/>
      <circle cx="60" cy="118" r="16" fill="#1d2a1d"/><circle cx="84" cy="124" r="12" fill="#1d2a1d"/>
      <circle cx="58" cy="114" r="3" fill="#a33b3b"/><circle cx="80" cy="120" r="3" fill="#a33b3b"/>
      <ellipse cx="150" cy="140" rx="26" ry="8" fill="#3a3f4d"/>
      <rect x="124" y="118" width="52" height="22" fill="#353b4c"/>
      <ellipse cx="150" cy="118" rx="26" ry="6" fill="#0a0c12"/>
      <rect x="128" y="88" width="4" height="30" fill="#4a3324"/><rect x="168" y="88" width="4" height="30" fill="#4a3324"/><rect x="124" y="84" width="52" height="5" fill="#4a3324"/>
      <rect x="200" y="114" width="20" height="20" fill="#59606e"/>
      <circle cx="210" cy="88" r="7" fill="#7a8190"/><path d="M200 114 Q210 92 220 114Z" fill="#7a8190"/>
      <path d="M200 100 Q186 88 194 80 M220 100 Q234 88 226 80" stroke="#7a8190" stroke-width="5" fill="none"/>
      <path d="M248 132 V96 L274 80 L300 96 V132Z" fill="rgba(200,240,220,0.25)" stroke="rgba(220,255,235,0.4)"/>
      ${rain(26)}`),

    well: frame(`
      <rect y="120" width="320" height="60" fill="#10131c"/>
      <ellipse cx="160" cy="120" rx="110" ry="40" fill="#353b4c"/>
      <ellipse cx="160" cy="116" rx="92" ry="30" fill="#05070c"/>
      <ellipse cx="140" cy="116" rx="13" ry="10" fill="rgba(200,190,170,0.35)"/>
      <ellipse cx="180" cy="114" rx="13" ry="10" fill="rgba(170,220,255,0.35)"/>
      <path d="M176 140 Q178 124 182 118 M182 140 Q186 126 190 120" stroke="rgba(220,240,255,0.6)" stroke-width="4" fill="none" stroke-linecap="round"/>
      ${rain(20)}`, { sky: "#0f131d", low: "#1a2030" }),

    statue: frame(`
      <rect y="150" width="320" height="30" fill="#10131c"/>
      <rect x="120" y="128" width="80" height="24" fill="#4a505e"/>
      <rect x="132" y="134" width="56" height="2" fill="#2a2f3a"/><rect x="132" y="140" width="56" height="2" fill="#2a2f3a"/>
      <path d="M136 128 Q160 60 184 128Z" fill="#7a8190"/>
      <circle cx="160" cy="54" r="13" fill="#8a919e"/>
      <path d="M146 80 Q100 60 96 30 Q120 50 150 70Z" fill="#6a717e"/>
      <path d="M174 80 Q220 60 224 30 Q200 50 170 70Z" fill="#6a717e"/>
      <path d="M150 90 L118 104 M170 90 L202 104" stroke="#8a919e" stroke-width="7" stroke-linecap="round"/>
      <path d="M140 110 Q150 116 146 128" stroke="#3d5a3d" stroke-width="3" fill="none"/>
      <circle cx="155" cy="54" r="1.5" fill="#222"/><circle cx="165" cy="54" r="1.5" fill="#222"/>
      <path d="M155 56 L154 66" stroke="rgba(150,180,220,0.6)"/>
      ${rain(26)}`),

    greenhouse: frame(`
      <rect width="320" height="180" fill="#0f1a16"/>
      <path d="M20 180 V60 L160 10 L300 60 V180" fill="rgba(180,240,210,0.08)" stroke="rgba(200,255,230,0.35)" stroke-width="2"/>
      <path d="M90 180 V36 M160 180 V10 M230 180 V36 M20 110 H300" stroke="rgba(200,255,230,0.25)" stroke-width="2"/>
      ${[[60, 150], [100, 140], [140, 155], [190, 145], [230, 152], [270, 142], [120, 128], [210, 130]]
        .map(([x, y]) => `<line x1="${x}" y1="${y}" x2="${x}" y2="180" stroke="#2d5a3d" stroke-width="2"/>
          <circle cx="${x}" cy="${y}" r="7" fill="#f4f7ff"/><circle cx="${x}" cy="${y}" r="14" fill="rgba(240,248,255,0.15)"/>`)
        .join("")}
      <ellipse cx="170" cy="168" rx="40" ry="8" fill="#0a120e"/>`),

    cat: frame(`
      <rect width="320" height="180" fill="#1f1a16"/>
      <rect y="110" width="320" height="8" fill="${C.woodLight}"/>
      ${[...Array(12)].map((_, i) => `<rect x="${10 + i * 28}" y="118" width="6" height="62" fill="${C.wood}"/>`).join("")}
      ${catSil(160, 110, 1.4)}
      <circle cx="157" cy="74" r="3" fill="#cfd4dc"/>
      ${candle(40, 90)}${candle(280, 90)}`),

    shadowcat: frame(`
      <rect width="320" height="180" fill="#120f0d"/>
      ${catSil(170, 200, 4.2, "#050404", "#ff4a3a")}
      ${catSil(60, 165, 0.7)}
      <circle cx="60" cy="146" r="2" fill="#cfd4dc"/>`, { sky: "#120f0d", low: "#2a1a14" }),

    catdoor: frame(`
      <rect width="320" height="180" fill="#120e0b"/>
      <path d="M0 180 Q160 90 320 180Z" fill="#2a2018"/>
      <path d="M120 180 V120 Q160 80 200 120 V180Z" fill="#1d2a40"/>
      <circle cx="150" cy="110" r="1.5" fill="#fff"/><circle cx="180" cy="104" r="1.5" fill="#fff"/><circle cx="168" cy="122" r="1" fill="#fff"/>
      ${catSil(160, 172, 0.8)}
      <circle cx="158" cy="146" r="2" fill="#cfd4dc"/>`),

    catroad: frame(`
      <path d="M0 140 Q160 120 320 140 V180 H0Z" fill="#20283a"/>
      <path d="M130 180 Q160 140 175 120 L182 120 Q172 140 190 180Z" fill="#3a4256"/>
      <rect x="230" y="70" width="4" height="70" fill="#111"/>
      <path d="M222 70 H246" stroke="#111" stroke-width="4"/>
      <polygon points="236,72 210,140 262,140" fill="rgba(255,220,150,0.18)"/>
      <circle cx="236" cy="74" r="5" fill="#ffd88a"/>
      ${catSil(178, 128, 0.5)}
      <circle cx="40" cy="30" r="1.5" fill="#fff"/><circle cx="100" cy="20" r="1.5" fill="#fff"/><circle cx="280" cy="40" r="1.5" fill="#fff"/>`, { sky: "#141a2a", low: "#2a3350" }),

    cathome: frame(`
      <rect width="320" height="180" fill="#f2e6d0"/>
      <rect x="60" y="20" width="200" height="110" fill="#bcd6ea"/>
      <circle cx="210" cy="56" r="18" fill="#fff4c2"/>
      <line x1="160" y1="20" x2="160" y2="130" stroke="#f2e6d0" stroke-width="6"/>
      <line x1="60" y1="75" x2="260" y2="75" stroke="#f2e6d0" stroke-width="6"/>
      <rect x="40" y="130" width="240" height="14" fill="#c9a77a"/>
      <rect x="0" y="144" width="320" height="36" fill="#e8d8bc"/>
      <path d="M120 130 Q122 112 150 110 Q178 108 190 120 Q196 130 190 130Z" fill="#111"/>
      <circle cx="122" cy="118" r="10" fill="#111"/>
      <polygon points="114,112 116,100 122,108" fill="#111"/><polygon points="126,108 130,100 131,112" fill="#111"/>
      <path d="M118 118 q3 2 6 0" stroke="#f2d14b" stroke-width="1.5" fill="none"/>
      <circle cx="124" cy="128" r="2.5" fill="#cfd4dc"/>
      <path d="M190 126 Q206 128 204 116" stroke="#111" stroke-width="4" fill="none" stroke-linecap="round"/>`, { sky: "#f2e6d0", low: "#f2e6d0" }),

    parlor: frame(`
      <rect width="320" height="180" fill="#1e1714"/>
      <rect y="140" width="320" height="40" fill="#2b1f19"/>
      <rect x="240" y="60" width="70" height="80" fill="#2a2420"/><rect x="250" y="80" width="50" height="60" fill="#0c0908"/>
      <path d="M30 140 V100 Q30 76 70 76 H120 Q130 76 130 90 V140Z" fill="#0b0b0d"/>
      <rect x="40" y="96" width="80" height="6" fill="#e8e4da"/>
      ${[...Array(10)].map((_, i) => `<rect x="${42 + i * 8}" y="96" width="3" height="4" fill="#111"/>`).join("")}
      <rect x="150" y="120" width="70" height="6" fill="${C.woodLight}"/><rect x="180" y="126" width="8" height="14" fill="${C.wood}"/>
      <rect x="158" y="114" width="10" height="6" fill="#ddd"/><rect x="174" y="114" width="10" height="6" fill="#ddd"/><rect x="190" y="114" width="10" height="6" fill="#ddd"/>
      <rect x="207" y="96" width="4" height="24" fill="#c9a94a"/>
      <rect x="205" y="86" width="8" height="10" fill="${C.paper}"/>
      <line x1="209" y1="86" x2="209" y2="82" stroke="#222" stroke-width="1.5"/>
      ${smoke(209, 80)}`),

    ball: frame(`
      <rect width="320" height="180" fill="#3a2418"/>
      <circle cx="160" cy="20" r="18" fill="#ffd88a"/><circle cx="160" cy="20" r="60" fill="rgba(255,216,138,0.2)"/>
      <rect y="140" width="320" height="40" fill="#5a3a24"/>
      ${[[70, "#a33b5a"], [130, "#3b5aa3"], [190, "#a37a3b"], [250, "#5aa37a"]]
        .map(([x, c], i) => `<g opacity="0.75"><circle cx="${x}" cy="${86 + (i % 2) * 6}" r="9" fill="rgba(240,240,255,0.7)"/>
          <path d="M${x - 20} 150 Q${x} 90 ${x + 20} 150Z" fill="${c}"/></g>`)
        .join("")}
      ${candle(30, 110)}${candle(290, 110)}`),

    blackout: frame(`
      <rect width="320" height="180" fill="#020202"/>
      <rect x="156" y="120" width="8" height="20" fill="#1a1a1a"/>
      ${smoke(160, 118)}
      ${[[60, 70], [100, 40], [230, 60], [270, 100], [190, 30]]
        .map(([x, y]) => `<ellipse cx="${x}" cy="${y}" rx="2" ry="1.4" fill="#555"/><ellipse cx="${x + 8}" cy="${y}" rx="2" ry="1.4" fill="#555"/>`)
        .join("")}`, { sky: "#020202", low: "#060606" }),

    cellar: frame(`
      <rect width="320" height="180" fill="#140f0c"/>
      ${[...Array(4)].map((_, r) => [...Array(9)].map((_, c) => `<circle cx="${22 + c * 34}" cy="${26 + r * 30}" r="11" fill="#241a14"/><circle cx="${22 + c * 34}" cy="${26 + r * 30}" r="5" fill="#3a1e22"/>`).join("")).join("")}
      <rect y="140" width="320" height="40" fill="#221812"/>
      <rect x="146" y="100" width="18" height="40" rx="4" fill="#4a1a24"/><rect x="151" y="88" width="8" height="14" fill="#4a1a24"/>
      <rect x="148" y="112" width="14" height="14" fill="${C.paper}"/>
      <circle cx="155" cy="110" r="30" fill="rgba(242,179,91,0.12)"/>
      <path d="M178 116 L186 116 L184 128 L180 128Z" fill="rgba(255,255,255,0.4)"/><line x1="182" y1="128" x2="182" y2="138" stroke="rgba(255,255,255,0.4)"/>`),

    curtain: frame(`
      <rect width="320" height="180" fill="#1a1820"/>
      <rect x="70" y="16" width="180" height="150" fill="#1b2133"/>
      <circle cx="200" cy="50" r="12" fill="${C.moon}" opacity="0.5"/>
      ${rain(14)}
      <rect x="70" y="140" width="180" height="4" fill="#0a0c12"/>
      ${[...Array(8)].map((_, i) => `<rect x="${78 + i * 22}" y="122" width="3" height="18" fill="#0a0c12"/>`).join("")}
      <rect x="62" y="10" width="196" height="8" fill="${C.wood}"/>
      <path fill="rgba(240,240,248,0.85)">
        <animate attributeName="d" dur="4s" repeatCount="indefinite"
          values="M70 18 Q110 18 120 18 Q112 90 124 170 Q96 168 70 170Z;
                  M70 18 Q120 18 150 18 Q200 70 170 160 Q110 176 70 170Z;
                  M70 18 Q110 18 120 18 Q112 90 124 170 Q96 168 70 170Z"/>
      </path>
      <path fill="rgba(240,240,248,0.75)">
        <animate attributeName="d" dur="4s" begin="0.4s" repeatCount="indefinite"
          values="M250 18 Q210 18 200 18 Q208 90 196 170 Q224 168 250 170Z;
                  M250 18 Q190 18 172 18 Q140 80 168 158 Q220 176 250 170Z;
                  M250 18 Q210 18 200 18 Q208 90 196 170 Q224 168 250 170Z"/>
      </path>`),

    balcony: frame(`
      <circle cx="250" cy="40" r="14" fill="${C.moon}" opacity="0.6"/>
      <path d="M0 110 Q160 90 320 110 V180 H0Z" fill="#141a14"/>
      <ellipse cx="90" cy="120" rx="10" ry="4" fill="#353b4c"/>
      <circle cx="270" cy="104" r="3" fill="#ffd88a"/><circle cx="290" cy="102" r="3" fill="#ffd88a"/>
      <rect y="130" width="320" height="6" fill="${C.stone}"/>
      ${[...Array(16)].map((_, i) => `<rect x="${6 + i * 20}" y="136" width="8" height="44" fill="${C.stone}"/>`).join("")}
      <polygon points="40,180 280,100 290,108 60,180" fill="rgba(255,240,190,0.15)"/>
      ${rain(12)}`),

    butlerroom: frame(`
      <rect width="320" height="180" fill="#1a1714"/>
      <rect y="150" width="320" height="30" fill="#241d17"/>
      ${[...Array(6)].map((_, i) => `<g transform="translate(${20 + i * 22} 20)"><line x1="10" y1="0" x2="10" y2="6" stroke="#555"/>
        <path d="M0 10 L10 4 L20 10 L18 70 H2Z" fill="#0b0b0b"/><polygon points="7,10 10,20 13,10" fill="#ddd"/></g>`).join("")}
      <rect x="180" y="110" width="120" height="8" fill="${C.woodLight}"/><rect x="190" y="118" width="8" height="32" fill="${C.wood}"/><rect x="282" y="118" width="8" height="32" fill="${C.wood}"/>
      <rect x="210" y="98" width="60" height="12" fill="#5a2a1a"/><rect x="214" y="96" width="52" height="4" fill="${C.paper}"/>
      ${candle(194, 96)}`),

    ledger: frame(`
      <rect width="320" height="180" fill="#2a1c14"/>
      <path d="M30 30 H160 V170 H30Z" fill="#e6dcc4"/><path d="M160 30 H290 V170 H160Z" fill="#ddd2b8"/>
      ${[...Array(10)].map((_, i) => `<line x1="44" y1="${46 + i * 12}" x2="146" y2="${46 + i * 12}" stroke="#8a7a66" stroke-width="1.5" opacity="0.6"/>`).join("")}
      ${[...Array(7)].map((_, i) => `<line x1="174" y1="${46 + i * 12}" x2="276" y2="${46 + i * 12}" stroke="#8a7a66" stroke-width="1.5" opacity="0.6"/>`).join("")}
      <line x1="174" y1="${46 + 7 * 12}" x2="236" y2="${46 + 7 * 12}" stroke="#7a1a1a" stroke-width="2.5"/>
      <rect x="240" y="${36 + 7 * 12}" width="36" height="14" fill="none" stroke="#7a1a1a" stroke-dasharray="3 2"/>
      <line x1="250" y1="160" x2="300" y2="120" stroke="#111" stroke-width="3"/>`),

    truck: frame(`
      <path d="M0 120 Q120 70 220 90 T320 80 V180 H0Z" fill="${C.ground}"/>
      ${mansionSil(30, 40, 0.4)}
      <path d="M0 180 L140 130 L200 130 L320 180Z" fill="#1a1d26"/>
      <rect x="170" y="110" width="80" height="34" fill="#2a2f3a"/><rect x="250" y="120" width="30" height="24" fill="#2a2f3a"/>
      <circle cx="190" cy="148" r="8" fill="#05060a"/><circle cx="262" cy="148" r="8" fill="#05060a"/>
      <circle cx="278" cy="134" r="4" fill="#ffe6a0"/>
      <polygon points="282,130 320,118 320,150 282,138" fill="rgba(255,230,160,0.2)"/>
      ${rain(40)}`),

    car: frame(`
      <circle cx="260" cy="30" r="14" fill="${C.moon}" opacity="0.5"/>
      <path d="M0 110 Q120 60 220 80 T320 70 V180 H0Z" fill="${C.ground}"/>
      ${mansionSil(210, 38, 0.45)}
      <path d="M0 180 L130 120 L190 120 L320 180Z" fill="#1a1d26"/>
      <rect x="110" y="122" width="100" height="30" rx="6" fill="${C.sil}"/>
      <path d="M128 122 L140 104 H182 L194 122Z" fill="${C.sil}"/>
      <path d="M142 120 L148 108 H176 L182 120Z" fill="#2a3148"/>
      <circle cx="132" cy="154" r="9" fill="#05060a"/><circle cx="190" cy="154" r="9" fill="#05060a"/>
      <polygon points="112,134 40,170 60,180 112,140" fill="rgba(242,179,91,0.15)"/>
      ${rain(60)}`),

    mansion: frame(`
      <circle cx="60" cy="34" r="16" fill="${C.moon}" opacity="0.6"/>
      <rect y="140" width="320" height="40" fill="${C.ground}"/>
      ${mansionSil(80, 50, 1.3)}
      <circle cx="160" cy="111" r="12" fill="${C.warmSoft}"/>
      ${[...Array(14)].map((_, i) => `<rect x="${8 + i * 22}" y="${110 + (i % 2) * 4}" width="3" height="${70}" fill="#05060a"/>`).join("")}
      <rect y="112" width="320" height="4" fill="#05060a"/>
      ${rain(40)}`),

    shed: frame(`
      <rect y="140" width="320" height="40" fill="${C.ground}"/>
      <polygon points="70,70 160,40 250,70" fill="${C.sil}"/>
      <rect x="80" y="68" width="160" height="80" fill="${C.wood}"/>
      <rect x="95" y="80" width="130" height="5" fill="${C.woodLight}"/>
      <rect x="95" y="110" width="130" height="5" fill="${C.woodLight}"/>
      <polygon points="168,98 320,60 320,150" fill="rgba(255,240,190,0.18)"/>
      <rect x="140" y="92" width="30" height="12" rx="3" fill="#888"/>
      <rect x="166" y="90" width="6" height="16" rx="2" fill="#bbb"/>
      <rect x="110" y="122" width="20" height="16" fill="${C.paper}" opacity="0.7"/>
      <text x="120" y="134" font-size="9" text-anchor="middle" fill="#7a3b30">12</text>`),

    butler: frame(`
      <rect x="0" y="0" width="320" height="180" fill="${C.sil}"/>
      <rect x="110" y="10" width="100" height="170" fill="#3a2a1a"/>
      <rect x="116" y="16" width="88" height="164" fill="${C.warmSoft}"/>
      <circle cx="160" cy="60" r="14" fill="#d8d2c4"/>
      <path d="M140 180 L144 82 Q160 74 176 82 L180 180Z" fill="#111"/>
      <polygon points="154,82 160,96 166,82" fill="#eee"/>
      <rect x="182" y="98" width="4" height="22" fill="#bba"/>
      ${candle(184, 92)}
      <rect x="0" y="0" width="110" height="180" fill="${C.sil}"/>
      ${rain(18)}`),

    hall: frame(`
      <rect width="320" height="180" fill="#1f1a16"/>
      <rect y="140" width="320" height="40" fill="#2a211a"/>
      <polygon points="200,140 300,40 320,40 320,60 230,140" fill="${C.wood}"/>
      ${[...Array(8)].map((_, i) => `<rect x="${212 + i * 11}" y="${130 - i * 11}" width="12" height="3" fill="${C.woodLight}"/>`).join("")}
      <rect x="40" y="30" width="60" height="76" fill="#6b5a2a"/>
      <rect x="46" y="36" width="48" height="64" fill="#2e2620"/>
      <circle cx="70" cy="60" r="12" fill="#8a7a66"/>
      <rect x="58" y="74" width="24" height="26" fill="#1a1512"/>
      <rect x="130" y="70" width="36" height="70" fill="#120e0b"/>
      <path d="M130 70 Q148 54 166 70" fill="#120e0b"/>
      ${candle(30, 120)}${candle(116, 116)}${candle(180, 118)}
      ${catSil(262, 84, 0.45)}`),

    portrait: frame(`
      <rect width="320" height="180" fill="#1f1a16"/>
      <rect x="95" y="10" width="130" height="160" fill="#8a6d2a"/>
      <rect x="105" y="20" width="110" height="140" fill="#2a231c"/>
      <circle cx="160" cy="72" r="26" fill="#9b8a72"/>
      <path d="M134 62 Q160 40 186 62" fill="#ccc" opacity="0.8"/>
      <circle cx="150" cy="72" r="3" fill="#1a1512"/><circle cx="170" cy="72" r="3" fill="#1a1512"/>
      <path d="M150 88 Q160 84 170 88" stroke="#4a3a2a" stroke-width="2" fill="none"/>
      <path d="M118 160 Q160 96 202 160Z" fill="#14100c"/>
      <rect x="135" y="150" width="50" height="8" fill="#c9a94a"/>
      <rect x="208" y="120" width="26" height="34" fill="${C.paper}" transform="rotate(12 220 137)"/>`),

    dining: frame(`
      <rect width="320" height="180" fill="#1d1513"/>
      <polygon points="40,180 120,90 200,90 280,180" fill="${C.wood}"/>
      <polygon points="52,176 126,96 194,96 268,176" fill="#e8e0d0" opacity="0.15"/>
      <ellipse cx="160" cy="140" rx="26" ry="9" fill="#ddd"/>
      <ellipse cx="160" cy="138" rx="18" ry="5" fill="#a0522d"/>
      <path d="M152 128 q4 -8 0 -16 M160 126 q4 -8 0 -16 M168 128 q4 -8 0 -16" stroke="rgba(255,255,255,0.4)" fill="none"/>
      <rect x="100" y="70" width="4" height="30" fill="#bba"/>${candle(102, 64)}
      <rect x="216" y="70" width="4" height="30" fill="#bba"/>${candle(218, 64)}
      <path d="M270 40 L278 180 H300 L292 40Z" fill="#0a0808"/><circle cx="285" cy="32" r="9" fill="#cfc8ba" opacity="0.7"/>`),

    kitchen: frame(`
      <rect width="320" height="180" fill="#1a1d22"/>
      <rect y="130" width="320" height="50" fill="#2b2f36"/>
      <rect x="20" y="20" width="120" height="70" fill="${C.wood}"/>
      <rect x="26" y="50" width="108" height="3" fill="${C.woodLight}"/>
      <circle cx="45" cy="40" r="8" fill="#ccc"/><circle cx="70" cy="40" r="8" fill="#bbb"/><rect x="95" y="30" width="14" height="18" fill="#7a8a9a"/>
      <rect x="40" y="58" width="22" height="12" fill="#c33"/><rect x="40" y="58" width="22" height="4" fill="#eee"/>
      <rect x="190" y="80" width="100" height="60" fill="#444"/>
      <rect x="200" y="96" width="80" height="34" fill="#111"/>
      <path d="M220 130 l6 -10 l6 10 l6 -8 l6 8" stroke="#334" fill="none"/>`),

    library: frame(`
      <rect width="320" height="180" fill="#1d1813"/>
      ${bookshelf(10, 110)}${bookshelf(200, 110)}
      <rect x="120" y="120" width="80" height="10" fill="${C.woodLight}"/>
      <rect x="128" y="130" width="64" height="40" fill="${C.wood}"/>
      <rect x="140" y="142" width="40" height="10" fill="${C.woodLight}"/>
      <path d="M140 118 L160 112 L180 118 L160 120Z" fill="${C.paper}"/>
      ${candle(130, 106)}`),

    diary: frame(`
      <rect width="320" height="180" fill="#2a2018"/>
      <path d="M40 40 Q160 20 160 40 V160 Q160 140 40 160Z" fill="${C.paper}"/>
      <path d="M280 40 Q160 20 160 40 V160 Q160 140 280 160Z" fill="#e6dcc4"/>
      ${[...Array(8)].map((_, i) => `<path d="M58 ${60 + i * 11} q40 ${-3} 86 0" stroke="#6b5a4a" stroke-width="1.5" fill="none" opacity="0.6"/>`).join("")}
      ${[...Array(5)].map((_, i) => `<path d="M176 ${60 + i * 11} q40 ${-3} 86 0" stroke="#6b5a4a" stroke-width="1.5" fill="none" opacity="0.6"/>`).join("")}
      <circle cx="230" cy="130" r="12" fill="none" stroke="#7a3b30" stroke-width="2"/>
      <path d="M230 122 V130 L236 134" stroke="#7a3b30" stroke-width="2" fill="none"/>`),

    passage: frame(`
      <rect width="320" height="180" fill="#0d0b09"/>
      <polygon points="0,0 120,60 120,130 0,180" fill="#2a221a"/>
      <polygon points="320,0 200,60 200,130 320,180" fill="#2a221a"/>
      <rect x="120" y="60" width="80" height="70" fill="#1a1510"/>
      <rect x="20" y="50" width="30" height="24" fill="#e8e0c8" transform="skewY(14)"/>
      <rect x="60" y="80" width="26" height="20" fill="#e8e0c8" transform="skewY(14)"/>
      <rect x="250" y="70" width="30" height="24" fill="#e8e0c8" transform="skewY(-14)"/>
      <circle cx="160" cy="112" r="12" fill="#c9a94a"/><circle cx="160" cy="112" r="9" fill="#f5efdc"/>
      <path d="M160 105 V112 L165 115" stroke="#333" stroke-width="1.5" fill="none"/>
      <rect x="140" y="124" width="40" height="6" fill="${C.wood}"/>
      <circle cx="160" cy="112" r="30" fill="rgba(242,179,91,0.12)"/>`),

    corridor: frame(`
      <rect width="320" height="180" fill="#16130f"/>
      <polygon points="0,0 130,55 130,125 0,180" fill="#2a221a"/>
      <polygon points="320,0 190,55 190,125 320,180" fill="#2a221a"/>
      <polygon points="0,180 130,125 190,125 320,180" fill="#3a2a1e"/>
      <rect x="140" y="62" width="40" height="63" fill="#e8d8c8"/>
      <circle cx="160" cy="85" r="6" fill="#d77"/><circle cx="153" cy="92" r="5" fill="#d9a"/><circle cx="167" cy="92" r="5" fill="#d9a"/>
      <rect x="30" y="40" width="40" height="110" fill="#1a1410" transform="skewY(22)"/>
      ${candle(100, 80)}`),

    door: frame(`
      <rect width="320" height="180" fill="#16130f"/>
      <rect x="90" y="10" width="140" height="170" fill="#e8d8c8"/>
      <circle cx="160" cy="70" r="16" fill="#d77"/><circle cx="142" cy="88" r="13" fill="#d9a"/><circle cx="178" cy="88" r="13" fill="#d9a"/>
      <circle cx="210" cy="110" r="5" fill="#a88"/>
      <text x="250" y="60" font-size="18" fill="#ccc" opacity="0.6">♪</text>
      <text x="270" y="90" font-size="14" fill="#ccc" opacity="0.4">♪</text>`),

    mirror: frame(`
      <rect width="320" height="180" fill="#1a1716"/>
      <rect x="100" y="8" width="120" height="168" rx="60" fill="#8a6d2a"/>
      <rect x="110" y="18" width="100" height="150" rx="50" fill="#3a4250"/>
      <circle cx="160" cy="80" r="14" fill="#1a1d24"/>
      <path d="M136 168 Q140 100 160 98 Q180 100 184 168Z" fill="#1a1d24"/>
      <path d="M120 40 L140 20" stroke="rgba(255,255,255,0.25)" stroke-width="4"/>
      <circle cx="155" cy="78" r="1.5" fill="#e33"/><circle cx="165" cy="78" r="1.5" fill="#e33"/>`),

    attic: frame(`
      <rect width="320" height="180" fill="#1a1612"/>
      <polygon points="0,0 160,0 0,120" fill="#0e0b09"/>
      <polygon points="320,0 160,0 320,120" fill="#0e0b09"/>
      <circle cx="160" cy="40" r="22" fill="#2a3148"/>
      <line x1="160" y1="18" x2="160" y2="62" stroke="#0e0b09" stroke-width="3"/>
      <line x1="138" y1="40" x2="182" y2="40" stroke="#0e0b09" stroke-width="3"/>
      <rect y="150" width="320" height="30" fill="#2a2018"/>
      <rect x="40" y="120" width="70" height="40" fill="${C.wood}"/>
      <rect x="130" y="110" width="60" height="44" fill="#f0e8d4"/>
      <circle cx="146" cy="128" r="6" fill="#777"/><circle cx="160" cy="132" r="4" fill="#777"/><circle cx="174" cy="126" r="6" fill="#777"/>
      <rect x="140" y="134" width="12" height="16" fill="#555"/><rect x="156" y="136" width="8" height="12" fill="#555"/><rect x="168" y="132" width="12" height="18" fill="#555"/>
      <path d="M220 150 l10 -12 l10 12Z M240 150 l10 -12 l10 12Z" fill="#c77"/>`),

    child: frame(`
      <rect width="320" height="180" fill="#211c22"/>
      <rect x="180" y="20" width="90" height="90" fill="#2a3148"/>
      <circle cx="240" cy="50" r="10" fill="${C.moon}" opacity="0.6"/>
      <line x1="225" y1="20" x2="225" y2="110" stroke="#211c22" stroke-width="4"/>
      <line x1="180" y1="65" x2="270" y2="65" stroke="#211c22" stroke-width="4"/>
      <circle cx="225" cy="100" r="12" fill="${C.ghost}"/>
      <path d="M210 160 Q212 112 225 112 Q238 112 240 160Z" fill="${C.ghost}"/>
      <rect x="30" y="120" width="110" height="40" fill="#e8d0d8"/><rect x="30" y="110" width="30" height="20" fill="#fff" opacity="0.8"/>
      <rect x="160" y="140" width="34" height="22" fill="#8a5a3a"/><rect x="160" y="136" width="34" height="6" fill="#c9a94a"/>
      <text x="200" y="134" font-size="12" fill="#fff" opacity="0.6">♪</text>`),

    clock: frame(`
      <rect width="320" height="180" fill="#0c0b0a"/>
      <polygon points="0,180 100,40 220,40 320,180" fill="rgba(255,240,190,0.08)"/>
      <rect x="125" y="20" width="70" height="160" fill="${C.wood}"/>
      <path d="M125 20 Q160 0 195 20Z" fill="${C.wood}"/>
      <circle cx="160" cy="48" r="24" fill="#e8e0c8"/>
      <line x1="160" y1="48" x2="160" y2="30" stroke="#222" stroke-width="2.5"/>
      <line x1="160" y1="48" x2="158" y2="36" stroke="#222" stroke-width="3.5"/>
      <rect x="138" y="80" width="44" height="90" fill="#1a120c"/>
      <line x1="160" y1="80" x2="170" y2="150" stroke="#c9a94a" stroke-width="2"/>
      <circle cx="170" cy="152" r="9" fill="#c9a94a"/>
      <path d="M40 30 L48 180 H64 L56 30Z" fill="#111"/><circle cx="52" cy="24" r="7" fill="#cfc8ba" opacity="0.5"/>`),

    rain: frame(`
      <rect y="130" width="320" height="50" fill="#0c0e14"/>
      <rect x="100" y="110" width="110" height="34" rx="6" fill="${C.sil}"/>
      <path d="M120 110 L134 92 H176 L190 110Z" fill="${C.sil}"/>
      <polygon points="190,112 230,96 232,140 196,142" fill="#1a1d26"/>
      <path d="M260 180 L262 120 Q270 100 280 120 L284 180Z" fill="rgba(0,0,0,0.6)"/>
      ${rain(90, "rgba(180,200,230,0.45)")}`, { sky: "#0f131d", low: "#1a2030" }),

    stairs: frame(`
      <rect width="320" height="180" fill="#050505"/>
      ${[...Array(7)].map((_, i) => `<rect x="${60 + i * 30}" y="${30 + i * 20}" width="200" height="6" fill="rgba(80,70,60,${0.5 - i * 0.06})"/>`).join("")}
      <text x="250" y="40" font-size="12" fill="#666">tick</text>
      <text x="270" y="60" font-size="12" fill="#444">tock</text>`),

    road: frame(`
      <circle cx="270" cy="150" r="40" fill="#f5c88a" opacity="0.6"/>
      <path d="M0 140 Q160 120 320 140 V180 H0Z" fill="#3a4250"/>
      <path d="M130 180 Q160 140 175 120 L182 120 Q172 140 190 180Z" fill="#555c6b"/>
      <path d="M150 104 Q170 84 190 104Z" fill="#111"/><line x1="170" y1="104" x2="170" y2="128" stroke="#111" stroke-width="2"/>
      <rect x="164" y="108" width="10" height="22" fill="#111"/>
      ${rain(14, "rgba(200,210,230,0.25)")}`, { sky: "#5a6278", low: "#c9a98a" }),

    ruins: frame(`
      <circle cx="80" cy="140" r="34" fill="#f5d6a0" opacity="0.7"/>
      <path d="M0 140 Q160 110 320 140 V180 H0Z" fill="#3c4434"/>
      <polygon points="150,130 160,90 168,128 180,100 186,130 200,112 208,132" fill="#2a2a2a"/>
      <rect x="170" y="100" width="6" height="30" fill="#2a2a2a" transform="rotate(14 173 115)"/>`, { sky: "#7c8aa6", low: "#e8c9a0" }),

    dawn: frame(`
      <circle cx="160" cy="150" r="60" fill="#ffd89a" opacity="0.8"/>
      <circle cx="160" cy="150" r="90" fill="#ffd89a" opacity="0.25"/>
      <rect y="140" width="320" height="40" fill="#3a3040"/>
      ${mansionSil(100, 60, 1)}
      <circle cx="120" cy="60" r="3" fill="#fff"/><circle cx="200" cy="40" r="2" fill="#fff"/><circle cx="230" cy="70" r="2.5" fill="#fff"/>`, { sky: "#4a5a8a", low: "#f2b38a" }),

    family: frame(`
      <circle cx="160" cy="160" r="110" fill="#ffe2b0" opacity="0.5"/>
      <rect y="150" width="320" height="30" fill="#4a3a40"/>
      ${[[120, 1, "#fff7e6"], [160, 0.7, "#fff7e6"], [200, 1.1, "#fff7e6"]]
        .map(
          ([x, s, c]) => `<g transform="translate(${x} 150) scale(${s})" opacity="0.85">
            <circle cx="0" cy="-58" r="11" fill="${c}"/><path d="M-14 0 Q-12 -44 0 -44 Q12 -44 14 0Z" fill="${c}"/></g>`
        )
        .join("")}
      <circle cx="80" cy="50" r="2" fill="#fff"/><circle cx="250" cy="40" r="2.5" fill="#fff"/><circle cx="280" cy="80" r="2" fill="#fff"/>`, { sky: "#5a6aa0", low: "#f7c99a" }),
  };
})();
