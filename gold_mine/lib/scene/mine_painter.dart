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

      for (var i = 0; i < count; i++) {
        final pose = MinerCycle.pose(t, floor, i);
        s.miner.draw(
          c,
          pose.frame,
          pose.x,
          top + MineLayout.floorLine - MineLayout.minerHeight + 1,
          flip: pose.facingLeft,
        );
        if (pose.action == MinerAction.mine && pose.frame == 10) {
          _debris(c, pose.x, top + MineLayout.floorLine - 8, t, floor, i);
        }
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

  void _lamp(Canvas c, double x, double y, double t) {
    final flicker = 0.18 + 0.04 * sin(t * 9 + x);
    c.drawCircle(
      Offset(x, y + 1),
      9,
      Paint()..color = const Color(0xFFFFD35A).withValues(alpha: flicker),
    );
    _rect(c, x - 1, y, 2, 2, const Color(0xFFFFE9A0));
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
