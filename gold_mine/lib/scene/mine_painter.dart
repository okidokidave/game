import 'dart:math';

import 'package:flutter/material.dart';

import 'mine_layout.dart';
import 'sprites.dart';

/// 화면에 잠깐 떠올랐다 사라지는 "+N" 글자.
class GoldPopup {
  GoldPopup(this.text, this.x, this.y, this.bornAt);

  final String text;
  final double x; // 도트 좌표
  final double y;
  final double bornAt; // 실제 시간(초)

  static const double lifetime = 1.1;
}

/// 광산 단면도 전체를 그린다. 좌표는 [MineLayout]의 도트 단위.
class MinePainter extends CustomPainter {
  MinePainter({
    required this.sprites,
    required this.time,
    required this.realTime,
    required this.floors,
    required this.workers,
    required this.workerTime,
    required this.workerLook,
    required this.hasGoldVein,
    required this.tool,
    required this.title,
    required this.lockedLabel,
    required this.popups,
  }) : super(repaint: time);

  final Sprites? sprites;

  /// 애니메이션 시간 (부스트 중에는 빨리 흐른다).
  final ValueNotifier<double> time;

  /// 실제 흐른 시간 (글자 효과용).
  final double Function() realTime;

  final int floors;
  final int workers;

  /// 인부마다 따로 흐르는 일하는 시간 (지치면 느리게, 쉬면 멈춤).
  final double Function(int floor, int worker) workerTime;
  final WorkerLook Function(int floor, int worker) workerLook;
  final bool Function(int floor) hasGoldVein;

  /// 지금 쓰는 채굴 장비 (Tool.pickaxe ~ Tool.machine).
  final int tool;
  final String title;
  final String lockedLabel;
  final List<GoldPopup> popups;

  static const _sky = Color(0xFF7CC8F2);
  static const _skyLow = Color(0xFFC4E8F7);
  static const _grass = Color(0xFF5FB246);
  static const _grassDark = Color(0xFF3F8A34);
  static const _wood = Color(0xFF96623A);
  static const _woodDark = Color(0xFF6B4423);
  static const _woodLight = Color(0xFFBA824C);
  static const _shaft = Color(0xFF1B1410);
  static const _rail = Color(0xFF7D8A96);
  static const _rope = Color(0xFF3A3028);

  final Paint _fill = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / MineLayout.sceneWidth;
    canvas.save();
    canvas.scale(scale);
    final t = time.value;

    _paintSurface(canvas, t);
    for (var f = 0; f < floors; f++) {
      _paintFloor(canvas, f, t);
    }
    _paintLockedFloor(canvas);
    _paintBedrock(canvas, size.height / scale);
    _paintShaft(canvas, t);
    _paintPopups(canvas);

