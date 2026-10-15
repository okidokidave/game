import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../game/game_controller.dart';
import '../game/shop.dart';
import 'number_format.dart';

/// 갱도 밖 매점: 인부의 체력을 채우는 물건을 사고, 모두에게 쓰는 물건은 바로 쓴다.
class ShopSheet extends StatelessWidget {
  const ShopSheet({
    super.key,
    required this.game,
    required this.scroll,
    this.sound,
    this.forSlot,
  });

  final GameController game;
  final ScrollController scroll;
  final SoundService? sound;

  /// 특정 인부를 돌보러 왔으면 그 인부 번호 (한 명용 물건을 바로 먹일 수 있다).
  final int? forSlot;

  static void show(
    BuildContext context,
    GameController game, {
    SoundService? sound,
    int? forSlot,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ShopSheet(
          game: game,
          scroll: scroll,
          sound: sound,
          forSlot: forSlot,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            '🏪 광산 매점',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            forSlot == null
                ? '인부들의 체력을 채워 줄 먹거리를 팔아요.\n'
                      '한 명용 물건은 인부를 눌러서 먹일 수 있어요.'
                : '${GameController.workerLabel(forSlot!)} 인부 체력 '
                      '${game.staminaOf(forSlot!).round()} / 100',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          if (game.isStaminaBuffActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '💊 비타민 효과 중 · ${game.staminaBuffRemaining.inMinutes + 1}분 남음',
                style: const TextStyle(
                  color: Color(0xFF81C784),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final item in Shop.items)
            // 부품은 사이보그 인부가 생긴 뒤에만 판다.
            if (item.target != ShopTarget.cyborgPart || game.hasCyborg)
              _itemTile(context, item),
        ],
      ),
    );
  }

  Widget _itemTile(BuildContext context, ShopItem item) {
    final owned = game.itemCount(item);
    final cost = game.itemCost(item);
    final canUseHere =
        owned > 0 &&
        item.target != ShopTarget.cyborgPart &&
        (item.target != ShopTarget.worker || forSlot != null);
    return Card(
      color: const Color(0xFF3A2C20),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.name}  ×$owned',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: game.canBuy(item)
                        ? () {
                            if (game.buyItem(item)) sound?.play(Sfx.buy);
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('사기 ${formatGold(cost)}'),
                  ),
                  if (canUseHere)
                    OutlinedButton(
                      onPressed: () => _use(context, item),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        item.target == ShopTarget.worker ? '먹이기' : '사용',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _use(BuildContext context, ShopItem item) {
    final ok = item.target == ShopTarget.worker
        ? game.feedWorker(item, forSlot!)
        : game.useItem(item);
    if (!ok) return;
    sound?.play(Sfx.sparkle);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (item.target) {
          ShopTarget.worker =>
            '${item.emoji} ${GameController.workerLabel(forSlot!)} 인부가 기운을 차렸어요!',
          ShopTarget.everyone => '${item.emoji} 모든 인부가 기운을 차렸어요!',
          ShopTarget.buff =>
            '${item.emoji} ${item.buffMinutes}분 동안 아무도 지치지 않아요!',
          ShopTarget.cyborgPart => '',
        }),
      ),
    );
  }
}
