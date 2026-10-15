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
        if (mounted) ask(context, '${s.name}의 방송 데뷔', introBody(), const [DialogButton('방송 시작!', primary: true)]);
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
          content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xEE2A2622),
          duration: const Duration(milliseconds: 2200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 24),
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
      '${news ? '📰' : '⚡'} ${ev.title}',
      [eventText(game.eventText(ev))],
      [for (final c in ev.choices) DialogButton(c.label, choice: true)],
    );
    final out = game.resolveEvent(ev, idx);
    if (!mounted) return;
    await ask(
      context,
      ev.title,
      [eventText(Sns.fill(out.choice.result, s)), changeChips(out.changes)],
      [DialogButton(out.trend != null ? '📱 SNS 반응 보러 가기' : '확인', primary: true)],
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
    final head = r.viral ? '🚀 떡상!' : (r.flop ? '😓 오늘은 좀 별로…' : '방송 종료');
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
    ]);
    if (out.trend != null && mounted) await showPhone(context, game, trendTab: true, trend: out.trend);
    if (await _checkOver()) return;
    await _advance();
  }

  Future<void> _upload() async {
    final out = game.upload();
    final r = out.result;
    await ask(context, r.viral ? '🚀 쇼츠 대박!' : '업로드 완료', [
      resultGrid([
        ('조회수', shortNum(r.views)),
        ('새 구독자', '+${shortNum(r.gain)}'),
        ('광고 수익', r.ads > 0 ? shortWon(r.ads) : '-'),
      ]),
    ], [
      DialogButton(out.trend != null ? '📱 반응 보러 가기' : '확인', primary: true)
    ]);
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
      Text('ENDING', style: TextStyle(color: Pal.endingColor(e.type), fontWeight: FontWeight.w800, letterSpacing: 1)),
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
      mutedText('엔딩 도감 ${got.length} / ${endings.length}'),
    ], const [
      DialogButton('📱 마지막 반응 보기'),
      DialogButton('새 게임', primary: true),
    ]);
    if (!mounted) return;
    if (i == 0) await showPhone(context, game, trendTab: true);
    if (i == 1) widget.onExit?.call();
  }

  // ───── 화면 ─────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                children: [
                  _hud(),
                  const SizedBox(height: 10),
                  _stage(),
                  const SizedBox(height: 10),
                  s.ended == null ? _actions() : _endActions(),
                  const SizedBox(height: 10),
                  _log(),
                ],
              ),
            ),
            widget.ads.buildBanner(),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Pal.surface, border: Border.all(color: Pal.border), borderRadius: BorderRadius.circular(12)),
        child: child,
      );

  Widget _hud() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'D+${s.day.clamp(1, seasonDays)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                TextSpan(text: ' / $seasonDays일 · ${slotNames[s.slot]}', style: const TextStyle(color: Pal.muted, fontSize: 13)),
              ])),
              const Spacer(),
              Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Pal.accent, borderRadius: BorderRadius.circular(999)),
                child: Text(rankName(s.followers), style: const TextStyle(color: Pal.accentText, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _num('구독자', shortNum(s.followers))),
            const SizedBox(width: 8),
            Expanded(child: _num('통장', shortWon(s.money))),
          ]),
          const SizedBox(height: 10),
          _meter('체력', s.energy / 100, Pal.energy, '${s.energy}'),
          _meter('멘탈', s.mental / 100, Pal.mental, '${s.mental}'),
          _meter('이미지', (s.image + 100) / 200, Pal.image, imageText(s.image)),
          _meter('논란', s.heat / 100, Pal.heat, '${s.heat}'),
        ],
      ),
    );
  }

  Widget _num(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pal.text, fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
      );

  Widget _meter(String label, double value, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 44, child: Text(label, style: const TextStyle(fontSize: 13, color: Pal.muted))),
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(color: Pal.bg, border: Border.all(color: Pal.border), borderRadius: BorderRadius.circular(2)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(color: color),
                ),
              ),
            ),
            SizedBox(width: 44, child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          ],
        ),
      );

  Widget _stage() {
    final trend = contentOf(s.trend);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2F4A), Color(0xFF171A2C)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.stage, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          RoomView(state: s, mode: s.mode, effects: game.effects),
          if (_live)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(4)),
                child: Text('● LIVE  👁 ${shortNum(_shownViewers)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ),
          if (_live && _chat.isNotEmpty)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 190,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xB80A0C18), borderRadius: BorderRadius.circular(8)),
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
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xA60A0C18), borderRadius: BorderRadius.circular(999)),
                child: Text('🔥 이번 주 대세: ${trend.icon} ${trend.name}', style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          Positioned(top: 8, right: 8, child: _phoneButton()),
        ],
      ),
    );
  }

  Widget _phoneButton() {
    return GestureDetector(
      key: const ValueKey('phone-button'),
      onTap: () => showPhone(context, game),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Pal.stage, width: 2),
              boxShadow: const [BoxShadow(color: Pal.stage, offset: Offset(0, 3))],
            ),
            child: const Text('📱', style: TextStyle(fontSize: 22)),
          ),
          if (s.unread > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(999)),
                child: Text(s.unread > 99 ? '99+' : '${s.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  static const _actionList = [
    ('stream', '📡', '방송하기', '콘텐츠 선택'),
    ('upload', '✂️', '편집·업로드', '체력 15'),
    ('work', '🏪', '편의점 알바', '+6만 원 · 체력 22'),
    ('rest', '🛋️', '휴식', '체력·멘탈 회복'),
    ('sleep', '😴', '잠자기', '하루 마치기'),
    ('shop', '🛒', '장비 쇼핑', '시간 안 듦'),
  ];

  Widget _actions() {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width < 480 ? 2 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final (id, icon, label, sub) in _actionList)
          ChunkyButton(
            key: ValueKey('act-$id'),
            edge: id == 'stream' ? Pal.live : Pal.border,
            onTap: _block(id) == null ? () => _act(id) : null,
            child: _actionLabel(icon, label, _block(id) ?? sub),
          ),
      ],
    );
  }

  Widget _actionLabel(String icon, String label, String sub) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Pal.text)),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: Pal.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      );

  Widget _endActions() => Row(children: [
        Expanded(
          child: ChunkyButton(onTap: () => showPhone(context, game, trendTab: true), child: _actionLabel('📱', '마지막 반응 보기', 'SNS')),
        ),
        const SizedBox(width: 8),
        Expanded(child: ChunkyButton(onTap: widget.onExit, child: _actionLabel('🔄', '새 게임', '처음부터'))),
      ]);

  Widget _log() {
    Color? color(String kind) => switch (kind) {
          'viral' => Pal.good,
          'flop' => Pal.muted,
          'event' => Pal.accent,
          'milestone' => Pal.trueEnd,
          _ => null,
        };
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 기록', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          for (final (i, l) in s.log.take(8).indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: i == 0 ? null : const BoxDecoration(border: Border(top: BorderSide(color: Pal.border))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 64, child: Text('D${l.day} ${slotNames[l.slot]}', style: const TextStyle(fontSize: 12, color: Pal.muted))),
                  Expanded(
                    child: Text(
                      l.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: color(l.kind) ?? Pal.text,
                        fontWeight: l.kind == 'day' || l.kind == 'viral' || l.kind == 'milestone' ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
