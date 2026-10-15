import 'dart:math';
import 'dart:ui' show Offset;

import '../game/game_config.dart';

/// 광산 단면도의 배치와 움직임 계산.
///
/// 모든 좌표는 "도트 픽셀" 단위다. 화면 너비가 [sceneWidth] 도트가 되도록
/// 확대해서 그린다. 그리기 코드 없이 숫자만 계산하므로 테스트하기 쉽다.
class MineLayout {
  MineLayout._();

  static const double sceneWidth = 120;

  // ── 지상 ────────────────────────────────────────────
  static const double surfaceHeight = 46;
  static const double groundY = 36;

  // ── 층 ──────────────────────────────────────────────
  static const double floorHeight = 40;

  /// 층 안에서 굴(작업 공간)이 시작하는 높이와 바닥 높이.
  static const double tunnelTop = 4;
  static const double floorLine = 34;

  /// 아직 열리지 않은 다음 층의 높이.
  static const double lockedHeight = 30;

  /// 굴의 오른쪽 끝. 그 오른쪽은 엘리베이터 통로.
  static const double tunnelRight = 96;
  static const double shaftLeft = 98;
  static const double shaftRight = 118;

  static const double crateX = 82;

  /// 인부 그림 크기와 서 있는 위치 (그림의 왼쪽 x).
  static const double minerWidth = 24;
  static const double minerHeight = 22;
  static const double mineX = 11; // 암벽 앞 (곡괭이 끝이 바위에 닿는 위치)
  static const double dropX = 62; // 상자 앞

  static const int workersPerFloor = GameConfig.workersPerMineLevel;

  static double floorTop(int floor) => surfaceHeight + floor * floorHeight;

  static double sceneHeight(int floors) =>
      surfaceHeight + floors * floorHeight + lockedHeight;

  /// [floor]층에서 일하는 인부 수.
  static int workersOnFloor(int floor, int totalWorkers) =>
      GameConfig.workersOnFloor(floor, totalWorkers);
}

enum MinerAction { walkToRock, mine, carry, drop }

/// 돌발상황에 따라 달라지는 인부의 모습.
enum WorkerLook { normal, tired, resting, injured, diamond, energized }

/// 그릴 칸 번호와 위치.
class WorkerSprite {
  const WorkerSprite(
    this.frame,
    this.x,
    this.flip, [
    this.action,
    this.phase = 0,
  ]);

  final int frame;
  final double x;
  final bool flip;

  /// 일하는 중이면 하는 일, 멈춰 있으면 null.
  final MinerAction? action;

  /// 채굴 동작 진행도 (0~1).
  final double phase;
}

/// 인부 한 명의 순간 모습.
class MinerPose {
  const MinerPose(
    this.action,
    this.x,
    this.frame,
    this.facingLeft, [
    this.phase = 0,
  ]);

  final MinerAction action;
  final double x;
  final int frame;
  final bool facingLeft;

  /// 채굴 중일 때 채굴 동작이 얼마나 진행됐는지 (0~1).
  final double phase;
}

/// 장비 단계 번호 (GameConfig.equipmentTiers 순서).
abstract final class Tool {
  static const int pickaxe = 0;
  static const int drill = 1;
  static const int dynamite = 2;
  static const int machine = 3;
}

/// 인부의 일 순서: 암벽으로 걸어감 → 곡괭이질 → 광석 지고 돌아옴 → 상자에 내려놓음.
class MinerCycle {
  MinerCycle._();

  static const double walkSpeed = 18; // 도트/초
  static const double swingTime = 0.6;
  static const int swings = 3;
  static const double dropTime = 0.5;

  static double get walkTime =>
      (MineLayout.dropX - MineLayout.mineX) / walkSpeed;
  static double get mineTime => swingTime * swings;

  /// 한 바퀴에 걸리는 시간(초, 부스트 없을 때).
  static double get duration => walkTime * 2 + mineTime + dropTime;

  /// 같은 층 인부들이 겹치지 않게 시작 시점과 위치를 조금씩 다르게 한다.
  static double phaseOffset(int floor, int index) =>
      (index / MineLayout.workersPerFloor + floor * 0.17) * duration;

  static double xOffset(int index) => const [0.0, 4.0, -3.0][index % 3];

  /// 굴착 기계가 놓이는 자리와, 기계를 조종하는 인부의 자리.
  static const double machineX = 6;
  static const double operateX = 26;

  /// 다이너마이트에 불을 붙인 뒤 물러나는 거리.
  static const double dynamiteRetreat = 14;

  /// 장비마다 일하는 자리. 걷는 시간은 같게 해서 한 바퀴 시간이 바뀌지 않는다.
  static double workX(int tool) =>
      tool == Tool.machine ? operateX : MineLayout.mineX;

  static MinerPose pose(
    double time,
    int floor,
    int index, [
    int tool = Tool.pickaxe,
  ]) {
    var t = (time + phaseOffset(floor, index)) % duration;
    final dx = xOffset(index);
    final workAt = workX(tool);
    final walkDistance = MineLayout.dropX - workAt;

    if (t < walkTime) {
      final x = MineLayout.dropX - t / walkTime * walkDistance;
      return MinerPose(MinerAction.walkToRock, x + dx, _walkFrame(t), true);
    }
    t -= walkTime;
    if (t < mineTime) {
      final phase = t / mineTime;
      final (frame, x) = _mineFrame(tool, t, phase, workAt);
      return MinerPose(MinerAction.mine, x + dx, frame, true, phase);
    }
    t -= mineTime;
    if (t < walkTime) {
      final x = workAt + t / walkTime * walkDistance;
      return MinerPose(MinerAction.carry, x + dx, 4 + _walkFrame(t), false);
    }
    return MinerPose(MinerAction.drop, MineLayout.dropX + dx, 11, false);
  }

