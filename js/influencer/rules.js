/*
 * 인플루언서 시뮬레이터 — 계산 규칙
 * 화면과 관계없는 순수 계산만 모았습니다. (밸런스 조절은 여기서)
 */
(() => {
  // 방송 품질 배율: 장비 단계 + 꾸미기
  IF.quality = (s, c) => {
    const g = s.gear;
    const q = g.camera + g.light * 0.8 + g.mic * ((c && c.mic) || 1) + g.pc * ((c && c.pc) || 0.4);
    return 1 + q * 0.13 + s.deco.length * 0.03;
  };

  IF.canStream = (s, c) => {
    if (!c.need) return true;
    return Object.entries(c.need).every(([k, v]) => s.gear[k] >= v);
  };

  IF.rankOf = (followers) => [...IF.RANKS].reverse().find((r) => followers >= r.min);

  // 방송 결과
  IF.calcStream = (s, c, R = Math.random) => {
    const rnd = (a, b) => a + R() * (b - a);
    const Q = IF.quality(s, c);
    const skill = 1 + Math.min(s.skills[c.id] || 0, 20) * 0.03;
    const time = [0.75, 1, 1.3][s.slot];
    const trend = s.trend === c.id ? 1.5 : 1;
    const fatigue = s.lastContent === c.id ? 0.85 : 1;
    const mind = s.mental < 30 ? 0.75 : 1;
    const tired = s.energy < 30 ? 0.85 : 1;
    const buzz = 1 + s.image / 250 + s.heat / 250;
    const base = 8 + 0.12 * Math.pow(s.followers, 0.85);

    let viewers = base * Q * skill * time * c.base * trend * fatigue * mind * tired * buzz * rnd(0.75, 1.25);
    const viral = R() < 0.025 + (Q - 1) * 0.02 + (trend > 1 ? 0.02 : 0);
    const flop = !viral && R() < 0.08;
    if (viral) viewers *= rnd(2.5, 5);
    if (flop) viewers *= 0.5;
    viewers = Math.max(1, Math.round(viewers));

    const early = 1 + 1.5 / (1 + s.followers / 150);
    const conv = early * (0.2 / (1 + s.followers / 400000)) * Math.sqrt(Q) * (1 + s.image / 120) * (1 - Math.min(s.heat, 90) / 180);
    let gain = viewers * conv * rnd(0.8, 1.2) * (viral ? 1.8 : 1) * (flop ? 0.3 : 1);
    gain = Math.max(0, Math.round(gain));

    const donation = Math.round((viewers * rnd(60, 140) * skill) / 100) * 100;
    const ads = s.followers >= 1000 ? Math.round((viewers * 30) / 100) * 100 : 0;
    return { viewers, gain, donation, ads, viral, flop };
  };

  // 편집 영상 업로드 결과
  IF.calcUpload = (s, R = Math.random) => {
    const rnd = (a, b) => a + R() * (b - a);
    const Q = IF.quality(s, null);
    const viral = R() < 0.06 + (Q - 1) * 0.02;
    const views = Math.round((20 + (s.lastViewers || 0) * 6 + s.followers * 0.25) * Math.sqrt(Q) * rnd(0.6, 1.4) * (viral ? rnd(4, 8) : 1));
    const gain = Math.round(views * 0.035 * (1 + s.image / 150) * (1 - Math.min(s.heat, 90) / 200));
    const ads = s.followers >= 1000 ? Math.round((views * 4) / 100) * 100 : 0;
    return { views, gain, ads, viral };
  };
})();
