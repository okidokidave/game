import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../ui/number_format.dart';
import 'mine_layout.dart';
import 'mine_painter.dart';
import 'sprites.dart';

/// 움직이는 광산 단면도. 위아래로 스크롤되고, 누르면 직접 채굴한다.
class MineScene extends StatefulWidget {
  const MineScene({super.key, required this.game, this.sprites});

  final GameController game;

  /// 도트 그림. 없으면 (테스트 등) 배경색만 그린다.
  final Sprites? sprites;

  @override
  State<MineScene> createState() => _MineSceneState();
}

class _MineSceneState extends State<MineScene>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _animTime = ValueNotifier(0);
  final List<GoldPopup> _popups = [];
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

  void _onTick(Duration elapsed) {
    // 앱이 잠깐 멈췄다 돌아와도 인부가 순간이동하지 않게 한 번에 최대 0.1초만 진행한다.
    final dt = min((elapsed - _lastElapsed).inMicroseconds / 1e6, 0.1);
    _lastElapsed = elapsed;
    _realTime += dt;

    final speed = _game.isBoostActive ? GameConfig.boostMultiplier : 1.0;
    final from = _animTime.value;
    final to = from + dt * speed;
    _spawnDropPopups(from, to);
    _popups.removeWhere((p) => _realTime - p.bornAt > GoldPopup.lifetime);
    _animTime.value = to;
  }

  /// 인부가 상자에 광석을 내려놓을 때 "+N"을 띄운다 (보이는 효과일 뿐,
  /// 골드는 GameController가 초 단위로 정확하게 계산한다).
  void _spawnDropPopups(double from, double to) {
    final workers = _game.workers;
    if (workers == 0) return;
    final perDrop = _game.baseGoldPerSecond / workers * MinerCycle.duration;
    for (var f = 0; f < _game.mineLevel; f++) {
      final count = MineLayout.workersOnFloor(f, workers);
      for (var i = 0; i < count; i++) {
        if (MinerCycle.droppedBetween(from, to, f, i)) {
          _popups.add(
            GoldPopup(
              '+${formatGold(perDrop)}',
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
    final earned = _game.tap();
    final pos = details.localPosition / scale;
    _popups.add(
      GoldPopup('+${formatRate(earned)}', pos.dx, pos.dy - 6, _realTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = width / MineLayout.sceneWidth;
        final floors = _game.mineLevel;
        final height = MineLayout.sceneHeight(floors) * scale;
        return SingleChildScrollView(
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
                title: '${_game.mineName}  Lv.$floors',
                lockedLabel:
                    '🔒 광산 확장하면 B${floors + 1}층이 열려요 '
                    '(${formatGold(_game.mineUpgradeCost)} 골드)',
                popups: _popups,
              ),
            ),
          ),
        );
      },
    );
  }
}
