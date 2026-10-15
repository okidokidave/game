import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../game/mine_event.dart';
import '../ui/number_format.dart';
import 'mine_layout.dart';
import 'mine_painter.dart';
import 'sprites.dart';

/// 움직이는 광산 단면도. 위아래로 스크롤되고, 누르면 직접 채굴한다.
/// 인부 머리 위 말풍선이나 위쪽 알림을 누르면 반장이 상황을 처리한다.
class MineScene extends StatefulWidget {
  const MineScene({
    super.key,
    required this.game,
    this.sprites,
    this.onEventTap,
    this.onWorkerTap,
    this.onShowWorkers,
  });

  final GameController game;

  /// 도트 그림. 없으면 (테스트 등) 배경색만 그린다.
  final Sprites? sprites;

  /// 반장이 처리해야 하는 상황을 눌렀을 때.
  final void Function(MineEvent event)? onEventTap;

  /// 승급 준비가 된 인부(⬆)를 눌렀을 때. 인부 번호를 넘긴다.
  final void Function(int slot)? onWorkerTap;

  /// "승급 가능" 알림을 눌렀을 때.
  final VoidCallback? onShowWorkers;

  @override
  State<MineScene> createState() => _MineSceneState();
}

class _MineSceneState extends State<MineScene>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _animTime = ValueNotifier(0);
  final List<GoldPopup> _popups = [];

  /// 인부마다 따로 흐르는 일하는 시간 (층 * 100 + 번호).
  final Map<int, double> _workerTimes = {};
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _realTime = 0;

  GameController get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _animTime.dispose();
    super.dispose();
  }

  double _workerTime(int floor, int worker) =>
      _workerTimes[floor * 100 + worker] ?? 0;

  WorkerLook _look(int floor, int worker) =>
      switch (_game.workerEvent(floor, worker)?.type) {
        MineEventType.fatigue => WorkerLook.tired,
        MineEventType.injury => WorkerLook.injured,
        MineEventType.rest => WorkerLook.resting,
        MineEventType.diamond => WorkerLook.diamond,
        MineEventType.energized => WorkerLook.energized,
        MineEventType.goldVein || null => WorkerLook.normal,
      };

  void _onTick(Duration elapsed) {
    // 앱이 잠깐 멈췄다 돌아와도 인부가 순간이동하지 않게 한 번에 최대 0.1초만 진행한다.
    final dt = min((elapsed - _lastElapsed).inMicroseconds / 1e6, 0.1);
    _lastElapsed = elapsed;
    _realTime += dt;

    final boost = _game.isBoostActive ? GameConfig.boostMultiplier : 1.0;
    _advanceWorkers(dt * boost);
    _popups.removeWhere((p) => _realTime - p.bornAt > GoldPopup.lifetime);
    _animTime.value += dt * boost;
  }

  /// 인부마다 작업 속도만큼 시간을 흘리고, 상자에 광석을 내려놓으면 "+N"을 띄운다.
  /// (보이는 효과일 뿐, 골드는 GameController가 초 단위로 정확하게 계산한다.)
  void _advanceWorkers(double dt) {
    final workers = _game.workers;
    if (workers == 0) return;
    final perDrop = _game.steadyGoldPerSecond / workers * MinerCycle.duration;
    for (var f = 0; f < _game.mineLevel; f++) {
      final count = MineLayout.workersOnFloor(f, workers);
      for (var i = 0; i < count; i++) {
        final key = f * 100 + i;
        final from = _workerTimes[key] ?? 0;
        final to = from + dt * _game.workerSpeed(f, i);
        _workerTimes[key] = to;
        if (MinerCycle.droppedBetween(from, to, f, i)) {
          _popups.add(
            GoldPopup(
              '+${formatGold(perDrop * _game.floorMultiplier(f))}',
              MineLayout.crateX + 7,
              MineLayout.floorTop(f) + MineLayout.floorLine - 20,
              _realTime,
            ),
          );
        }
      }
    }
  }

  void _handleTap(TapUpDetails details, double scale) {
    final pos = details.localPosition / scale;
    final event = _eventAt(pos);
    if (event != null) {
      widget.onEventTap?.call(event);
      return;
    }
    final ready = _readyWorkerAt(pos);
    if (ready != null && widget.onWorkerTap != null) {
      widget.onWorkerTap!(ready);
      return;
    }
    final earned = _game.tap();
    _popups.add(
      GoldPopup('+${formatRate(earned)}', pos.dx, pos.dy - 6, _realTime),
    );
  }

  /// 누른 곳 가까이에 반장을 부르는 인부가 있으면 그 상황.
  MineEvent? _eventAt(Offset pos) {
    for (final e in _game.foremanEvents) {
      final look = _look(e.floor, e.worker);
      final sprite = MinerCycle.sprite(
        look,
        _workerTime(e.floor, e.worker),
        e.floor,
        e.worker,
        _game.equipmentTier,
      );
      final bubble = MinerCycle.bubbleCenter(e.floor, sprite.x, look);
      final body = bubble.translate(0, 14);
      if ((pos - bubble).distance < 12 || (pos - body).distance < 12) {
        return e;
      }
    }
    return null;
  }

  /// 누른 곳 가까이에 승급 준비가 된 인부가 있으면 그 인부 번호.
  int? _readyWorkerAt(Offset pos) {
    for (var f = 0; f < _game.mineLevel; f++) {
      for (var i = 0; i < MineLayout.workersOnFloor(f, _game.workers); i++) {
        final slot = GameController.slotOf(f, i);
        if (!_game.isPromotionReady(slot)) continue;
        final look = _look(f, i);
        final sprite = MinerCycle.sprite(
          look,
          _workerTime(f, i),
          f,
          i,
          _game.equipmentTier,
        );
        final bubble = MinerCycle.bubbleCenter(f, sprite.x, look);
        if ((pos - bubble).distance < 12 ||
            (pos - bubble.translate(0, 14)).distance < 12) {
          return slot;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / MineLayout.sceneWidth;
        final floors = _game.mineLevel;
        // 층이 적어서 화면이 남으면 아래를 깊은 암반으로 채운다.
        final height = max(
          MineLayout.sceneHeight(floors) * scale,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
        );
        return Stack(
          children: [
            SingleChildScrollView(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _handleTap(d, scale),
                child: CustomPaint(
                  size: Size(width, height),
                  painter: MinePainter(
                    sprites: widget.sprites,
                    time: _animTime,
                    realTime: () => _realTime,
                    floors: floors,
                    workers: _game.workers,
                    workerTime: _workerTime,
                    workerLook: _look,
                    hasGoldVein: (f) => _game.floorEvent(f) != null,
                    tool: _game.equipmentTier,
                    workerGrade: (f, i) =>
                        _game.gradeIndexOf(GameController.slotOf(f, i)),
                    promotionReady: (f, i) =>
                        _game.isPromotionReady(GameController.slotOf(f, i)),
                    title: '${_game.mineName}  Lv.$floors',
                    lockedLabel:
                        '🔒 광산 확장하면 B${floors + 1}층이 열려요 '
                        '(${formatGold(_game.mineUpgradeCost)} 골드)',
                    popups: _popups,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: _EventBadges(
                events: _game.events,
                now: DateTime.now(),
                onTap: widget.onEventTap,
                promotionReady: _game.promotionReadyCount,
                onShowWorkers: widget.onShowWorkers,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 광산 아래쪽에 떠 있는 상황 알림. 층이 화면 밖이어도 놓치지 않게 한다.
class _EventBadges extends StatelessWidget {
  const _EventBadges({
    required this.events,
    required this.now,
    this.onTap,
    this.promotionReady = 0,
    this.onShowWorkers,
  });

  final List<MineEvent> events;
  final DateTime now;
  final void Function(MineEvent event)? onTap;
  final int promotionReady;
  final VoidCallback? onShowWorkers;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final e in events)
        if (e.type.needsForeman || e.type == MineEventType.goldVein) e,
    ];
    if (shown.isEmpty && promotionReady == 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in shown) _badge(e),
        if (promotionReady > 0)
          _chip(
            '⬆ 승급 가능 $promotionReady명  ›',
            const Color(0xFF2E7D32),
            onShowWorkers,
          ),
      ],
    );
  }

  Widget _badge(MineEvent e) {
    final floor = 'B${e.floor + 1}';
    final (icon, label, color) = switch (e.type) {
      MineEventType.fatigue => ('💦', '$floor 인부 지침', const Color(0xFFB8432F)),
      MineEventType.injury => ('🩹', '$floor 인부 부상', const Color(0xFFB8432F)),
      MineEventType.diamond => (
        '💎',
        '$floor 다이아 발견!',
        const Color(0xFF2A7FA8),
      ),
      MineEventType.goldVein => ('✨', '$floor 금맥 ×3', const Color(0xFF9C7A12)),
      _ => ('', '', Colors.transparent),
    };
    final left = e.remaining(now);
    final timer = e.endsAt == null || e.type == MineEventType.injury
        ? ''
        : ' ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final tappable = e.type.needsForeman && onTap != null;
    return _chip(
      '$icon $label$timer${tappable ? '  ›' : ''}',
      color,
      tappable ? () => onTap!(e) : null,
    );
  }

  Widget _chip(String text, Color color, VoidCallback? onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