  /// 장비별 채굴 동작의 그림 칸과 위치.
  static (int, double) _mineFrame(int tool, double t, double phase, double x) {
    switch (tool) {
      case Tool.drill:
        // 드르르륵: 두 칸을 빠르게 번갈아
        return ((t * 14).floor() % 2 == 0 ? 15 : 16, x);
      case Tool.dynamite:
        // 설치 → 물러나 귀 막기 → (폭발은 그림 효과)
        if (phase < dynamitePlantEnd) return (17, x);
        return (18, x + dynamiteRetreat);
      case Tool.machine:
        return (19, x);
      default:
        // 들어 올림 → 휘두름 → 찍기
        final swing = (t % swingTime) / swingTime;
        return (swing < 0.45 ? 8 : (swing < 0.6 ? 9 : 10), x);
    }
  }

  /// 다이너마이트: 설치가 끝나는 시점과 터지는 시점 (채굴 진행도 기준).
  static const double dynamitePlantEnd = 0.4;
  static const double dynamiteBlast = 0.72;

  static int _walkFrame(double t) => (t * 8).floor() % 4;

  static const double restX = 46; // 버팀목 옆에 앉아 쉼
  static const double injuredX = 26; // 바닥에 누움

  /// 인부 모습에 맞는 그림 칸과 위치. [time]은 그 인부의 일하는 시간.
  static WorkerSprite sprite(
    WorkerLook look,
    double time,
    int floor,
    int i, [
    int tool = Tool.pickaxe,
  ]) {
    final dx = xOffset(i);
    switch (look) {
      case WorkerLook.resting:
        return WorkerSprite(12, restX + dx, false);
      case WorkerLook.injured:
        return WorkerSprite(13, injuredX + dx, false);
      case WorkerLook.diamond:
        return WorkerSprite(14, MineLayout.mineX + 8 + dx, false);
      case WorkerLook.normal:
      case WorkerLook.tired:
      case WorkerLook.energized:
        final p = pose(time, floor, i, tool);
        return WorkerSprite(p.frame, p.x, p.facingLeft, p.action, p.phase);
    }
  }

  /// 인부 머리 위 말풍선의 가운데 (도트 좌표).
  /// 누워 있는 인부([look]이 injured)는 말풍선을 낮게 띄운다.
  static Offset bubbleCenter(int floor, double spriteX, WorkerLook look) =>
      Offset(
        spriteX + MineLayout.minerWidth / 2,
        MineLayout.floorTop(floor) +
            MineLayout.floorLine -
            MineLayout.minerHeight -
            5 +
            (look == WorkerLook.injured ? 9 : 0),
      );

  /// 시간 [from]~[to] 사이에 이 인부가 상자에 광석을 내려놓았는지.
  static bool droppedBetween(double from, double to, int floor, int index) {
    if (to <= from) return false;
    final dropAt = walkTime * 2 + mineTime; // 한 바퀴 안에서 내려놓는 시점
    final offset = phaseOffset(floor, index);
    final start = ((from + offset) / duration).floor();
    final end = ((to + offset) / duration).floor();
    for (var cycle = start; cycle <= end; cycle++) {
      final at = cycle * duration + dropAt - offset;
      if (at > from && at <= to) return true;
    }
    return false;
  }

  /// 곡괭이가 암벽을 찍는 순간인지 (돌가루 효과용).
  static bool isHitMoment(double time, int floor, int index) {
    final p = pose(time, floor, index);
    return p.action == MinerAction.mine && p.frame == 10;
  }
}

/// 엘리베이터: 지상과 가장 깊은 층 사이를 오르내린다.
class ElevatorMotion {
  ElevatorMotion._();

  static const double speed = 30; // 도트/초
  static const double wait = 1.2;
  static const double cageHeight = 18;

  static double topY() => MineLayout.groundY - cageHeight;

  static double bottomY(int floors) =>
      MineLayout.floorTop(max(floors, 1) - 1) +
      MineLayout.floorLine -
      cageHeight;

  /// (위쪽 y, 광석을 실었는지)
  static (double, bool) at(double time, int floors) {
    final top = topY();
    final bottom = bottomY(floors);
    final travel = (bottom - top) / speed;
    final period = travel * 2 + wait * 2;
    var t = time % period;
    if (t < wait) return (top, false); // 지상에서 내림
    t -= wait;
    if (t < travel) return (top + t * speed, false); // 내려감
    t -= travel;
    if (t < wait) return (bottom, true); // 바닥에서 실음
    t -= wait;
    return (bottom - t * speed, true); // 올라감
  }
}

/// 지상의 광차: 엘리베이터 탑에서 창고까지 금을 나른다.
class CartMotion {
  CartMotion._();

  static const double startX = 74;
  static const double endX = 36;
  static const double travel = 3.5;
  static const double wait = 1.0;
  static const double period = travel * 2 + wait * 2;

  /// (x, 실었는지, 움직이는 중인지)
  static (double, bool, bool) at(double time) {
    var t = time % period;
    if (t < wait) return (startX, true, false); // 엘리베이터 앞에서 싣기
    t -= wait;
    if (t < travel) {
      return (startX + (endX - startX) * t / travel, true, true);
    }
    t -= travel;
    if (t < wait) return (endX, false, false); // 창고에 내림
    t -= wait;
    return (endX + (startX - endX) * t / travel, false, true);
  }
}
