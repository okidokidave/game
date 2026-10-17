import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/data.dart';
import 'palette.dart';

// 방송 미니게임: 콘텐츠마다 짧은 손맛 게임. 점수(0~1)를 별 0~3개로 바꿔 방송 결과에 보너스를 준다.

/// 미니게임 종류
enum MiniKind { targets, mash, timing, reaction, hold }

class MiniSpec {
  const MiniSpec(this.kind, this.title, this.howTo, {this.good = const [], this.bad = const [], this.icon = ''});
  final MiniKind kind;
  final String title;
  final String howTo;

  /// 눌러야 하는 것 / 누르면 안 되는 것 (targets)
  final List<String> good;
  final List<String> bad;

  /// 가운데 큰 그림 (mash, hold, timing)
  final String icon;
}

MiniSpec miniFor(Content c, {String petIcon = '🐾'}) => switch (c.id) {
      'talk' => const MiniSpec(MiniKind.targets, '💬 채팅 낚기', '좋은 채팅(💬❓😂)을 눌러 대답하고, 악플(😡🤬)은 무시하세요!', good: ['💬', '❓', '😂'], bad: ['😡', '🤬']),
      'game' => const MiniSpec(MiniKind.targets, '🎮 에임 연습', '과녁을 빠르게 맞히세요! 💣은 누르면 안 돼요.', good: ['🎯', '👾'], bad: ['💣']),
      'pet' => MiniSpec(MiniKind.targets, '🐾 쓰다듬기', '돌아다니는 반려동물을 쓰다듬어 주세요! 🧶은 건드리지 마세요.', good: [petIcon], bad: ['🧶']),
      'mukbang' => const MiniSpec(MiniKind.mash, '🍜 폭풍 먹방', '화면을 마구 눌러서 시간 안에 다 먹어 치우세요!', icon: '🍜'),
      'sing' => const MiniSpec(MiniKind.timing, '🎤 박자 맞추기', '움직이는 음표가 초록 칸에 왔을 때 누르세요!', icon: '🎵'),
      'vlog' => const MiniSpec(MiniKind.timing, '🎬 구도 잡기', '움직이는 카메라가 초록 칸에 왔을 때 찍으세요!', icon: '📷'),
      'react' => const MiniSpec(MiniKind.reaction, '😲 찐 리액션', '"!"가 뜨는 순간 바로 누르세요! 미리 누르면 실패예요.', icon: '😲'),
      'asmr' => const MiniSpec(MiniKind.hold, '🎧 섬세한 소리', '꾹 누르면 올라가고 떼면 내려가요. 초록 구간에 머무르세요!', icon: '🎧'),
      _ => const MiniSpec(MiniKind.hold, '📚 집중 유지', '꾹 누르면 집중이 올라가요. 너무 높지도 낮지도 않게!', icon: '📚'),
    };

/// 점수 → 별 0~3개
int starsOf(double score) => score >= 0.8 ? 3 : (score >= 0.55 ? 2 : (score >= 0.25 ? 1 : 0));

/// 미니게임을 띄우고 점수(0~1)를 돌려준다
Future<double> playMinigame(BuildContext context, MiniSpec spec, {required Duration duration, Random? rng}) async {
  final score = await showGeneralDialog<double>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC060814),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: MinigameView(spec: spec, duration: duration, rng: rng ?? Random(), onDone: (v) => Navigator.pop(ctx, v)),
      ),
    ),
  );
  return score ?? 0;
}

class MinigameView extends StatefulWidget {
  const MinigameView({super.key, required this.spec, required this.duration, required this.rng, required this.onDone});
  final MiniSpec spec;
  final Duration duration;
  final Random rng;
  final ValueChanged<double> onDone;

  @override
  State<MinigameView> createState() => _MinigameViewState();
}

class _Target {
  _Target(this.x, this.y, this.icon, this.good, this.born);
  final double x, y;
  final String icon;
  final bool good;
  final double born;
  bool gone = false;
}