    canvas.restore();
  }

  // ── 지상 ────────────────────────────────────────────
  void _paintSurface(Canvas c, double t) {
    const w = MineLayout.sceneWidth;
    const ground = MineLayout.groundY;

    // 하늘 (아래로 갈수록 밝게, 도트 느낌이 나도록 띠로 나눈다)
    for (var i = 0; i < 6; i++) {
      final color = Color.lerp(_sky, _skyLow, i / 5)!;
      _rect(c, 0, i * ground / 6, w, ground / 6 + 0.5, color);
    }
    // 해
    _rect(c, 84, 5, 8, 8, const Color(0xFFFFE36E));
    _rect(c, 85, 6, 6, 6, const Color(0xFFFFF3A8));

    final s = sprites;
    if (s != null) {
      for (var i = 0; i < 2; i++) {
        final x = (t * 2.5 + i * 70) % (w + 24) - 22;
        s.cloud.draw(c, 0, x, 6 + i * 9.0);
      }
    }

    // 땅
    if (s != null) {
      for (var x = 0.0; x < w; x += 16) {
        s.dirt.draw(c, 0, x, ground);
      }
    }
    _rect(c, 0, ground, w, 2, _grass);
    _rect(c, 0, ground + 2, w, 1, _grassDark);

    // 광차 레일
    _rect(c, 30, ground - 1, 70, 1, _rail);

    if (s != null) {
      s.warehouse.draw(c, 0, 1, ground - 28);
      final (cartX, loaded, moving) = CartMotion.at(t);
      final wheel = moving ? (t * 6).floor() % 2 : 0;
      s.cart.draw(c, (loaded ? 2 : 0) + wheel, cartX, ground - 13);
    }

    // 엘리베이터 탑 (나무 기둥과 도르래)
    _rect(c, MineLayout.shaftLeft, 5, 2, ground - 5, _woodDark);
    _rect(c, MineLayout.shaftRight - 2, 5, 2, ground - 5, _woodDark);
    _rect(c, MineLayout.shaftLeft - 1, 4, 22, 2, _wood);
    _rect(c, MineLayout.shaftLeft + 2, 18, 16, 1, _woodDark);
    s?.wheel.draw(c, (t * 4).floor() % 2, 103, 0);

    _text(c, title, 38, 2, 5, Colors.white, shadow: true, bold: true);
  }

  // ── 땅속 층 ─────────────────────────────────────────
  void _paintFloor(Canvas c, int floor, double t) {
    final top = MineLayout.floorTop(floor);
    final theme = MineLayout.theme(floor);
    final s = sprites;

    if (s != null) {
      for (var y = top; y < top + MineLayout.floorHeight; y += 16) {
        for (var x = 0.0; x < MineLayout.sceneWidth; x += 16) {
          s.dirt.draw(c, theme, x, y);
        }
      }
      for (
        var y = top + MineLayout.tunnelTop;
        y < top + MineLayout.floorLine;
        y += 16
      ) {
        for (var x = 0.0; x < MineLayout.tunnelRight; x += 16) {
          s.tunnel.draw(c, theme, x, y);
        }
      }
    } else {
      _rect(
        c,
        0,
        top,
        MineLayout.sceneWidth,
        MineLayout.floorHeight,
        const Color(0xFF5C4030),
      );
      _rect(
        c,
        0,
        top + MineLayout.tunnelTop,
        MineLayout.tunnelRight,
        MineLayout.floorLine - MineLayout.tunnelTop,
        const Color(0xFF2E2018),
      );
    }

    // 버팀목과 등불
    for (final bx in const [44.0, 74.0]) {
      _rect(
        c,
        bx,
        top + MineLayout.tunnelTop,
        2,
        MineLayout.floorLine - MineLayout.tunnelTop,
        _woodDark,
      );
      _lamp(c, bx + 1, top + MineLayout.tunnelTop + 5, t);
    }
    _rect(c, 0, top + MineLayout.tunnelTop, MineLayout.tunnelRight, 2, _wood);
    _rect(
      c,
      0,
      top + MineLayout.tunnelTop + 2,
      MineLayout.tunnelRight,
      1,
      _woodDark,
    );

    // 바닥 판자
    _rect(
      c,
      0,
      top + MineLayout.floorLine,
      MineLayout.tunnelRight,
      2,
      _woodLight,
    );
    _rect(
      c,
      0,
      top + MineLayout.floorLine + 2,
      MineLayout.tunnelRight,
      1,
      _woodDark,
    );

    final count = MineLayout.workersOnFloor(floor, workers);
    if (s != null) {
      s.wall.draw(c, theme, 0, top + 2);
      s.crate.draw(
        c,
        count == 0 ? 0 : (count >= 2 ? 2 : 1),
        MineLayout.crateX,
        top + MineLayout.floorLine - 12,
      );

      if (hasGoldVein(floor)) _goldVein(c, top, t);
      if (tool == Tool.machine && count > 0) {
        s.machine.draw(
          c,
          (t * 8).floor() % 2,
          MinerCycle.machineX,
          top + MineLayout.floorLine - 21,
        );
        _sparks(
          c,
          MinerCycle.machineX + 1,
          top + MineLayout.floorLine - 11,
          t,
          floor,
        );
      }

      for (var i = 0; i < count; i++) {
        final look = workerLook(floor, i);
        final sprite = MinerCycle.sprite(
          look,
          workerTime(floor, i),
          floor,
          i,
          tool,
        );
        s.miner.draw(
          c,
          sprite.frame,
          sprite.x,
          top + MineLayout.floorLine - MineLayout.minerHeight + 1,
          flip: sprite.flip,
        );
        if (sprite.action == MinerAction.mine) {
          _toolEffect(c, sprite, top, t, floor, i);
        }
        _workerMark(c, look, floor, sprite.x, t);
      }
    }

    _text(
      c,
      'B${floor + 1}',
      22,
      top + MineLayout.tunnelTop + 4,
      5,
      Colors.white70,
      bold: true,
    );
  }

  /// 인부 머리 위 말풍선 (돌발상황, 좋은 일).
  void _workerMark(Canvas c, WorkerLook look, int floor, double x, double t) {
    final (icon, border) = switch (look) {
      WorkerLook.tired => ('💦', const Color(0xFFE5533D)),
      WorkerLook.injured => ('🩹', const Color(0xFFE5533D)),
      WorkerLook.diamond => ('💎', const Color(0xFF5BC8F5)),
      WorkerLook.resting => ('💤', const Color(0xFF9AA4B0)),
      WorkerLook.energized => ('⚡', const Color(0xFFFFC83D)),
      WorkerLook.normal => ('', const Color(0x00000000)),
    };
    if (icon.isEmpty) return;
    final center = MinerCycle.bubbleCenter(floor, x, look);
    // 반장을 부르는 말풍선은 살짝 통통 튄다.
    final needsForeman =
        look == WorkerLook.tired ||
        look == WorkerLook.injured ||
        look == WorkerLook.diamond;
    final bob = needsForeman ? (sin(t * 6) > 0 ? -1.0 : 0.0) : 0.0;
    final rect = Rect.fromCenter(
      center: center.translate(0, bob),
      width: 11,
      height: 9,
    );
    _rect(
      c,
      rect.left - 1,
      rect.top - 1,
      rect.width + 2,
      rect.height + 2,
      border,
    );
    _rect(c, rect.left, rect.top, rect.width, rect.height, Colors.white);
    _rect(c, center.dx - 1, rect.bottom + 1, 2, 1, border); // 말풍선 꼬리
    _rect(c, center.dx - 0.5, rect.bottom + 2, 1, 1, border);
    _text(c, icon, center.dx, rect.top + 0.6, 5.5, Colors.black, center: true);
    if (look == WorkerLook.diamond) _sparkle(c, x + 18, center.dy + 10, t);
  }

  /// 반짝이는 십자 빛.
  void _sparkle(Canvas c, double x, double y, double t) {
    final on = (t * 4).floor() % 2 == 0;
    const color = Color(0xFFE6FAFF);
    _rect(c, x, y, 1, 1, color);
    if (on) {
      _rect(c, x - 2, y, 5, 1, color.withValues(alpha: 0.8));
      _rect(c, x, y - 2, 1, 5, color.withValues(alpha: 0.8));
    }
  }

  /// 금맥: 암벽과 굴 천장에서 금빛이 반짝인다.
  void _goldVein(Canvas c, double top, double t) {
    const spots = [
      (4.0, 8.0),
      (10.0, 20.0),
      (6.0, 28.0),
      (14.0, 12.0),
      (30.0, 6.0),
      (58.0, 5.0),
      (86.0, 7.0),
      (2.0, 16.0),
    ];
    for (var k = 0; k < spots.length; k++) {
      final (sx, sy) = spots[k];
      if (((t * 3).floor() + k) % 3 == 0) continue;
      _rect(c, sx, top + sy, 2, 2, const Color(0xFFFFE36E));
      _rect(c, sx, top + sy, 1, 1, Colors.white);
    }
    _text(
      c,
      '✨ ×3',
      60,
      top + MineLayout.tunnelTop + 4,
      5,
      const Color(0xFFFFE36E),
      shadow: true,
      bold: true,
    );
  }

  void _lamp(Canvas c, double x, double y, double t) {
    final flicker = 0.18 + 0.04 * sin(t * 9 + x);
    c.drawCircle(
      Offset(x, y + 1),
      9,
      Paint()..color = const Color(0xFFFFD35A).withValues(alpha: flicker),
    );
    _rect(c, x - 1, y, 2, 2, const Color(0xFFFFE9A0));
  }

  /// 장비마다 다른 채굴 효과.
  void _toolEffect(
    Canvas c,
    WorkerSprite sprite,
    double top,
    double t,
    int floor,
    int i,
  ) {
    final ground = top + MineLayout.floorLine;
    switch (tool) {
      case Tool.pickaxe:
        if (sprite.frame == 10) _debris(c, sprite.x, ground - 8, t, floor, i);
      case Tool.drill:
        _dust(c, sprite.x - 1, ground - 9, t, floor, i);
      case Tool.dynamite:
        _dynamite(c, sprite.phase, ground, t);
      case Tool.machine:
        break; // 기계 쪽에서 불꽃을 그린다
    }
  }

  /// 드릴이 벽을 뚫을 때 날리는 돌가루.
  void _dust(Canvas c, double x, double y, double t, int floor, int i) {
    for (var k = 0; k < 4; k++) {
      final p = (t * 5 + k * 0.25 + floor * 0.3 + i * 0.5) % 1;
      _rect(
        c,
        x + p * 6,
        y - 2 + k * 1.5 - p * 3,
        1,
        1,
        Color.lerp(const Color(0xFFD8CBB8), const Color(0x00D8CBB8), p)!,
      );
    }
  }

  /// 다이너마이트: 심지가 타다가 펑!
  void _dynamite(Canvas c, double phase, double ground, double t) {
    const wallX = 14.0;
    if (phase < MinerCycle.dynamitePlantEnd) return;
    if (phase < MinerCycle.dynamiteBlast) {
      _rect(c, wallX, ground - 10, 2, 5, const Color(0xFFC82828));
      if ((t * 12).floor() % 2 == 0) {
        _rect(c, wallX + 1, ground - 12, 1, 1, const Color(0xFFFFF3A0));
        _rect(c, wallX, ground - 13, 1, 1, const Color(0xFFFF9A3C));
      }
      return;
    }
    // 폭발: 커지면서 사라지는 불꽃과 연기
    final p =
        (phase - MinerCycle.dynamiteBlast) / (1 - MinerCycle.dynamiteBlast);
    final center = Offset(wallX + 1, ground - 8);
    c.drawCircle(
      center,
      4 + p * 10,
      Paint()..color = const Color(0xFF8A8580).withValues(alpha: 0.5 * (1 - p)),
    );
    c.drawCircle(
      center,
      3 + p * 7,
      Paint()..color = const Color(0xFFFF8A2A).withValues(alpha: 0.9 * (1 - p)),
    );
    c.drawCircle(
      center,
      2 + p * 3,
      Paint()..color = const Color(0xFFFFF0A0).withValues(alpha: 1 - p),
    );
    for (var k = 0; k < 6; k++) {
      final angle = k * pi / 3 + 0.4;
      final r = 3 + p * 14;
      _rect(
        c,
        center.dx + cos(angle) * r,
        center.dy + sin(angle) * r * 0.7,
        1,
        1,
        const Color(0xFFFFD35A).withValues(alpha: 1 - p),
      );
    }
  }

  /// 굴착 기계 드릴 끝의 불꽃.
  void _sparks(Canvas c, double x, double y, double t, int floor) {
    for (var k = 0; k < 3; k++) {
      final p = (t * 6 + k / 3 + floor * 0.2) % 1;
      _rect(
        c,
        x + 2 + p * 5,
        y - 3 + k * 2 - p * 4,
        1,
        1,
        Color.lerp(const Color(0xFFFFF3A0), const Color(0x00FF8A2A), p)!,
      );
    }
  }

  /// 곡괭이가 바위를 찍을 때 튀는 돌 조각.
  void _debris(Canvas c, double minerX, double y, double t, int floor, int i) {
    final phase = (t * 10 + floor + i) % 1;
    for (var k = 0; k < 3; k++) {
      final dx = 4 + k * 3 + phase * 4;
      final dy = -2 - k * 2 + phase * 3;
      _rect(c, minerX + dx, y + dy, 1, 1, const Color(0xFFFFE07A));
    }
  }

  // ── 아직 열리지 않은 층 ──────────────────────────────
  void _paintLockedFloor(Canvas c) {
    final top = MineLayout.floorTop(floors);
    final s = sprites;
    final theme = MineLayout.theme(floors);
    if (s != null) {
      for (var y = top; y < top + MineLayout.lockedHeight; y += 16) {
        for (var x = 0.0; x < MineLayout.sceneWidth; x += 16) {
          s.dirt.draw(c, theme, x, y);
        }
      }
    }
    _rect(
      c,
      0,
      top,
      MineLayout.sceneWidth,
      MineLayout.lockedHeight,
      Colors.black.withValues(alpha: 0.55),
    );
    _text(c, lockedLabel, 6, top + 11, 4.5, Colors.white70);
  }

  /// 잠긴 층 아래 남는 공간을 어두운 암반으로 채운다.
  void _paintBedrock(Canvas c, double bottom) {
    final top = MineLayout.floorTop(floors) + MineLayout.lockedHeight;
    if (bottom <= top) return;
    final s = sprites;
    if (s != null) {
      final theme = MineLayout.theme(floors + 1);
      for (var y = top; y < bottom; y += 16) {
        for (var x = 0.0; x < MineLayout.sceneWidth; x += 16) {
          s.dirt.draw(c, theme, x, y);
        }
      }
    }
    _rect(
      c,
      0,
      top,
      MineLayout.sceneWidth,
      bottom - top,
      Colors.black.withValues(alpha: 0.75),
    );
  }

  // ── 엘리베이터 통로 ─────────────────────────────────
  void _paintShaft(Canvas c, double t) {
    const left = MineLayout.shaftLeft;
    const width = MineLayout.shaftRight - MineLayout.shaftLeft;
    final bottom = MineLayout.floorTop(floors);
    _rect(
      c,
      left,
      MineLayout.groundY + 3,
      width,
      bottom - MineLayout.groundY,
      _shaft,
    );
    // 각 층과 이어지는 입구
    for (var f = 0; f < floors; f++) {
      final top = MineLayout.floorTop(f);
      _rect(
        c,
        MineLayout.tunnelRight,
        top + MineLayout.tunnelTop,
        left - 96,
        MineLayout.floorLine - MineLayout.tunnelTop,
        _shaft,
      );
      _rect(
        c,
        MineLayout.tunnelRight,
        top + MineLayout.floorLine,
        width + 2,
        2,
        _woodLight,
      );
    }
    _rect(
      c,
      left,
      MineLayout.groundY + 3,
      1,
      bottom - MineLayout.groundY - 3,
      _rail,
    );
    _rect(
      c,
      MineLayout.shaftRight - 1,
      MineLayout.groundY + 3,
      1,
      bottom - MineLayout.groundY - 3,
      _rail,
    );

    final (cageY, loaded) = ElevatorMotion.at(t, floors);
    _rect(c, 108, 6, 1, cageY - 6, _rope);
    sprites?.cage.draw(c, loaded ? 1 : 0, left + 2, cageY);
  }

  // ── 글자 ────────────────────────────────────────────
  void _paintPopups(Canvas c) {
    final now = realTime();
    for (final p in popups) {
      final age = (now - p.bornAt) / GoldPopup.lifetime;
      if (age < 0 || age > 1) continue;
      _text(
        c,
        p.text,
        p.x,
        p.y - age * 10,
        5.5,
        Color.lerp(const Color(0xFFFFE36E), const Color(0x00FFE36E), age)!,
        shadow: age < 0.7,
        bold: true,
        center: true,
      );
    }
  }

  void _text(
    Canvas c,
    String text,
    double x,
    double y,
    double size,
    Color color, {
    bool shadow = false,
    bool bold = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          shadows: shadow
              ? const [Shadow(color: Colors.black87, offset: Offset(0.6, 0.6))]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? x - painter.width / 2 : x;
    painter.paint(c, Offset(dx, y));
  }

  @override
  bool shouldRepaint(MinePainter old) => true;
}
