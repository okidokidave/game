import 'package:flutter/material.dart';

import '../../game/game_config.dart';

/// 광고를 보고 채굴 속도를 올리는 버튼과 남은 부스트 시간.
class BoostBar extends StatelessWidget {
  const BoostBar({
    super.key,
    required this.remaining,
    required this.canActivate,
    required this.adReady,
    required this.onPressed,
  });

  final Duration remaining;
  final bool canActivate;
  final bool adReady;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = remaining > Duration.zero;
    final multiplier = GameConfig.boostMultiplier.toStringAsFixed(0);
    final minutes = GameConfig.boostDuration.inMinutes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (active) ...[
            const Icon(Icons.bolt, color: Colors.orangeAccent),
            Text(
              '채굴 ×$multiplier  ${_format(remaining)}',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
          ],
          OutlinedButton.icon(
            onPressed: canActivate && adReady ? onPressed : null,
            icon: const Icon(Icons.ondemand_video, size: 18),
            label: Text(
              !canActivate
                  ? '부스트 가득 참'
                  : active
                  ? '+$minutes분 연장'
                  : '광고 보고 $minutes분간 채굴 ×$multiplier',
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
