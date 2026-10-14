import 'package:flutter_test/flutter_test.dart';
import 'package:gold_mine/game/game_config.dart';
import 'package:gold_mine/scene/mine_layout.dart';

void main() {
  group('층 배치', () {
    test('층마다 인부를 최대 3명씩 채운다', () {
      expect(MineLayout.workersPerFloor, GameConfig.workersPerMineLevel);
      final perFloor = [
        for (var f = 0; f < 3; f++) MineLayout.workersOnFloor(f, 7),
      ];
      expect(perFloor, [3, 3, 1]);
      expect(MineLayout.workersOnFloor(3, 7), 0);
    });

    test('깊은 층일수록 다른 암석 테마를 쓰고, 마지막 테마에서 멈춘다', () {
      expect(
        [for (var f = 0; f < 7; f++) MineLayout.theme(f)],
        [0, 1, 2, 3, 4, 4, 4],
      );
    });
  });

  group('인부 움직임', () {
    test('한 바퀴 동안 걷기 → 곡괭이질 → 운반 → 내려놓기 순서로 움직인다', () {
      final actions = <MinerAction>[];
      for (var t = 0.0; t < MinerCycle.duration; t += 0.05) {
        final a = MinerCycle.pose(
          t - MinerCycle.phaseOffset(0, 0),
          0,
          0,
        ).action;
        if (actions.isEmpty || actions.last != a) actions.add(a);
      }
      expect(actions, [
        MinerAction.walkToRock,
        MinerAction.mine,
        MinerAction.carry,
        MinerAction.drop,
      ]);
    });

    test('암벽으로 갈 때는 왼쪽, 돌아올 때는 오른쪽을 본다', () {
      for (var t = 0.0; t < MinerCycle.duration * 2; t += 0.1) {
        final p = MinerCycle.pose(t, 1, 2);
        if (p.action == MinerAction.walkToRock) expect(p.facingLeft, isTrue);
        if (p.action == MinerAction.carry) expect(p.facingLeft, isFalse);
      }
    });

    test('인부는 굴 안에서만 움직인다', () {
      for (var t = 0.0; t < MinerCycle.duration * 3; t += 0.03) {
        for (var i = 0; i < 3; i++) {
          final p = MinerCycle.pose(t, 2, i);
          expect(p.x, greaterThanOrEqualTo(0));
          expect(
            p.x + MineLayout.minerWidth,
            lessThanOrEqualTo(MineLayout.tunnelRight),
          );
          expect(p.frame, inInclusiveRange(0, 11));
        }
      }
    });

    test('한 바퀴에 정확히 한 번 광석을 내려놓는다', () {
      var drops = 0;
      const step = 1 / 60;
      for (var t = 0.0; t < MinerCycle.duration * 10; t += step) {
        if (MinerCycle.droppedBetween(t, t + step, 0, 1)) drops++;
      }
      expect(drops, 10);
    });
  });

  group('엘리베이터와 광차', () {
    test('엘리베이터는 지상과 가장 깊은 층 사이에서만 움직인다', () {
      const floors = 4;
      for (var t = 0.0; t < 60; t += 0.1) {
        final (y, _) = ElevatorMotion.at(t, floors);
        expect(y, greaterThanOrEqualTo(ElevatorMotion.topY() - 1e-9));
        expect(y, lessThanOrEqualTo(ElevatorMotion.bottomY(floors) + 1e-9));
      }
    });

    test('광차는 실은 채로 창고로 가고 빈 채로 돌아온다', () {
      final (_, loadedAtStart, _) = CartMotion.at(0);
      final (x, loadedAtWarehouse, _) = CartMotion.at(
        CartMotion.wait + CartMotion.travel + 0.1,
      );
      expect(loadedAtStart, isTrue);
      expect(loadedAtWarehouse, isFalse);
      expect(x, CartMotion.endX);
    });
  });
}
