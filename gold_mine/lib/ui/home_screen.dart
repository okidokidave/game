import 'package:flutter/material.dart';

import '../game/game_config.dart';
import '../game/game_controller.dart';
import 'number_format.dart';
import 'widgets/gold_header.dart';
import 'widgets/mine_view.dart';
import 'widgets/upgrade_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  GameController get _game => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumeGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.stop();
    super.dispose();
  }

  /// 앱이 백그라운드로 가면 저장하고 멈추고, 돌아오면 오프라인 보상을 준다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeGame();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _game.stop();
        _game.save();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _resumeGame() {
    // 알림창을 내렸다 올린 경우처럼 멈춘 적이 없으면 오프라인 보상도 없다.
    if (_game.isRunning) return;
    final earned = _game.collectOfflineEarnings(DateTime.now());
    _game.start();
    // 1초 미만의 짧은 전환에는 팝업을 띄우지 않는다.
    if (earned >= _game.goldPerSecond * GameConfig.offlineEfficiency) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOfflineDialog(earned);
      });
    }
  }

  void _showOfflineDialog(double earned) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('돌아오셨군요!'),
        content: Text(
          '자리를 비운 동안 인부들이\n${formatGold(earned)} 골드를 캐 두었어요.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('받기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _game,
          builder: (context, _) => Column(
            children: [
              GoldHeader(gold: _game.gold, goldPerSecond: _game.goldPerSecond),
              Expanded(
                child: MineView(
                  mineName: _game.mineName,
                  mineLevel: _game.mineLevel,
                  workers: _game.workers,
                  maxWorkers: _game.maxWorkers,
                  onTap: _game.tap,
                ),
              ),
              _buildUpgrades(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgrades() {
    final nextMultiplier =
        GameConfig.mineMultiplier(_game.mineLevel + 1) /
        GameConfig.mineMultiplier(_game.mineLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2B2018),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UpgradeTile(
            icon: Icons.engineering,
            title: '인부 고용',
            description: _game.isWorkerFull
                ? '광산이 가득 찼어요. 광산을 확장하세요!'
                : '인부 ${_game.workers}/${_game.maxWorkers}명 · 초당 생산 증가',
            cost: _game.workerCost,
            enabled: _game.canHireWorker,
            maxed: _game.isWorkerFull,
            onPressed: _game.hireWorker,
          ),
          UpgradeTile(
            icon: Icons.terrain,
            title: '광산 확장',
            description:
                'Lv.${_game.mineLevel} → ${_game.mineLevel + 1} · 생산 ×${nextMultiplier.toStringAsFixed(1)}, '
                '인부 +${GameConfig.workersPerMineLevel}칸',
            cost: _game.mineUpgradeCost,
            enabled: _game.canUpgradeMine,
            onPressed: _game.upgradeMine,
          ),
          UpgradeTile(
            icon: Icons.hardware,
            title: '곡괭이 강화',
            description:
                'Lv.${_game.pickaxeLevel} · 터치당 ${formatRate(_game.goldPerTap)} 골드',
            cost: _game.pickaxeUpgradeCost,
            enabled: _game.canUpgradePickaxe,
            onPressed: _game.upgradePickaxe,
          ),
        ],
      ),
    );
  }
}
