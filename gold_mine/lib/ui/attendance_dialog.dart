import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../game/game_config.dart';
import '../game/game_controller.dart';
import 'number_format.dart';

/// 7일 출석 보상판. 7일째에는 사이보그 인부가 온다.
class AttendanceDialog extends StatelessWidget {
  const AttendanceDialog({super.key, required this.game, this.sound});

  final GameController game;
  final SoundService? sound;

  static Future<void> show(
    BuildContext context,
    GameController game, {
    SoundService? sound,
  }) => showDialog<void>(
    context: context,
    builder: (_) => AttendanceDialog(game: game, sound: sound),
  );

  /// 이번 주기에서 이미 받은 칸 수 (0~7).
  int get _done {
    final slot = game.attendanceSlot;
    if (!game.canCheckIn && slot == 0 && game.attendanceCount > 0) {
      return GameConfig.attendanceRewards.length;
    }
    return slot;
  }

  String _amount(AttendanceReward r) {
    if (r.isCyborg) return '1명';
    if (r.itemId != null) return '×${r.count}';
    return formatGold(game.rewardGold(r));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final rewards = GameConfig.attendanceRewards;
        final done = _done;
        return AlertDialog(
          title: const Text('🎁 출석 보상'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '매일 들르면 보상을 드려요.\n'
                  '7일째에는 지치지 않는 🤖 사이보그 인부 (생산량 '
                  '${GameConfig.cyborgMultiplier}배)!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < rewards.length; i++)
                      _DayCell(
                        day: i + 1,
                        emoji: rewards[i].emoji,
                        amount: _amount(rewards[i]),
                        claimed: i < done,
                        today: game.canCheckIn && i == game.attendanceSlot,
                        big: rewards[i].isCyborg,
                      ),
                  ],
                ),
                if (game.cyborgs > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '현재 사이보그 인부 ${game.cyborgs}명',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF80DEEA),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (game.canCheckIn)
              FilledButton(
                onPressed: () => _claim(context),
                child: Text('${game.attendanceSlot + 1}일째 보상 받기'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('내일 또 올게요'),
              ),
          ],
        );
      },
    );
  }

  void _claim(BuildContext context) {
    final r = game.todaysReward;
    final gold = game.rewardGold(r);
    if (game.checkIn() == null) return;
    sound?.play(r.isCyborg ? Sfx.fanfare : Sfx.coin);
    final text = r.isCyborg
        ? '🤖 사이보그 인부가 광산에 합류했어요! 일반 인부의 '
              '${GameConfig.cyborgMultiplier}배로 캐요.'
        : r.itemId != null
        ? '${r.emoji} ${r.name} ${r.count}개를 받았어요! (매점 가방에 쏙)'
        : '💰 ${formatGold(gold)} 골드를 받았어요!';
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.emoji,
    required this.amount,
    required this.claimed,
    required this.today,
    required this.big,
  });

  final int day;
  final String emoji;
  final String amount;
  final bool claimed;
  final bool today;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final border = today
        ? const Color(0xFFFFC83D)
        : big
        ? const Color(0xFF80DEEA)
        : const Color(0xFF6B4423);
    return Opacity(
      opacity: claimed ? 0.45 : 1,
      child: Container(
        width: big ? 132 : 62,
        height: 74,
        decoration: BoxDecoration(
          color: big ? const Color(0xFF203A44) : const Color(0xFF3A2C20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: today ? 3 : 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day일', style: const TextStyle(fontSize: 11)),
                Text(emoji, style: TextStyle(fontSize: big ? 26 : 20)),
                FittedBox(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (claimed)
              const Icon(Icons.check_circle, color: Color(0xFF66BB6A)),
          ],
        ),
      ),
    );
  }
}
