import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_service.dart';
import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../game/mine_event.dart';
import '../ui/number_format.dart';
import 'mine_layout.dart';
import 'mine_painter.dart';
import 'sprites.dart';

/// 움직이는 광산 단면도. 위아래로 스크롤되고, 누르면 직접 채굴한다.
/// 인부 머리 위 말풍선이나 위쪽 알림을 누르면 소장이 상황을 처리한다.
class MineScene extends StatefulWidget {
  const MineScene({
    super.key,
    required this.game,
    this.sprites,
    this.onEventTap,
    this.onWorkerTap,
    this.onShowWorkers,
    this.onWorkerCare,
    this.onOpenShop,
    this.sound,
  });

  /// 지치거나 쓰러진 인부를 눌렀을 때. 인부 번호를 넘긴다.
  final void Function(int slot)? onWorkerCare;

  /// 지상 매점을 눌렀을 때.
  final VoidCallback? onOpenShop;

  /// 터치, 광석 내려놓기, 폭발 소리 (없으면 조용히).
  final SoundService? sound;

  final GameController game;

  /// 도트 그림. 없으면 (테스트 등) 배경색만 그린다.
  final Sprites? sprites;

  /// 소장이 처리해야 하는 상황을 눌렀을 때.
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

  WorkerLook _look(int floor, int worker) {
    switch (_game.workerEvent(floor, worker)?.type) {
      case MineEventType.injury:
        return WorkerLook.injured;
      case MineEventType.rest:
        return WorkerLook.resting;
      case MineEventType.diamond:
        return WorkerLook.diamond;
      case MineEventType.energized:
        return WorkerLook.energized;
      case MineEventType.fatigue:
      case MineEventType.goldVein:
      case MineEventType.flood:
      case MineEventType.bailing:
      case MineEventType.ghost:
      case MineEventType.exorcism:
      case MineEventType.blessing:
      case null:
        break;
    }
    switch (_game.floorEvent(floor)?.type) {
      case MineEventType.ghost:
      case MineEventType.exorcism:
        return WorkerLook.scared;
      case MineEventType.bailing:
        return WorkerLook.bailing;
      default:
        break;
    }
    final slot = GameController.slotOf(floor, worker);
    if (_game.isCollapsed(slot)) return WorkerLook.collapsed;
    if (_game.isTired(slot)) return WorkerLook.tired;
    return WorkerLook.normal;
  }

