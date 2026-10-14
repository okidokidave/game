import 'dart:math';

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

  static const int workersPerFloor = 3;

  static double floorTop(int floor) => surfaceHeight + floor * floorHeight;

  static double sceneHeight(int floors) =>
      surfaceHeight + floors * floorHeight + lockedHeight;

  /// 층 번호에 맞는 암석 테마 (0 흙, 1 돌, 2 깊은 돌, 3 수정, 4 용암).
  static int theme(int floor) => min(floor, 4);

  /// [floor]층에서 일하는 인부 수.
  static int workersOnFloor(int floor, int totalWorkers) =>
      (totalWorkers - floor * workersPerFloor).clamp(0, workersPerFloor);
}

enum MinerAction { walkToRock, mine, carry, drop }

/// 인부 한 명의 순간 모습.
class MinerPose {
  const MinerPose(this.action, this.x, this.frame, this.facingLeft);

  final MinerAction action;
  final double x;
  final int frame;
  final bool facingLeft;
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

  static MinerPose pose(double time, int floor, int index) {
    var t = (time + phaseOffset(floor, index)) % duration;
    final dx = xOffset(index);

    if (t < walkTime) {
      final x = MineLayout.dropX - t * walkSpeed;
      return MinerPose(MinerAction.walkToRock, x + dx, _walkFrame(t), true);
    }
    t -= walkTime;
    if (t < mineTime) {
      // 들어 올림 → 휘두름 → 찍기
      final swing = (t % swingTime) / swingTime;
      final frame = swing < 0.45 ? 8 : (swing < 0.6 ? 9 : 10);
      return MinerPose(MinerAction.mine, MineLayout.mineX + dx, frame, true);
    }
    t -= mineTime;
    if (t < walkTime) {
      final x = MineLayout.mineX + t * walkSpeed;
      return MinerPose(MinerAction.carry, x + dx, 4 + _walkFrame(t), false);
    }
    return MinerPose(MinerAction.drop, MineLayout.dropX + dx, 11, false);
  }

  static int _walkFrame(double t) => (t * 8).floor() % 4;

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
