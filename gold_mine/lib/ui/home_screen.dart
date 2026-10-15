import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../game/mine_event.dart';
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
    _game.onEventNotice = _onEventNotice;
    _resumeGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.onEventNotice = null;
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
        _game.steadyGoldPerSecond *
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

  // ── 작업 반장의 결정 ────────────────────────────────
  void _onEventNotice(MineEvent event, String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final stillOpen = _game.eventById(event.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: stillOpen != null && stillOpen.type.needsForeman
            ? SnackBarAction(
                label: '확인',
                onPressed: () {
                  final e = _game.eventById(event.id);
                  if (e != null) _showEventDialog(e);
                },
              )
            : null,
      ),
    );
  }

  void _showEventDialog(MineEvent event) {
    final floor = 'B${event.floor + 1}';
    switch (event.type) {
      case MineEventType.fatigue:
        _decide(
          title: '💦 지친 인부',
          message:
              '반장님, $floor 인부가 많이 지쳤어요.\n'
              '지금은 절반 속도로 일하고 있어요.\n'
              '${GameConfig.fatigueToInjury.inMinutes}분 넘게 무리하면 다칠 수 있어요.',
          choices: [
            ('계속 일 시키기', false, () {}),
            (
              '휴식 주기 (${GameConfig.restDuration.inSeconds}초)',
              true,
              () {
                if (_game.restWorker(event.id)) {
                  _showMessage(
                    '쉬고 나면 ${GameConfig.energizedDuration.inMinutes}분간 '
                    '${GameConfig.energizedSpeed}배로 일해요!',
                  );
                }
              },
            ),
          ],
        );
      case MineEventType.injury:
        final healIn = event.remaining(DateTime.now()).inMinutes + 1;
        _decide(
          title: '🩹 다친 인부',
          message:
              '반장님, $floor 인부가 다쳐서 일을 못 하고 있어요.\n'
              '그냥 두면 약 $healIn분 뒤에 회복해요.',
          choices: [
            ('기다리기', false, () {}),
            if (_ads.rewardedReady.value)
              (
                '광고 보고 치료',
                false,
                () async {
                  if (await _ads.showRewarded() &&
                      _game.treatInjury(event.id, free: true)) {
                    _showMessage('$floor 인부가 다시 일하러 갔어요!');
                  }
                },
              ),
            (
              '치료하기 (${formatGold(_game.treatCost)} 골드)',
              true,
              _game.canTreat
                  ? () {
                      if (_game.treatInjury(event.id)) {
                        _showMessage('$floor 인부가 다시 일하러 갔어요!');
                      }
                    }
                  : null,
            ),
          ],
        );
      case MineEventType.diamond:
        _decide(
          title: '💎 다이아몬드 발견!',
          message:
              '반장님! $floor 인부가 다이아몬드를 찾았어요!\n'
              '${formatGold(event.reward)} 골드에 팔 수 있어요.',
          choices: [
            if (_ads.rewardedReady.value)
              (
                '광고 보고 2배',
                false,
                () async {
                  if (await _ads.showRewarded()) {
                    final got = _game.collectDiamond(event.id, multiplier: 2);
                    if (got > 0) _showMessage('+${formatGold(got)} 골드!');
                  }
                },
              ),
            (
              '받기',
              true,
              () {
                final got = _game.collectDiamond(event.id);
                if (got > 0) _showMessage('+${formatGold(got)} 골드!');
              },
            ),
          ],
        );
      case MineEventType.rest:
      case MineEventType.energized:
      case MineEventType.goldVein:
        break;
    }
  }

  /// 반장에게 선택지를 보여 준다. (글자, 강조 여부, 누르면 할 일)
  void _decide({
    required String title,
    required String message,
    required List<(String, bool, void Function()?)> choices,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          for (final (label, primary, action) in choices)
            if (primary)
              FilledButton(
                onPressed: action == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        action();
                      },
                child: Text(label),
              )
            else
              TextButton(
                onPressed: action == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        action();
                      },
                child: Text(label),
              ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('처음부터 다시 시작'),
              subtitle: const Text('골드, 인부, 광산이 모두 초기화돼요'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmReset();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('처음부터 다시 시작할까요?'),
        content: const Text('지금까지의 골드, 인부, 광산이 모두 사라지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('다시 시작'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _game.reset();
    await _game.save();
    _showMessage('새 광산에서 다시 시작합니다!');
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: GoldHeader(
                  gold: _game.gold,
                  goldPerSecond: _game.goldPerSecond,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _ads.rewardedReady,
                builder: (context, ready, _) => BoostBar(
                  remaining: _game.boostRemaining,
                  canActivate: _game.canActivateBoost,
                  adReady: ready,
                  onPressed: _watchAdForBoost,
                ),
              ),
              IconButton(
                tooltip: '설정',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: _showSettings,
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: MineScene(
              game: _game,
              sprites: widget.sprites,
              onEventTap: _showEventDialog,
            ),
          ),
        ),
        _buildUpgrades(),
      ],
    );
  }

  static const _equipmentIcons = [
    Icons.hardware, // 곡괭이
    Icons.construction, // 착암 드릴
    Icons.local_fire_department, // 다이너마이트
    Icons.precision_manufacturing, // 굴착 기계
  ];

  String _equipmentDescription() {
    final next = _game.nextEquipment;
    if (next != null) return 'Lv.${_game.pickaxeLevel} · 다음: ${next.name}';
    return 'Lv.${_game.pickaxeLevel} · 터치 +${formatRate(_game.goldPerTap)}';
  }

  /// 장비를 강화하고, 새 장비로 바뀌었으면 크게 알린다.
  void _upgradeEquipment() {
    final before = _game.equipmentTier;
    if (!_game.upgradePickaxe() || _game.equipmentTier == before) return;
    final tier = _game.equipment;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          _equipmentIcons[_game.equipmentTier],
          size: 48,
          color: Colors.amber,
        ),
        title: Text('${tier.name} 도입!'),
        content: Text(
          '반장님, 새 장비가 들어왔어요!\n'
          '이제 인부들이 ${tier.name}(으)로 일해서\n'
          '생산량이 ${tier.multiplier}배가 돼요.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('좋아요!'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgrades() {
    final nextMultiplier =
        GameConfig.mineMultiplier(_game.mineLevel + 1) /
        GameConfig.mineMultiplier(_game.mineLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      color: const Color(0xFF2B2018),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: UpgradeTile(
              icon: Icons.engineering,
              title: '인부 고용',
              description: _game.isWorkerFull
                  ? '광산 확장 필요'
                  : '${_game.workers}/${_game.maxWorkers}명',
              cost: _game.workerCost,
              enabled: _game.canHireWorker,
              maxed: _game.isWorkerFull,
              onPressed: _game.hireWorker,
            ),
          ),
          Expanded(
            child: UpgradeTile(
              icon: Icons.terrain,
              title: '광산 확장',
              description:
                  'B${_game.mineLevel + 1}층 · 생산 ×${nextMultiplier.toStringAsFixed(1)}',
              cost: _game.mineUpgradeCost,
              enabled: _game.canUpgradeMine,
              onPressed: _game.upgradeMine,
            ),
          ),
          Expanded(
            child: UpgradeTile(
              icon: _equipmentIcons[_game.equipmentTier],
              title: _game.equipment.name,
              description: _equipmentDescription(),
              cost: _game.pickaxeUpgradeCost,
              enabled: _game.canUpgradePickaxe,
              buttonLabel: _game.equipmentLockedUntilMine == null
                  ? null
                  : 'B${_game.equipmentLockedUntilMine}층 필요',
              onPressed: _upgradeEquipment,
            ),
          ),
        ],
      ),
    );
  }
}