  void _onTick(Duration elapsed) {
    // 앱이 잠깐 멈췄다 돌아와도 인부가 순간이동하지 않게 한 번에 최대 0.1초만 진행한다.
    final dt = min((elapsed - _lastElapsed).inMicroseconds / 1e6, 0.1);
    _lastElapsed = elapsed;
    _realTime += dt;

    final boost = _game.isBoostActive ? GameConfig.boostMultiplier : 1.0;
    _advanceWorkers(dt * boost);
    _advanceCyborgs(dt * boost);
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
        if (_game.equipmentTier == Tool.dynamite &&
            _blastedBetween(from, to, f, i)) {
          widget.sound?.play(Sfx.blast);
          widget.sound?.vibrate(Buzz.heavy);
        }
        _workerTimes[key] = to;
        if (MinerCycle.droppedBetween(from, to, f, i)) {
          widget.sound?.play(Sfx.coin);
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

  /// 이 인부의 다이너마이트가 시간 [from]~[to] 사이에 터졌는지.
  bool _blastedBetween(double from, double to, int floor, int worker) {
    final a = MinerCycle.pose(from, floor, worker, Tool.dynamite);
    final b = MinerCycle.pose(to, floor, worker, Tool.dynamite);
    return a.action == MinerAction.mine &&
        b.action == MinerAction.mine &&
        a.phase < MinerCycle.dynamiteBlast &&
        b.phase >= MinerCycle.dynamiteBlast;
  }

  /// 사이보그 인부들: 지치지 않고 늘 같은 속도로 일한다.
  void _advanceCyborgs(double dt) {
    final floors = _game.mineLevel;
    final cyborgs = _game.cyborgs;
    if (cyborgs == 0) return;
    final perDrop = _game.cyborgGoldPerSecond / cyborgs * MinerCycle.duration;
    for (var f = 0; f < floors; f++) {
      final here = MineLayout.cyborgsOnFloor(f, cyborgs, floors);
      for (var k = 0; k < here; k++) {
        final key = f * 100 + 50 + k;
        final index = MineLayout.workersPerFloor + k;
        final from = _workerTimes[key] ?? 0;
        final to = from + dt;
        _workerTimes[key] = to;
        if (MinerCycle.droppedBetween(from, to, f, index)) {
          widget.sound?.play(Sfx.coin);
          _popups.add(
            GoldPopup(
              '+${formatGold(perDrop * _game.floorMultiplier(f))}',
              MineLayout.crateX + 7,
              MineLayout.floorTop(f) + MineLayout.floorLine - 26,
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
    if (_isKiosk(pos)) {
      widget.onOpenShop?.call();
      return;
    }
    final tired = _exhaustedWorkerAt(pos);
    if (tired != null && widget.onWorkerCare != null) {
      widget.onWorkerCare!(tired);
      return;
    }
    final ready = _readyWorkerAt(pos);
    if (ready != null && widget.onWorkerTap != null) {
      widget.onWorkerTap!(ready);
      return;
    }
    final earned = _game.tap();
    widget.sound?.play(Sfx.pick);
    widget.sound?.vibrate(Buzz.light);
    _popups.add(
      GoldPopup('+${formatRate(earned)}', pos.dx, pos.dy - 6, _realTime),
    );
  }

  (MineEventType, double)? _floorEvent(int floor) {
    final e = _game.floorEvent(floor);
    if (e == null) return null;
    final end = e.endsAt;
    if (end == null) return (e.type, 0);
    final total = end.difference(e.startedAt).inMilliseconds;
    final left = e.remaining(DateTime.now()).inMilliseconds;
    return (e.type, total <= 0 ? 1 : (1 - left / total).clamp(0.0, 1.0));
  }

  /// 누른 곳 가까이에 소장을 부르는 인부가 있으면 그 상황.
  /// 침수·귀신처럼 층 전체 상황은 그 층 갱도 어디를 눌러도 된다.
  MineEvent? _eventAt(Offset pos) {
    for (final e in _game.managerEvents) {
      if (e.type.isFloorWide) {
        final top = MineLayout.floorTop(e.floor);
        if (pos.dx < MineLayout.tunnelRight &&
            pos.dy >= top &&
            pos.dy <= top + MineLayout.floorLine + 2) {
          return e;
        }
        continue;
      }
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

  bool _isKiosk(Offset pos) =>
      pos.dx >= MineLayout.kioskLeft &&
      pos.dx <= MineLayout.kioskLeft + MineLayout.kioskWidth &&
      pos.dy >= MineLayout.groundY - MineLayout.kioskHeight &&
      pos.dy <= MineLayout.groundY;

  /// 누른 곳 가까이에 지치거나 쓰러진 인부가 있으면 그 인부 번호.
  int? _exhaustedWorkerAt(Offset pos) {
    for (var f = 0; f < _game.mineLevel; f++) {
      for (var i = 0; i < MineLayout.workersOnFloor(f, _game.workers); i++) {
        final look = _look(f, i);
        if (look != WorkerLook.tired && look != WorkerLook.collapsed) continue;
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
          return GameController.slotOf(f, i);
        }
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
                    floorEvent: _floorEvent,
                    tool: _game.equipmentTier,
                    workerGrade: (f, i) =>
                        _game.gradeIndexOf(GameController.slotOf(f, i)),
                    promotionReady: (f, i) =>
                        _game.isPromotionReady(GameController.slotOf(f, i)),
                    themeOf: _game.region.themeOf,
                    cyborgs: _game.cyborgs,
                    cyborgTime: (f, k) => _workerTimes[f * 100 + 50 + k] ?? 0,
                    workerStamina: (f, i) =>
                        _game.staminaOf(GameController.slotOf(f, i)) /
                        GameConfig.maxStamina,
                    bottomFloor: _game.isAtBottom
                        ? _game.region.bottomFloor - 1
                        : null,
                    title: _game.mineName,
                    lockedLabel: _game.isAtBottom
                        ? '⛏ 막장 도달! 막장 인부들이 희귀 광석을 찾아요'
                        : '🔒 광산 확장하면 B${floors + 1}층이 열려요 '
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
                exhausted: _game.exhaustedCount,
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
    this.exhausted = 0,
    this.onShowWorkers,
  });

  final List<MineEvent> events;
  final DateTime now;
  final void Function(MineEvent event)? onTap;
  final int promotionReady;
  final int exhausted;
  final VoidCallback? onShowWorkers;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final e in events)
        if (e.type.needsManager ||
            e.type.isFloorWide ||
            e.type == MineEventType.goldVein)
          e,
    ];
    if (shown.isEmpty && promotionReady == 0 && exhausted == 0) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in shown) _badge(e),
        if (exhausted > 0)
          _chip(
            '😵 지친 인부 $exhausted명  ›',
            const Color(0xFFB8432F),
            onShowWorkers,
          ),
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
      MineEventType.flood => ('💧', '$floor 침수!', const Color(0xFF2A6FA8)),
      MineEventType.bailing => (
        '🪣',
        '$floor 물 퍼내는 중',
        const Color(0xFF3D6E8F),
      ),
      MineEventType.ghost => ('👻', '$floor 귀신 출몰!', const Color(0xFF5E4A8C)),
      MineEventType.exorcism => (
        '🥁',
        '$floor 굿 하는 중',
        const Color(0xFF8C3A4A),
      ),
      MineEventType.blessing => (
        '🪭',
        '$floor 축복 ×${GameConfig.blessingMultiplier.round()}',
        const Color(0xFF9C4A7A),
      ),
      _ => ('', '', Colors.transparent),
    };
    final left = e.remaining(now);
    final timer = e.endsAt == null || e.type == MineEventType.injury
        ? ''
        : ' ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final tappable = e.type.needsManager && onTap != null;
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
