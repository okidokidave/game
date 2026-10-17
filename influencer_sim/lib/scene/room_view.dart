import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../game/game_controller.dart';
import '../game/game_state.dart';
import 'room_painter.dart';

/// 움직이는 도트 방. 상태가 바뀌면 고정된 부분(방, 가구)을 다시 그리고,
/// 캐릭터와 효과는 0.09초마다 한 번씩 움직인다.
class RoomView extends StatefulWidget {
  const RoomView({super.key, required this.state, required this.mode, this.effects});

  final GameState state;

  /// idle / live / sleep / away / stand
  final String mode;
  final Stream<RoomEffect>? effects;

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> with SingleTickerProviderStateMixin {
  static const _frame = Duration(milliseconds: 90);

  late final Ticker _ticker;
  final _rng = Random();
  final List<Particle> _particles = [];
  StreamSubscription<RoomEffect>? _sub;
  Duration _last = Duration.zero;
  int _tick = 0;

  ui.Image? _back;
  ui.Image? _front;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _sub = widget.effects?.listen((e) => _particles.addAll(burstParticles(e.kind, e.count, _rng)));
  }

  @override
  void didUpdateWidget(RoomView old) {
    super.didUpdateWidget(old);
    if (old.effects != widget.effects) {
      _sub?.cancel();
      _sub = widget.effects?.listen((e) => _particles.addAll(burstParticles(e.kind, e.count, _rng)));
    }
  }

  // 방 모양을 바꾸는 값들. 이 값이 그대로면 다시 그리지 않는다.
  String _sig(GameState s) {
    final trophies = s.followers >= 1000000 ? 3 : (s.followers >= 100000 ? 2 : (s.followers >= 10000 ? 1 : 0));
    final gifts = s.coreFans >= 50000 ? 4 : (s.coreFans >= 5000 ? 3 : (s.coreFans >= 500 ? 2 : (s.coreFans >= 50 ? 1 : 0)));
    return '${s.gear.values.join(',')}|${s.deco.join(',')}|$trophies|${min(s.slot, 2)}|${s.wallColor}|${widget.mode == 'apology'}|${s.house}'
        '|${s.business.join(',')}|${s.flags.contains('mcn')}|${s.flags.contains('goodsDone')}|$gifts';
  }

  void _redrawIfNeeded() {
    final sig = _sig(widget.state);
    if (sig == _signature && _back != null) return;
    _signature = sig;
    _back?.dispose();
    _front?.dispose();
    _back = drawBack(widget.state, apology: widget.mode == 'apology');
    _front = drawFront(widget.state);
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _last < _frame) return;
    _last = elapsed;
    _tick++;
    // 방송 중 하트·채팅 풍선 (사과 방송 중에는 뜨지 않는다)
    if (widget.mode == 'live' && _tick % 4 == 0) {
      _particles.addAll(burstParticles(_rng.nextDouble() < 0.7 ? 'heart' : 'chat', 1, _rng));
    }
    if (widget.mode == 'sleep' && _tick % 10 == 0) _particles.add(sleepParticle(widget.state));
    for (final p in _particles) {
      p.y += p.vy;
      p.x += sin((p.life + p.y) / 4) * 0.3;
      p.life--;
    }
    _particles.removeWhere((p) => p.life <= 0);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    _back?.dispose();
    _front?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _redrawIfNeeded();
    return AspectRatio(
      aspectRatio: roomW / roomH,
      child: CustomPaint(
        painter: RoomPainter(state: widget.state, mode: widget.mode, back: _back!, front: _front!, tick: _tick, particles: _particles),
      ),
    );
  }
}
