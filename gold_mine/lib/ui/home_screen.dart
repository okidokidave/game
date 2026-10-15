import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../audio/sound_service.dart';
import '../game/game_config.dart';
import '../game/game_controller.dart';
import '../game/mine_event.dart';
import '../game/shop.dart';
import '../scene/mine_scene.dart';
import '../scene/sprites.dart';
import 'attendance_dialog.dart';
import 'codex_sheet.dart';
import 'shop_sheet.dart';
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
    this.sound,
    this.dailyPopup = true,
  });

  final GameController controller;
  final AdService ads;
  final Sprites? sprites;

  /// 효과음·배경음악. 없으면 (테스트 등) 조용히 진행한다.
  final SoundService? sound;

  /// 오늘 출석 보상을 아직 안 받았으면 자동으로 보상판을 띄울지.
  final bool dailyPopup;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final SoundService _sound = widget.sound ?? SilentSoundService();

  /// 이보다 짧게 자리를 비웠으면 (광고 시청 등) 환영 팝업을 띄우지 않는다.
  static const _minAwayForDialog = Duration(minutes: 1);

  GameController get _game => widget.controller;
  AdService get _ads => widget.ads;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.onEventNotice = _onEventNotice;
    _game.onMessage = _onMessage;
    _game.onCue = _onCue;
    // 오프라인 팝업보다 먼저 띄워서 그 아래에 깔리게 한다 (닫으면 보인다).
    _maybeShowAttendance();
    _resumeGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.onEventNotice = null;
    _game.onMessage = null;
    _game.onCue = null;
    _game.stop();
    super.dispose();
  }

  /// 앱이 백그라운드로 가면 저장하고 멈추고, 돌아오면 오프라인 보상을 준다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _sound.resumeMusic();
        _maybeShowAttendance();
        _resumeGame();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _sound.pauseMusic();
        _game.stop();
        _game.save();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  bool _attendanceOpen = false;

  void _maybeShowAttendance() {
    if (!widget.dailyPopup || !_game.canCheckIn || _attendanceOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAttendance());
  }

  Future<void> _openAttendance() async {
    if (!mounted || _attendanceOpen) return;
    _attendanceOpen = true;
    await AttendanceDialog.show(context, _game, sound: _sound);
    _attendanceOpen = false;
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
    _sound.play(Sfx.coin);
    _showMessage('보너스 ${formatGold(earned)} 골드를 받았어요!');
  }

  Future<void> _watchAdForBoost() async {
    if (!await _ads.showRewarded()) return;
    if (_game.activateBoost()) {
      _sound.play(Sfx.sparkle);
      _showMessage(
        '${GameConfig.boostDuration.inMinutes}분간 채굴 속도가 '
        '${GameConfig.boostMultiplier.toStringAsFixed(0)}배가 됩니다!',
      );
    }
  }

  // ── 현장 소장의 결정 ────────────────────────────────
  void _onEventNotice(MineEvent event, String message) {
    if (!mounted) return;
    final current = _game.eventById(event.id);
    _sound.play(switch (current?.type) {
      MineEventType.fatigue || MineEventType.injury => Sfx.alert,
      MineEventType.diamond || MineEventType.goldVein => Sfx.sparkle,
      _ => Sfx.click,
    });
    if (current?.type == MineEventType.injury) _sound.vibrate(Buzz.medium);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final stillOpen = _game.eventById(event.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: stillOpen != null && stillOpen.type.needsManager
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
        _showWorkerCare(GameController.slotOf(event.floor, event.worker));
      case MineEventType.injury:
        final healIn = event.remaining(DateTime.now()).inMinutes + 1;
        _decide(
          title: '🩹 다친 인부',
          message:
              '소장님, $floor 인부가 다쳐서 일을 못 하고 있어요.\n'
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
              '소장님! $floor 인부가 다이아몬드를 찾았어요!\n'
              '${formatGold(event.reward)} 골드에 팔 수 있어요.',
          choices: [
            if (_ads.rewardedReady.value)
              (
                '광고 보고 2배',
                false,
                () async {
                  if (await _ads.showRewarded()) {
                    final got = _game.collectDiamond(event.id, multiplier: 2);
                    if (got > 0) {
                      _sound.play(Sfx.coin);
                      _showMessage('+${formatGold(got)} 골드!');
                    }
                  }
                },
              ),
            (
              '받기',
              true,
              () {
                final got = _game.collectDiamond(event.id);
                if (got > 0) {
                  _sound.play(Sfx.coin);
                  _showMessage('+${formatGold(got)} 골드!');
                }
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

  /// 소장에게 선택지를 보여 준다. (글자, 강조 여부, 누르면 할 일)
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

  // ── 인부 관리 ───────────────────────────────────────
  /// 등급별 안전모 색 (도트 그림과 같은 색).
  static const _gradeColors = [
    Color(0xFFCDCDC3),
    Color(0xFFF7C331),
    Color(0xFFF07832),
    Color(0xFFAA69EB),
  ];

  void _onCue(GameCue cue) {
    switch (cue) {
      case GameCue.newOre:
      case GameCue.setComplete:
        _sound.play(Sfx.rare);
        _sound.vibrate(Buzz.medium);
      case GameCue.oreFound:
        _sound.play(Sfx.sparkle);
      case GameCue.promotionReady:
        _sound.play(Sfx.click);
      case GameCue.workerTired:
        _sound.play(Sfx.alert);
      case GameCue.workerCollapsed:
        _sound.play(Sfx.alert);
        _sound.vibrate(Buzz.heavy);
    }
  }

  // ── 체력 돌보기 ─────────────────────────────────────
  void _openShop({int? forSlot}) =>
      ShopSheet.show(context, _game, sound: _sound, forSlot: forSlot);

  /// 지치거나 쓰러진 인부를 눌렀을 때: 가진 먹거리 먹이기, 쉬게 하기, 매점 가기.
  void _showWorkerCare(int slot) {
    final label = GameController.workerLabel(slot);
    final collapsed = _game.isCollapsed(slot);
    final stamina = _game.staminaOf(slot).round();
    final foods = [
      for (final item in Shop.items)
        if (item.target == ShopTarget.worker && _game.itemCount(item) > 0) item,
    ];
    _decide(
      title: collapsed ? '😵 $label 인부가 쓰러졌어요' : '💦 $label 인부',
      message: collapsed
          ? '체력이 바닥나 쓰러졌어요 (체력 $stamina).\n'
                '먹을 것을 주면 바로 일어나요.\n'
                '그냥 두면 15분쯤 뒤에 겨우 일어나요.'
          : '체력 $stamina / 100\n'
                '${stamina < GameConfig.tiredStamina ? '지쳐서 절반 속도로 일하고 있어요.' : '아직 일할 만해요.'}',
      choices: [
        for (final item in foods)
          (
            '${item.emoji} ${item.name} 먹이기 (${_game.itemCount(item)}개)',
            true,
            () {
              if (_game.feedWorker(item, slot)) {
                _sound.play(Sfx.sparkle);
                _showMessage('${item.emoji} $label 인부가 기운을 차렸어요!');
              }
            },
          ),
        if (!collapsed)
          (
            '쉬게 하기 (${GameConfig.restDuration.inSeconds}초)',
            false,
            () {
              if (_game.restWorker(slot)) {
                _showMessage(
                  '쉬고 나면 체력 +${GameConfig.restStamina.round()}, '
                  '${GameConfig.energizedDuration.inMinutes}분간 '
                  '${GameConfig.energizedSpeed}배로 일해요!',
                );
              }
            },
          ),
        ('🏪 매점 가기', foods.isEmpty, () => _openShop(forSlot: slot)),
      ],
    );
  }

  void _onMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: '보기', onPressed: _showWorkers),
      ),
    );
  }

  void _showWorkers() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) => ListenableBuilder(
          listenable: _game,
          builder: (context, _) => ListView(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const ListTile(
                title: Text(
                  '👷 인부 관리',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '일한 만큼 경험치가 쌓여요. 가득 차면 승급시키세요.\n'
                  '반장은 층마다 한 명! 같은 층 인부들의 경험치가 1.5배로 쌓여요.',
                ),
              ),
              if (_game.cyborgs > 0) _cyborgTile(),
              for (var slot = 0; slot < _game.workers; slot++)
                _workerTile(slot),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cyborgTile() {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF80DEEA),
        foregroundColor: Colors.black87,
        child: Text('🤖'),
      ),
      title: Text('사이보그 인부 ${_game.cyborgs}명'),
      subtitle: Text(
        '한 명이 일반 인부 ${GameConfig.cyborgMultiplier}명 몫 · 지치지 않아요\n'
        '초당 ${formatGold(_game.cyborgGoldPerSecond)} 골드 · 이사 가도 따라와요',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _workerTile(int slot) {
    final grade = _game.gradeOf(slot);
    final need = _game.xpNeeded(slot);
    final xp = _game.xpOf(slot);
    final ready = _game.isPromotionReady(slot);
    final stamina = _game.staminaOf(slot);
    final collapsed = _game.isCollapsed(slot);
    final staminaColor = collapsed || stamina < GameConfig.tiredStamina
        ? const Color(0xFFE5533D)
        : stamina < 60
        ? Colors.orange
        : const Color(0xFF66BB6A);
    return ListTile(
      onTap: () => _showWorkerCare(slot),
      leading: CircleAvatar(
        backgroundColor: _gradeColors[_game.gradeIndexOf(slot)],
        foregroundColor: Colors.black87,
        child: const Icon(Icons.engineering),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${GameController.workerLabel(slot)}  ${grade.name}  ×${grade.multiplier}',
            ),
          ),
          Text(
            collapsed ? '😵 쓰러짐' : '체력 ${stamina.round()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: staminaColor,
            ),
          ),
        ],
      ),
      subtitle: need == null
          ? const Text('최고 등급이에요!')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: xp / need,
                  color: ready ? const Color(0xFF4CAF50) : Colors.amber,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _game.isBlockedByForeman(slot) && xp >= need
                            ? 'B${slot ~/ GameConfig.workersPerMineLevel + 1}층 '
                                  '반장 자리가 차 있어요'
                            : ready
                            ? '승급 준비 완료!'
                            : '경험치 ${(xp / 60).floor()}/${(need / 60).round()}분',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (ready)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _game.canPromote(slot)
                            ? () => _promote(slot)
                            : null,
                        child: Text(
                          '승급 ${formatGold(_game.promotionCost(slot))}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  void _showPromotionDialog(int slot) {
    final grade = _game.gradeOf(slot);
    final next = GameConfig.workerGrades[_game.gradeIndexOf(slot) + 1];
    final cost = _game.promotionCost(slot);
    _decide(
      title: '⬆ 승급',
      message:
          '소장님, ${GameController.workerLabel(slot)} ${grade.name} 인부가 '
          '승급할 준비가 됐어요!\n\n'
          '${grade.name} → ${next.name}\n'
          '생산 ×${grade.multiplier} → ×${next.multiplier}',
      choices: [
        ('나중에', false, () {}),
        (
          '승급시키기 (${formatGold(cost)} 골드)',
          true,
          _game.canPromote(slot) ? () => _promote(slot) : null,
        ),
      ],
    );
  }

  void _promote(int slot) {
    if (!_game.promote(slot)) return;
    _sound.play(Sfx.fanfare);
    _showMessage(
      '${GameController.workerLabel(slot)} 인부가 '
      '${_game.gradeOf(slot).name}(으)로 승급했어요! 🎉',
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _sound,
              builder: (context, _) => Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('효과음 · 진동'),
                    value: _sound.sfxOn,
                    onChanged: (on) {
                      _sound.setSfxOn(on);
                      if (on) _sound.play(Sfx.click);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.music_note),
                    title: const Text('배경음악'),
                    value: _sound.musicOn,
                    onChanged: _sound.setMusicOn,
                  ),
                ],
              ),
            ),
            const Divider(),
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
              IconButton(
                tooltip: '도감',
                visualDensity: VisualDensity.compact,
                icon: Badge(
                  isLabelVisible: _game.unseenOreCount > 0,
                  label: const Text('N'),
                  child: const Icon(Icons.menu_book, color: Colors.white70),
                ),
                onPressed: () => CodexSheet.show(context, _game),
              ),
              IconButton(
                tooltip: '출석 보상',
                visualDensity: VisualDensity.compact,
                icon: Badge(
                  isLabelVisible: _game.canCheckIn,
                  label: const Text('!'),
                  child: const Icon(Icons.card_giftcard, color: Colors.white70),
                ),
                onPressed: _openAttendance,
              ),
              IconButton(
                tooltip: '매점',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.storefront, color: Colors.white70),
                onPressed: _openShop,
              ),
              IconButton(
                tooltip: '인부 관리',
                visualDensity: VisualDensity.compact,
                icon: Badge(
                  isLabelVisible:
                      _game.promotionReadyCount + _game.exhaustedCount > 0,
                  backgroundColor: _game.exhaustedCount > 0
                      ? const Color(0xFFE5533D)
                      : const Color(0xFF4CAF50),
                  label: Text(
                    '${_game.promotionReadyCount + _game.exhaustedCount}',
                  ),
                  child: const Icon(Icons.groups, color: Colors.white70),
                ),
                onPressed: _showWorkers,
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
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: MineScene(
                    game: _game,
                    sprites: widget.sprites,
                    sound: _sound,
                    onEventTap: _showEventDialog,
                    onWorkerTap: _showPromotionDialog,
                    onShowWorkers: _showWorkers,
                    onWorkerCare: _showWorkerCare,
                    onOpenShop: _openShop,
                  ),
                ),
              ),
              // 광고 부스트 버튼은 광산 하늘 오른쪽 위에 띄운다 (머리 공간 절약).
              Positioned(
                top: 6,
                right: 6,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _ads.rewardedReady,
                  builder: (context, ready, _) => BoostBar(
                    remaining: _game.boostRemaining,
                    canActivate: _game.canActivateBoost,
                    adReady: ready,
                    onPressed: _watchAdForBoost,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildUpgrades(),
      ],
    );
  }

  // ── 지역 개척 ───────────────────────────────────────
  /// 막장에 닿으면 광산 확장 칸이 "지역 개척"으로 바뀐다.
  Widget _pioneerTile() {
    final next = _game.nextRegion;
    return UpgradeTile(
      icon: Icons.explore,
      title: next == null ? '막장' : '지역 개척',
      description: next == null ? '마지막 지역이에요' : '→ ${next.name}',
      cost: _game.pioneerCost,
      enabled: _game.canPioneer,
      maxed: next == null,
      onPressed: _confirmPioneer,
    );
  }

  void _confirmPioneer() {
    final next = _game.nextRegion;
    if (next == null) return;
    final caretaker =
        (_game.steadyGoldPerSecond - _game.caretakerIncome) *
        GameConfig.caretakerShare;
    _decide(
      title: '🗺 ${next.name} 개척',
      message:
          '${next.summary}\n\n'
          '${next.traits.map((t) => '• $t').join('\n')}\n'
          '• 막장: B${next.bottomFloor}\n\n'
          '새 지역은 B1에서 인부 한 명, 곡괭이로 다시 시작해요.\n'
          '골드와 도감은 그대로 가져가요.\n'
          '${_game.mineName}은(는) 관리인이 맡아 '
          '초당 ${formatRate(caretaker)} 골드를 계속 보내 줘요.',
      choices: [
        ('나중에', false, () {}),
        (
          '개척하기 (${formatGold(_game.pioneerCost)} 골드)',
          true,
          _game.canPioneer
              ? () {
                  if (_game.pioneer()) {
                    _sound.play(Sfx.pioneer);
                    _sound.vibrate(Buzz.heavy);
                    _showMessage('🗺 ${_game.region.name}에 도착했어요!');
                  }
                }
              : null,
        ),
      ],
    );
  }

  /// 구매 버튼: 성공하면 "띠링".
  void _buy(bool Function() action) {
    if (action()) _sound.play(Sfx.buy);
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
    if (!_game.upgradePickaxe()) return;
    if (_game.equipmentTier == before) {
      _sound.play(Sfx.buy);
      return;
    }
    _sound.play(Sfx.fanfare);
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
          '소장님, 새 장비가 들어왔어요!\n'
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
              onPressed: () => _buy(_game.hireWorker),
            ),
          ),
          Expanded(
            child: _game.isAtBottom
                ? _pioneerTile()
                : UpgradeTile(
                    icon: Icons.terrain,
                    title: '광산 확장',
                    description:
                        'B${_game.mineLevel + 1}층 · 생산 ×${nextMultiplier.toStringAsFixed(1)}',
                    cost: _game.mineUpgradeCost,
                    enabled: _game.canUpgradeMine,
                    onPressed: () => _buy(_game.upgradeMine),
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
