// 계산 규칙. 화면과 관계없는 순수 계산만 모았다. (밸런스 조절은 여기서)

import 'dart:math';

import 'data.dart';
import 'game_state.dart';

/// 방송 품질 배율: 장비 단계 + 꾸미기
double quality(GameState s, Content? c) {
  final g = s.gear;
  final q = g['camera']! + g['light']! * 0.8 + g['mic']! * (c?.mic ?? 1) + g['pc']! * (c?.pc ?? 0.4);
  return 1 + q * 0.13 + s.deco.length * 0.03;
}

bool canStream(GameState s, Content c) => c.need.entries.every((e) => s.gear[e.key]! >= e.value);

Rank rankOf(int followers) => ranks.lastWhere((r) => followers >= r.min);

class StreamResult {
  const StreamResult({required this.viewers, required this.gain, required this.donation, required this.ads, required this.viral, required this.flop});
  final int viewers;
  final int gain;
  final int donation;
  final int ads;
  final bool viral;
  final bool flop;
}

class UploadResult {
  const UploadResult({required this.views, required this.gain, required this.ads, required this.viral});
  final int views;
  final int gain;
  final int ads;
  final bool viral;
}

/// 방송 결과
StreamResult calcStream(GameState s, Content c, Random rng) {
  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);
  final q = quality(s, c);
  final skill = 1 + min(s.skills[c.id] ?? 0, 20) * 0.03;
  final time = const [0.75, 1.0, 1.3][s.slot];
  final trend = s.trend == c.id ? 1.5 : 1.0;
  final fatigue = s.lastContent == c.id ? 0.85 : 1.0;
  final mind = s.mental < 30 ? 0.75 : 1.0;
  final tired = s.energy < 30 ? 0.85 : 1.0;
  final buzz = 1 + s.image / 250 + s.heat / 250;
  final base = 8 + 0.12 * pow(s.followers, 0.85);

  var viewers = base * q * skill * time * c.base * trend * fatigue * mind * tired * buzz * rnd(0.75, 1.25);
  final viral = rng.nextDouble() < 0.025 + (q - 1) * 0.02 + (trend > 1 ? 0.02 : 0);
  final flop = !viral && rng.nextDouble() < 0.08;
  if (viral) viewers *= rnd(2.5, 5);
  if (flop) viewers *= 0.5;
  final v = max(1, viewers.round());

  final early = 1 + 1.5 / (1 + s.followers / 150);
  final conv = early * (0.2 / (1 + s.followers / 400000)) * sqrt(q) * (1 + s.image / 120) * (1 - min(s.heat, 90) / 180);
  // 안티가 많으면 새 팬이 덜 생긴다
  final antiDrag = 1 - min(0.3, s.antis / (s.followers + 100) * 0.6);
  final gain = max(0, (v * conv * antiDrag * rnd(0.8, 1.2) * (viral ? 1.8 : 1) * (flop ? 0.3 : 1)).round());

  final donation = ((v * rnd(60, 140) * skill) / 100).round() * 100;
  final ads = s.followers >= 1000 ? ((v * 30) / 100).round() * 100 : 0;
  return StreamResult(viewers: v, gain: gain, donation: donation, ads: ads, viral: viral, flop: flop);
}

/// 편집 영상 업로드 결과
UploadResult calcUpload(GameState s, Random rng) {
  double rnd(double a, double b) => a + rng.nextDouble() * (b - a);
  final q = quality(s, null);
  final viral = rng.nextDouble() < 0.06 + (q - 1) * 0.02;
  final views = ((20 + s.lastViewers * 6 + s.followers * 0.25) * sqrt(q) * rnd(0.6, 1.4) * (viral ? rnd(4, 8) : 1)).round();
  final gain = (views * 0.035 * (1 + s.image / 150) * (1 - min(s.heat, 90) / 200)).round();
  final ads = s.followers >= 1000 ? ((views * 4) / 100).round() * 100 : 0;
  return UploadResult(views: views, gain: gain, ads: ads, viral: viral);
}
