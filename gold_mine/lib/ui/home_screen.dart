import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../scene/mine_scene.dart';
import '../scene/sprites.dart';
import 'number_format.dart';
import 'widgets/boost_bar.dart';
import 'widgets/gold_header.dart';
import 'widgets/upgrade_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.ads,
    this.sprites,
  });

  final GameController controller;
  final AdService ads;
  final Sprites? sprites;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// 이보다 짧게 자리를 비웠으면 (광고 시청 등) 환영 팝업을 띄우지 않는다.
  static const _minAwayForDialog = Duration(minutes: 1);

  GameController get _game => widget.controller;
  AdService get _ads => widget.ads;

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
    final minEarned =
        _game.baseGoldPerSecond *
        _minAwayForDialog.inSeconds *
        GameConfig.offlineEfficiency;
    if (earned > 0 && earned >= minEarned) {
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
          ValueListenableBuilder<bool>(
            valueListenable: _ads.rewardedReady,
            builder: (context, ready, _) => TextButton.icon(
              onPressed: ready
                  ? () {
                      Navigator.of(context).pop();
                      _watchAdForBonus(earned);
                    }
                  : null,
              icon: const Icon(Icons.ondemand_video),
              label: const Text('광고 보고 2배'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('받기'),
          ),
        ],
      ),
    );
  }

  /// 오프라인 보상은 이미 받은 상태이므로 같은 양을 한 번 더 준다.
  Future<void> _watchAdForBonus(double earned) async {
    if (!await _ads.showRewarded()) return;
    _game.grantBonusGold(earned);
    _showMessage('보너스 ${formatGold(earned)} 골드를 받았어요!');
  }

  Future<void> _watchAdForBoost() async {
    if (!await _ads.showRewarded()) return;
    if (_game.activateBoost()) {
      _showMessage(
        '${GameConfig.boostDuration.inMinutes}분간 채굴 속도가 '
        '${GameConfig.boostMultiplier.toStringAsFixed(0)}배가 됩니다!',
      );
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _game,
                builder: (context, _) => _buildGame(),
              ),
            ),
            // 배너는 0.1초마다 다시 그릴 필요가 없어서 밖에 둔다.
            _ads.buildBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        GoldHeader(gold: _game.gold, goldPerSecond: _game.goldPerSecond),
        ValueListenableBuilder<bool>(
          valueListenable: _ads.rewardedReady,
          builder: (context, ready, _) => BoostBar(
            remaining: _game.boostRemaining,
            canActivate: _game.canActivateBoost,
            adReady: ready,
            onPressed: _watchAdForBoost,
          ),
        ),
        Expanded(
          child: ClipRect(
            child: MineScene(game: _game, sprites: widget.sprites),
          ),
        ),
        _buildUpgrades(),
      ],
    );
  }

  Widget _buildUpgrades() {
    final nextMultiplier =
        GameConfig.mineMultiplier(_game.mineLevel + 1) /
        GameConfig.mineMultiplier(_game.mineLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
