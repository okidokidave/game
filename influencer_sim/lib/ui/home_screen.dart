import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import '../game/sns.dart';
import '../scene/room_view.dart';
import 'dialogs.dart';
import 'palette.dart';
import 'sns_phone.dart';

/// 게임 화면: 상태판, 방, 행동 버튼, 오늘의 기록
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.ads, this.showIntro = false, this.onExit, this.liveDuration = const Duration(milliseconds: 2600)});

  final GameController game;
  final AdService ads;

  /// 새 게임이면 시작 안내 팝업을 띄운다.
  final bool showIntro;

  /// 게임이 끝나고 "새 게임"을 누르면 (타이틀로)
  final VoidCallback? onExit;

  /// 방송 연출 길이 (테스트에서 줄인다)
  final Duration liveDuration;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  GameController get game => widget.game;
  GameState get s => game.s;

  bool _busy = false;

  // 방송 연출
  bool _live = false;
  int _shownViewers = 0;
  final List<(String, int, String)> _chat = [];
  Timer? _chatTimer;
  Timer? _viewerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_onGame);
    if (widget.showIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ask(context, '${s.name}의 방송 데뷔', introBody(), const [DialogButton('방송 시작!', primary: true)], icon: '📱');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && game.playing) game.save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_onGame);
    _stopChat();
    super.dispose();
  }

  void _onGame() {
    if (!mounted) return;
    setState(() {});
    // 마일스톤, 구입 알림
    while (game.toasts.isNotEmpty) {
      final msg = game.toasts.removeAt(0);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Pal.surface2,
          duration: const Duration(milliseconds: 2200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          // 아래 버튼을 가리지 않게 화면 위쪽에 띄운다
          margin: EdgeInsets.fromLTRB(40, 0, 40, MediaQuery.sizeOf(context).height - 150),
        ));
    }
  }

  // ───── 행동 ─────
  String? _block(String id) => _busy ? '잠시만요' : game.actionBlock(id);

  Future<void> _act(String id) async {
    if (_block(id) != null || s.ended != null) return;
    if (id == 'shop') return openShop(context, game);
    setState(() => _busy = true);
    try {
      switch (id) {
        case 'stream':
          await _stream();
        case 'upload':
          await _upload();
        case 'work':
          game.work();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _advance();
          if (s.ended == null && s.slot != 0) game.setMode('away');
        case 'rest':
          game.rest();
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await _advance();
        case 'sleep':
          final remaining = game.goSleep();
          await _endDay(remaining);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance() async {
    if (game.advance()) await _endDay(0);
  }

  Future<void> _endDay(int remaining) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final report = game.endDay(remaining);
    if (report.seasonOver) return _finish(game.seasonEndingKey());
    if (await _checkOver()) return;
    if (report.news != null) {
      await _runEvent(report.news!, news: true);
      await _checkOver();
    }
  }

  Future<bool> _checkOver() async {
    if (s.ended != null) return true;
    final key = game.overKey();
    if (key == null) return false;
    await _finish(key);
    return true;
  }

  /// 이벤트 → 결과 → SNS 반응
  Future<void> _runEvent(GameEvent ev, {bool news = false}) async {
    if (!mounted) return;
    final idx = await ask(
      context,
      ev.title,
      [eventText(game.eventText(ev))],
      [for (final c in ev.choices) DialogButton(c.label, choice: true)],
      icon: news ? '📰' : '⚡',
    );
    final out = game.resolveEvent(ev, idx);
    if (!mounted) return;
    await ask(
      context,
      ev.title,
      [eventText(Sns.fill(out.choice.result, s)), changeChips(out.changes)],
      [DialogButton(out.trend != null ? '📱 SNS 반응 보러 가기' : '확인', primary: true)],
      icon: out.changes.where((c) => c.good == false).length > out.changes.where((c) => c.good == true).length ? '😥' : '✨',
    );
    if (out.trend != null && mounted) await showPhone(context, game, trendTab: true, trend: out.trend);
  }

  Future<void> _stream() async {
    final c = await chooseContent(context, game);
    if (c == null || !mounted) return;

    final r = game.beginStream(c);
    _startLive(c, r.viewers);
    await Future<void>.delayed(widget.liveDuration);
    if (!mounted) return;

    // 방송 중 사건
    final ev = game.rollEvent('live', game.liveEventChance(c));
    if (ev != null) {
      _stopChat();
      await _runEvent(ev);
      if (await _checkOver()) return;
    }
    _stopLive();

    final out = game.finishStream(c, r);
    if (!mounted) return;
    final head = r.viral ? '떡상!' : (r.flop ? '오늘은 좀 별로…' : '방송 종료');
    await ask(context, head, [
      resultGrid([
        ('최고 시청자', '${shortNum(r.viewers)}명'),
        ('새 구독자', '+${shortNum(r.gain)}'),
        ('후원', shortWon(r.donation)),
        ('광고 수익', r.ads > 0 ? shortWon(r.ads) : (s.followers >= 1000 ? '0원' : '구독자 1천 명부터')),
      ]),
      const SizedBox(height: 6),
      mutedText(game.hintFor(c), size: 13),
    ], [
      DialogButton(out.trend != null ? '📱 반응 보러 가기' : '확인', primary: true)
    ], icon: r.viral ? '🚀' : (r.flop ? '😓' : c.icon));
    if (out.trend != null && mounted) await showPhone(context, game, trendTab: true, trend: out.trend);
    if (await _checkOver()) return;
    await _advance();
  }

  Future<void> _upload() async {
    final out = game.upload();
    final r = out.result;
    await ask(context, r.viral ? '쇼츠 대박!' : '업로드 완료', [
      resultGrid([
        ('조회수', shortNum(r.views)),
        ('새 구독자', '+${shortNum(r.gain)}'),
        ('광고 수익', r.ads > 0 ? shortWon(r.ads) : '-'),
      ]),
    ], [
      DialogButton(out.trend != null ? '📱 반응 보러 가기' : '확인', primary: true)
    ], icon: r.viral ? '🚀' : '✂️');
    if (out.trend != null && mounted) await showPhone(context, game, trendTab: true, trend: out.trend);
    await _advance();
  }

  // 방송 중 채팅과 시청자 수 연출
  void _startLive(Content c, int viewers) {
    setState(() {
      _live = true;
      _chat.clear();
      _shownViewers = 1;
    });
    var i = 0;
    const steps = 22;
    _viewerTimer = Timer.periodic(const Duration(milliseconds: 110), (t) {
      i++;
      setState(() => _shownViewers = (viewers * (i / steps).clamp(0, 1) * (0.9 + game.rng.nextDouble() * 0.2)).round().clamp(1, 1 << 31));
      if (i >= steps) t.cancel();
    });
    _chatTimer = Timer.periodic(const Duration(milliseconds: 320), (_) {
      setState(() {
        _chat.add(game.chatLine(c));
        if (_chat.length > 6) _chat.removeAt(0);
      });
    });
  }

  void _stopChat() {
    _chatTimer?.cancel();
    _viewerTimer?.cancel();
  }

  void _stopLive() {
    _stopChat();
    if (mounted) setState(() => _live = false);
  }

  // ───── 종료 ─────
  Future<void> _finish(String key) async {
    _stopLive();
    final e = endings[key]!;
    game.finish(key);
    final got = game.endingsSeen;
    if (!mounted) return;
    final i = await ask(context, e.title, [
      Center(child: Text('ENDING', style: TextStyle(color: Pal.endingColor(e.type), fontWeight: FontWeight.w800, letterSpacing: 3))),
      const SizedBox(height: 6),
      eventText(e.text),
      const SizedBox(height: 6),
      resultGrid([
        ('구독자', shortNum(s.followers)),
        ('최고 시청자', '${shortNum(s.peak)}명'),
        ('총 수입', shortWon(s.earned)),
        ('방송 횟수', '${s.streams}회'),
        ('이미지', imageText(s.image)),
        ('진행 일수', '${s.day.clamp(1, seasonDays)}일'),
      ]),
      const SizedBox(height: 4),
      Center(child: mutedText('엔딩 도감 ${got.length} / ${endings.length}')),
    ], const [
      DialogButton('새 게임', primary: true),
      DialogButton('📱 마지막 반응 보기'),
    ], icon: e.type == 'bad' ? '🥀' : (e.type == 'true' ? '👑' : '🏆'));
    if (!mounted) return;
    if (i == 1) await showPhone(context, game, trendTab: true);
    if (i == 0) widget.onExit?.call();
  }

  // ───── 화면 ─────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Pal.screen),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              // 화면이 길면 남는 공간을 위아래로 나눠 방을 가운데에, 짧으면 스크롤
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight - 16),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            _stats(),
                            const SizedBox(height: 12),
                            const Spacer(),
                            _stage(),
                            const Spacer(),
                            const SizedBox(height: 12),
                            _ticker(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              s.ended == null ? _dock() : _endDock(),
              widget.ads.buildBanner(),
            ],
          ),
        ),
      ),
    );
  }

  // 프로필 + 구독자 + 통장 + 시즌 진행
  Widget _topBar() {
    final day = s.day.clamp(1, seasonDays);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(gradient: Pal.brand, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFF000000 | s.look.shirt),
                  child: Text(s.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    ShaderMask(
                      shaderCallback: (r) => Pal.brand.createShader(r),
                      child: Text(rankName(s.followers), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Pill(icon: '👥', text: shortNum(s.followers)),
              const SizedBox(width: 6),
              Pill(icon: '💰', text: shortWon(s.money), color: Pal.gold),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('DAY $day', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(height: 6, color: Pal.surface2),
                      FractionallySizedBox(
                        widthFactor: day / seasonDays,
                        child: Container(height: 6, decoration: const BoxDecoration(gradient: Pal.brand)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _slotChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotChip() {
    const icons = ['🌅', '☀️', '🌙'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(opacity: i == s.slot ? 1 : 0.3, child: Text(icons[i], style: TextStyle(fontSize: i == s.slot ? 14 : 11))),
            ),
          const SizedBox(width: 4),
          Text(slotNames[s.slot], style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // 체력·멘탈·이미지·논란
  Widget _stats() {
    return Glass(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(child: _gauge('⚡', '체력', s.energy / 100, Pal.energy, '${s.energy}')),
          Expanded(child: _gauge('🧠', '멘탈', s.mental / 100, Pal.mental, '${s.mental}')),
          Expanded(child: _gauge('✨', '이미지', (s.image + 100) / 200, Pal.image, imageText(s.image))),
          Expanded(child: _gauge('🔥', '논란', s.heat / 100, Pal.heat, '${s.heat}', warn: s.heat >= 60)),
        ],
      ),
    );
  }

  Widget _gauge(String icon, String label, double v, Color color, String value, {bool warn = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Expanded(child: Text(label, maxLines: 1, style: const TextStyle(color: Pal.muted, fontSize: 11, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: warn ? Pal.heat : Pal.text, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(height: 5, color: Pal.bg),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    widthFactor: v.clamp(0.0, 1.0),
                    child: Container(height: 5, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _stage() {
    final trend = contentOf(s.trend);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2F5A), Color(0xFF14172E)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _live ? Pal.live.withValues(alpha: 0.7) : Pal.stroke, width: _live ? 2 : 1),
        boxShadow: [BoxShadow(color: (_live ? Pal.live : Pal.purple).withValues(alpha: 0.18), blurRadius: 24)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          RoomView(state: s, mode: s.mode, effects: game.effects),
          if (_live)
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(8)),
                    child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                    child: Text('👁 ${shortNum(_shownViewers)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
          if (_live && _chat.isNotEmpty)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                width: 190,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xB8080A16), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (nick, color, text) in _chat)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: nick, style: TextStyle(color: Color(color), fontWeight: FontWeight.w800)),
                          TextSpan(text: ' $text'),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.45),
                      ),
                  ],
                ),
              ),
            ),
          if (!_live)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xA6080A16), borderRadius: BorderRadius.circular(999), border: Border.all(color: Pal.stroke)),
                child: Text('🔥 이번 주 대세  ${trend.icon} ${trend.name}', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          Positioned(top: 10, right: 10, child: _phoneButton()),
        ],
      ),
    );
  }

  Widget _phoneButton() {
    return Pressable(
      key: const ValueKey('phone-button'),
      onTap: () => showPhone(context, game),
      radius: 16,
      color: const Color(0xCCFFFFFF),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox(width: 46, height: 46, child: Center(child: Text('📱', style: TextStyle(fontSize: 22)))),
          if (s.unread > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(s.unread > 99 ? '99+' : '${s.unread}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  // 최근 기록 한 줄. 누르면 전체 기록
  Widget _ticker() {
    final last = s.log.isEmpty ? null : s.log.first;
    return Pressable(
      key: const ValueKey('log-button'),
      onTap: _showLog,
      color: Pal.surface.withValues(alpha: 0.85),
      border: Border.all(color: Pal.stroke),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const Text('📝', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(last?.text ?? '아직 기록이 없어요', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _logColor(last?.kind ?? ''), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.expand_less_rounded, color: Pal.muted, size: 20),
        ],
      ),
    );
  }

  Color _logColor(String kind) => switch (kind) {
        'viral' => Pal.good,
        'flop' => Pal.muted,
        'event' => const Color(0xFFFF9EC2),
        'milestone' => Pal.gold,
        'buy' => const Color(0xFF9ED0FF),
        _ => Pal.text,
      };

  void _showLog() {
    showSheet<void>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sheetHeader(ctx, '📝 기록'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final l in s.log)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(999)),
                          child: Text('D${l.day} ${slotNames[l.slot]}', style: const TextStyle(fontSize: 11, color: Pal.muted, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.text,
                            style: TextStyle(fontSize: 13.5, height: 1.45, color: _logColor(l.kind), fontWeight: l.kind == 'day' || l.kind == 'viral' || l.kind == 'milestone' ? FontWeight.w800 : FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _small = [
    ('upload', '✂️', '업로드'),
    ('work', '🏪', '알바'),
    ('rest', '🛋️', '휴식'),
    ('sleep', '😴', '잠자기'),
    ('shop', '🛒', '상점'),
  ];

  // 아래 버튼 영역: 큰 방송 버튼 + 작은 동그란 버튼들
  Widget _dock() {
    final streamBlock = _block('stream');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Pal.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientButton(
            key: const ValueKey('act-stream'),
            icon: '📡',
            label: '방송 시작',
            sub: streamBlock ?? '${slotNames[s.slot]} 방송 · 콘텐츠 고르기',
            onTap: streamBlock == null ? () => _act('stream') : null,
            height: 58,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final (id, icon, label) in _small) _roundAction(id, icon, label)],
          ),
        ],
      ),
    );
  }

  Widget _roundAction(String id, String icon, String label) {
    final why = _block(id);
    return SizedBox(
      width: 62,
      child: Column(
        children: [
          Pressable(
            key: ValueKey('act-$id'),
            onTap: why == null ? () => _act(id) : null,
            radius: 20,
            color: Pal.surface2,
            border: Border.all(color: Pal.stroke),
            child: SizedBox(width: 52, height: 52, child: Center(child: Text(icon, style: const TextStyle(fontSize: 22)))),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(why ?? _subFor(id), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: why != null ? Pal.bad : Pal.muted, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _subFor(String id) => switch (id) {
        'upload' => '⚡15',
        'work' => '+6만',
        'rest' => '회복',
        'sleep' => '하루 끝',
        _ => '시간 0',
      };

  Widget _endDock() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Row(children: [
          Expanded(child: GhostButton(label: '📱 마지막 반응', onTap: () => showPhone(context, game, trendTab: true))),
          const SizedBox(width: 10),
          Expanded(child: GradientButton(label: '새 게임', onTap: widget.onExit)),
        ]),
      );
}
