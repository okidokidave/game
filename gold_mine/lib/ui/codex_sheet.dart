import 'package:flutter/material.dart';

import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../game/regions.dart';

/// 도감: 지역별 희귀 광석 모음과 세트 보너스.
class CodexSheet extends StatefulWidget {
  const CodexSheet({super.key, required this.game, required this.scroll});

  final GameController game;
  final ScrollController scroll;

  static void show(BuildContext context, GameController game) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => CodexSheet(game: game, scroll: scroll),
      ),
    );
  }

  @override
  State<CodexSheet> createState() => _CodexSheetState();
}

class _CodexSheetState extends State<CodexSheet> {
  /// 이번에 처음 보는 광석 (NEW 표시용). 열자마자 "확인함"으로 바꾼다.
  late final Set<String> _newOres;

  GameController get _game => widget.game;

  @override
  void initState() {
    super.initState();
    _newOres = {
      for (final ore in Regions.allOres)
        if (_game.isUnseen(ore)) ore.id,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _game.markCodexSeen());
  }

  @override
  Widget build(BuildContext context) {
    final found = Regions.allOres.where(_game.isDiscovered).length;
    final total = Regions.allOres.length;
    final bonus = (_game.codexMultiplier - 1) * 100;
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '📖 광물 도감  $found / $total',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '각 광산의 막장까지 내려가면 희귀 광석이 나와요.\n'
          '한 지역을 모두 모으면 생산량이 영구히 '
          '+${(GameConfig.regionSetBonus * 100).round()}%! '
          '(지금 보너스 +${bonus.round()}%)',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        for (var r = 0; r < Regions.all.length; r++) _region(r),
      ],
    );
  }

  Widget _region(int index) {
    final region = Regions.all[index];
    final reached = index <= _game.regionIndex;
    final found = region.ores.where(_game.isDiscovered).length;
    final complete = _game.isRegionComplete(region);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reached ? region.name : '??? (미개척 지역)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                complete ? '✅ 완성!' : '$found / ${region.ores.length}',
                style: TextStyle(
                  color: complete ? const Color(0xFF81C784) : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (reached) ...[
            const SizedBox(height: 2),
            Text(
              '막장 B${region.bottomFloor} · ${region.traits.join(' · ')}',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              for (final ore in region.ores)
                Expanded(child: _oreCard(ore, reached)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _oreCard(Ore ore, bool regionReached) {
    final found = _game.isDiscovered(ore);
    final rarityColor = Color(ore.rarity.color);
    return Card(
      color: const Color(0xFF3A2C20),
      margin: const EdgeInsets.all(3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: found ? rarityColor : Colors.white12,
          width: found ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: found ? () => _showOre(ore) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    found ? Icons.diamond : Icons.help_outline,
                    size: 34,
                    color: found ? Color(ore.color) : Colors.white24,
                  ),
                  if (_newOres.contains(ore.id))
                    const Positioned(
                      right: -14,
                      top: -6,
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5252),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                found ? ore.name : '???',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                found
                    ? '${ore.rarity.label} · ${_game.oreCount(ore)}개'
                    : ore.rarity.label,
                style: TextStyle(
                  fontSize: 11,
                  color: found ? rarityColor : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOre(Ore ore) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.diamond, size: 48, color: Color(ore.color)),
        title: Text(ore.name),
        content: Text(
          '${ore.rarity.label} 등급 · '
          '${Regions.all[Regions.regionOf(ore)].name}\n\n'
          '${ore.description}\n\n'
          '보관 중: ${_game.oreCount(ore)}개',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