class _MinigameViewState extends State<MinigameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// 진행 시간 (초)
  double _t = 0;
  double get _total => widget.duration.inMicroseconds / 1e6;
  bool _over = false;
  double? _final;
  String _feedback = '';
  double _feedbackAt = -1;

  // targets
  final _targets = <_Target>[];
  double _nextSpawn = 0.2;
  int _goodSpawned = 0, _goodHit = 0, _badHit = 0;

  // mash
  int _taps = 0;
  int get _mashGoal => max(6, (_total * 4.5).round());

  // timing
  int _round = 0, _hits = 0;
  late double _zone = _newZone();
  double _phase = 0;
  static const _rounds = 5;

  // reaction
  double _showAt = 0;
  bool _armed = false;
  int _reactRounds = 0, _reactHits = 0;

  // hold
  bool _holding = false;
  double _gauge = 0.2;
  double _inZone = 0;
  double _band = 0.6;

  @override
  void initState() {
    super.initState();
    _showAt = 0.6 + widget.rng.nextDouble() * 0.8;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _newZone() => 0.2 + widget.rng.nextDouble() * 0.6;

  void _say(String s) {
    _feedback = s;
    _feedbackAt = _t;
  }

  Duration _last = Duration.zero;

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_over) return;
    setState(() {
      _t = elapsed.inMicroseconds / 1e6;
      switch (widget.spec.kind) {
        case MiniKind.targets:
          if (_t >= _nextSpawn && _t < _total - 0.4) {
            final good = widget.rng.nextDouble() < 0.72;
            final pool = good ? widget.spec.good : widget.spec.bad;
            _targets.add(_Target(0.12 + widget.rng.nextDouble() * 0.76, 0.12 + widget.rng.nextDouble() * 0.76, pool[widget.rng.nextInt(pool.length)], good, _t));
            if (good) _goodSpawned++;
            _nextSpawn = _t + max(0.12, _total / 11);
          }
          for (final tg in _targets) {
            if (_t - tg.born > max(0.3, _total / 6)) tg.gone = true;
          }
        case MiniKind.timing:
          // 라운드가 갈수록 빨라진다
          _phase += dt * (1.1 + _round * 0.25) * (6 / _total).clamp(0.6, 30);
        case MiniKind.reaction:
          if (!_armed && _t >= _showAt) _armed = true;
          if (_armed && _t - _showAt > 0.6) {
            // 놓쳤다
            _reactRounds++;
            _armed = false;
            _showAt = _t + 0.5 + widget.rng.nextDouble() * 0.9;
            _say('놓쳤다!');
          }
        case MiniKind.hold:
          _gauge = (_gauge + (_holding ? 0.9 : -0.7) * dt * (6 / _total).clamp(0.6, 30)).clamp(0.0, 1.0);
          _band = 0.55 + 0.18 * sin(_t * 1.3 * (6 / _total).clamp(0.6, 30));
          if ((_gauge - _band).abs() < 0.12) _inZone += dt;
        case MiniKind.mash:
          break;
      }
      final done = _t >= _total || (widget.spec.kind == MiniKind.timing && _round >= _rounds) || (widget.spec.kind == MiniKind.mash && _taps >= _mashGoal);
      if (done) _finish();
    });
  }

  double _score() => switch (widget.spec.kind) {
        MiniKind.targets => _goodSpawned == 0 ? 0 : ((_goodHit - _badHit * 1.5) / max(1, _goodSpawned * 0.8)).clamp(0.0, 1.0),
        MiniKind.mash => (_taps / _mashGoal).clamp(0.0, 1.0),
        MiniKind.timing => _hits / _rounds,
        MiniKind.reaction => _reactRounds == 0 ? 0 : (_reactHits / max(3, _reactRounds)).clamp(0.0, 1.0),
        MiniKind.hold => (_inZone / (_total * 0.8)).clamp(0.0, 1.0),
      };

  void _finish() {
    _over = true;
    _final = _score();
    Future<void>.delayed(Duration(milliseconds: (_total * 140).clamp(10, 900).round()), () {
      if (mounted) widget.onDone(_final!);
    });
  }

  // ───── 입력 ─────
  void _tapTarget(_Target tg) {
    if (_over || tg.gone) return;
    setState(() {
      tg.gone = true;
      if (tg.good) {
        _goodHit++;
        _say('좋아요!');
      } else {
        _badHit++;
        _say('앗! 악플에 낚였다');
      }
    });
  }

  void _tapArea() {
    if (_over) return;
    setState(() {
      switch (widget.spec.kind) {
        case MiniKind.mash:
          _taps++;
        case MiniKind.timing:
          final pos = _markerPos;
          final d = (pos - _zone).abs();
          if (d < 0.09) {
            _hits++;
            _say(d < 0.035 ? '완벽!' : '좋아요!');
          } else {
            _say('빗나감');
          }
          _round++;
          _zone = _newZone();
        case MiniKind.reaction:
          if (_armed) {
            _reactHits++;
            _say('${((_t - _showAt) * 1000).round()}ms!');
          } else {
            _say('너무 빨라요!');
          }
          _reactRounds++;
          _armed = false;
          _showAt = _t + 0.5 + widget.rng.nextDouble() * 0.9;
        default:
          break;
      }
    });
  }

  double get _markerPos => (sin(_phase * pi) + 1) / 2;

  // 테스트용
  @visibleForTesting
  double get markerPos => _markerPos;
  @visibleForTesting
  double get zone => _zone;
  @visibleForTesting
  int get round => _round;

  // ───── 화면 ─────
  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final size = MediaQuery.sizeOf(context);
    final w = min(size.width - 32, 380.0);
    final left = (_total - _t).clamp(0.0, _total);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: w,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: Pal.stroke)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(spec.title, style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900))),
                Text('${left.toStringAsFixed(1)}초', style: const TextStyle(color: Pal.muted, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text(spec.howTo, style: const TextStyle(color: Pal.muted, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: _total == 0 ? 0 : left / _total, minHeight: 5, backgroundColor: Pal.bg, color: Pal.pink),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: const ValueKey('mini-area'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                if (spec.kind == MiniKind.hold) {
                  setState(() => _holding = true);
                } else if (spec.kind != MiniKind.targets) {
                  _tapArea();
                }
              },
              onTapUp: (_) => setState(() => _holding = false),
              onTapCancel: () => setState(() => _holding = false),
              child: Container(
                width: w - 32,
                height: w - 32,
                decoration: BoxDecoration(gradient: Pal.brandSoft, borderRadius: BorderRadius.circular(22)),
                child: LayoutBuilder(builder: (context, box) => _area(box.biggest)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: _over
                  ? Text(
                      '${'⭐' * starsOf(_final!)}${'☆' * (3 - starsOf(_final!))}  ${const ['아쉬워요', '괜찮아요', '잘했어요!', '완벽해요!'][starsOf(_final!)]}',
                      style: const TextStyle(color: Pal.gold, fontSize: 16, fontWeight: FontWeight.w900),
                    )
                  : AnimatedOpacity(
                      opacity: _t - _feedbackAt < 0.6 ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Text(_feedback, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _area(Size box) {
    final spec = widget.spec;
    switch (spec.kind) {
      case MiniKind.targets:
        return Stack(
          children: [
            for (final (i, tg) in _targets.indexed)
              if (!tg.gone)
                Positioned(
                  left: tg.x * box.width - 28,
                  top: tg.y * box.height - 28,
                  child: GestureDetector(
                    key: ValueKey('mini-${tg.good ? 'good' : 'bad'}-$i'),
                    onTap: () => _tapTarget(tg),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Text(tg.icon, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
                ),
          ],
        );
      case MiniKind.mash:
        final v = (_taps / _mashGoal).clamp(0.0, 1.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(scale: 1 + (_taps.isOdd ? 0.08 : 0), duration: const Duration(milliseconds: 60), child: Text(spec.icon, style: const TextStyle(fontSize: 90))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: v, minHeight: 14, backgroundColor: Pal.bg, color: Pal.gold),
              ),
            ),
            const SizedBox(height: 8),
            Text('${(v * 100).round()}% 먹었다!', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
          ],
        );
      case MiniKind.timing:
        final barW = box.width - 40;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${_round.clamp(0, _rounds)} / $_rounds', style: const TextStyle(color: Pal.muted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            SizedBox(
              width: barW,
              height: 70,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(top: 30, left: 0, right: 0, child: Container(height: 10, decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(999)))),
                  Positioned(
                    top: 22,
                    left: (_zone - 0.09) * barW,
                    child: Container(width: 0.18 * barW, height: 26, decoration: BoxDecoration(color: Pal.good.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8))),
                  ),
                  Positioned(top: 0, left: _markerPos * barW - 22, child: Text(spec.icon, style: const TextStyle(fontSize: 36))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('아무 데나 눌러요!', style: TextStyle(color: Pal.muted, fontSize: 12.5)),
          ],
        );
      case MiniKind.reaction:
        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            child: _armed
                ? const Text('❗', key: ValueKey('bang'), style: TextStyle(fontSize: 120))
                : Text('…', key: const ValueKey('wait'), style: TextStyle(fontSize: 60, color: Pal.muted.withValues(alpha: 0.8))),
          ),
        );
      case MiniKind.hold:
        final h = box.height - 60;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(spec.icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(width: 30),
            SizedBox(
              width: 46,
              height: h,
              child: Stack(
                children: [
                  Container(decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(16))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: (_band - 0.12) * h,
                    child: Container(height: 0.24 * h, decoration: BoxDecoration(color: Pal.good.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10))),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: _gauge * (h - 14),
                    child: Container(height: 14, decoration: BoxDecoration(color: Pal.pink, borderRadius: BorderRadius.circular(7))),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(width: 60, child: Text(_holding ? '꾹…' : '눌러서\n올리기', style: const TextStyle(color: Pal.muted, fontSize: 12.5))),
          ],
        );
    }
  }
}
