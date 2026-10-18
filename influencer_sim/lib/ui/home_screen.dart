import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../audio/sound_service.dart';
import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import '../game/rules.dart';
import '../game/sns.dart';
import '../scene/room_view.dart';
import 'dialogs.dart';
import 'palette.dart';
import 'minigame.dart';
import 'sheets.dart';
import 'sns_phone.dart';

/// 게임 화면: 상태판, 방, 행동 버튼, 오늘의 기록
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.ads, this.sound, this.showIntro = false, this.onExit, this.liveDuration = const Duration(milliseconds: 4200)});

  final GameController game;
  final AdService ads;

  /// 효과음·배경음악 (테스트에서는 없음)
  final SoundService? sound;

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

  // 방송 중 후원 팝업과 채팅 반응 버튼
  final List<Timer> _extraTimers = [];
  (String, int, String)? _donation; // 닉네임, 금액, 메시지
  // 이번 방송에서 미니게임을 했는지 (하루 첫 방송만)
  bool _playedMini = false;

  // 시청자 질문에 잘 대답해서 오른 분위기
  int _hype = 0;

  SoundService? get _sound => widget.sound;

  /// 결과 창 버튼: 확인 + (SNS 반응이 있으면) SNS 보기. SNS는 원할 때만 연다
  List<DialogButton> _snsButtons(Trend? t) => [const DialogButton('확인', primary: true), if (t != null) const DialogButton('📱 SNS 반응 보기')];

  Future<void> _phone({bool trendTab = false, Trend? trend, bool dmTab = false}) {
    _sfx(Sfx.notify);
    return showPhone(context, game, trendTab: trendTab, trend: trend, dmTab: dmTab);
  }

  // 소리 켜기/끄기 (효과음·배경음악 함께)
  Widget _soundToggle() {
    final sound = _sound;
    if (sound == null) return const SizedBox.shrink();
    final on = sound.sfxOn || sound.musicOn;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Pressable(
        key: const ValueKey('sound-toggle'),
        onTap: () async {
          await sound.setSfxOn(!on);
          await sound.setMusicOn(!on);
          if (mounted) setState(() {});
        },
        radius: 999,
        color: Pal.surface2,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(on ? '🔊' : '🔇', style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  void _sfx(Sfx s, [Buzz? buzz]) {
    _sound?.play(s);
    if (buzz != null) _sound?.vibrate(buzz);
  }

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
    if (state == AppLifecycleState.paused) _sound?.pauseMusic();
    if (state == AppLifecycleState.resumed) _sound?.resumeMusic();
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
      _sfx(msg.startsWith('🏆') || msg.contains('이사') || msg.contains('순위') ? Sfx.fanfare : Sfx.buy, Buzz.medium);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Pal.surface2,
            duration: const Duration(milliseconds: 2200),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            // 아래 버튼을 가리지 않게 화면 위쪽에 띄운다
            margin: EdgeInsets.fromLTRB(40, 0, 40, MediaQuery.sizeOf(context).height - 150),
          ),
        );
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
          await (game.isPro ? _promote() : _work());
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

  /// 알바: 그냥 일하기 또는 알바 브이로그 찍기
  Future<void> _work() async {
    final place = game.job;
    final pay = s.slot == 2 ? (place.pay * 1.2).round() : place.pay;
    final strikes = s.workStrikes;
    final i = await ask(
      context,
      '${place.name} 알바',
      [
        mutedText('오늘 알바비 ${shortWon(pay)} · 체력 -22', size: 14),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(12)),
          child: Text('🎥 알바 브이로그를 찍으면 구독자가 늘어요. 대신 점장님께 걸리면 경고! 3번 걸리면 잘려요.\n현재 경고 $strikes/3', style: const TextStyle(color: Pal.text, fontSize: 13, height: 1.5)),
        ),
      ],
      const [DialogButton('묵묵히 일만 한다', choice: true), DialogButton('🎥 알바 브이로그를 찍는다', choice: true), DialogButton('취소')],
      icon: place.icon,
    );
    if (i == 2 || !mounted) return;
    final out = game.work(vlog: i == 1);
    _sfx(Sfx.coin);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (i == 1) {
      if (out.fired) _sfx(Sfx.alert, Buzz.heavy);
      final snsPick = await ask(
        context,
        out.fired ? '알바에서 잘렸다!' : (out.caught ? '점장님께 걸렸다…' : '알바 브이로그 완성'),
        [
          eventText(
            out.fired
                ? '"이번이 세 번째죠? 내일부터 안 나와도 돼요." 해고 순간까지 카메라에 담겼다. 그런데 이 클립이 화제가 되고 있다…'
                : out.caught
                ? '"근무 중에 촬영하면 안 된다고 했죠?" 점장님 눈빛이 싸늘하다. (경고 ${out.strikes}/3)'
                : '손님 몰래 찍은 알바 일상이 소소하게 반응을 얻었다.',
          ),
          changeChips([Change('알바비', '+${shortWon(out.pay)}', true), Change('구독자', '+${shortNum(out.gain)}', true)]),
          if (out.fired) ...[const SizedBox(height: 8), mutedText('일주일 동안 알바를 할 수 없어요. 그 뒤 새 알바를 구할 수 있어요.')],
        ],
        _snsButtons(out.trend),
        icon: out.fired ? '🚫' : (out.caught ? '😬' : '🎥'),
      );
      if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: out.trend);
    }
    await _advance();
    if (s.ended == null && s.slot != 0) game.setMode('away');
  }

  /// 전업 방송인이 된 뒤의 알바 버튼: 부모님 가게 홍보
  Future<void> _promote() async {
    final i = await ask(
      context,
      '🍗 부모님 가게 홍보',
      [
        mutedText('부모님이 차리신 치킨집을 도와드리자.', size: 14),
        const SizedBox(height: 10),
        _tradeoff('🎥 가게 일 돕기 브이로그', '체력 -20. 구독자 조금, 찐팬 증가, 부모님 용돈.'),
        const SizedBox(height: 6),
        _tradeoff('📢 방송에서 대놓고 홍보', '체력 -12. 잘되면 이미지·찐팬·용돈이 크게 늘지만 "가족 장사" 논란이 날 수도 있어요.'),
      ],
      const [DialogButton('🎥 가게 일 돕기 브이로그', choice: true), DialogButton('📢 방송에서 홍보하기', choice: true), DialogButton('취소')],
      icon: '🍗',
    );
    if (i == 2 || !mounted) return;
    final out = game.promote(onAir: i == 1);
    _sfx(out.backlash ? Sfx.alert : Sfx.coin);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final snsPick = await ask(
      context,
      i == 0 ? '효도 브이로그 완성' : (out.backlash ? '"가족 장사" 논란…' : '주문 폭주!'),
      [
        eventText(
          i == 0
              ? '앞치마를 두르고 치킨을 튀겼다. 손님들이 알아보고 사진을 찍어 갔다. 엄마가 몰래 용돈을 쥐여 주셨다.'
              : out.backlash
              ? '"방송을 광고판으로 쓰냐"는 채팅이 올라왔다. 부모님 가게 이야기가 커뮤니티에 퍼지고 있다.'
              : '방송이 끝나자마자 가게 전화가 불이 났다. 아빠가 "덕분에 닭이 다 떨어졌다"며 웃으셨다.',
        ),
        changeChips(out.changes),
      ],
      _snsButtons(out.trend),
      icon: i == 0 ? '🎥' : (out.backlash ? '😥' : '🍗'),
    );
    if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: out.trend);
    await _advance();
    if (s.ended == null && s.slot != 0) game.setMode('away');
  }

  Future<void> _advance() async {
    if (game.advance()) await _endDay(0);
  }

  Future<void> _endDay(int remaining) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final report = game.endDay(remaining);
    if (await _checkOver()) return;
    if (report.goal != null) return _goalEnding(report.goal!);
    if (report.news != null) {
      await _runEvent(report.news!, news: true);
      await _checkOver();
    }
  }

  /// 목표 엔딩 달성: 엔딩 도감에 오르고, 계속 방송하거나 은퇴할 수 있다
  Future<void> _goalEnding(String key) async {
    final e = endings[key]!;
    _sfx(Sfx.fanfare, Buzz.heavy);
    game.emit('heart', 24);
    final i = await ask(
      context,
      e.title,
      [
        Center(
          child: Text(
            'ENDING 달성!',
            style: TextStyle(color: Pal.endingColor(e.type), fontWeight: FontWeight.w800, letterSpacing: 3),
          ),
        ),
        const SizedBox(height: 6),
        eventText(e.text),
        const SizedBox(height: 6),
        mutedText('엔딩 도감에 기록됐어요. 여기서 은퇴할 수도, 더 높은 곳을 향해 계속 방송할 수도 있어요.', size: 13),
      ],
      const [DialogButton('📡 계속 방송하기', primary: true), DialogButton('🏳️ 여기서 은퇴하기')],
      icon: e.type == 'true' ? '👑' : '🏆',
    );
    if (i == 1 && mounted) await _finish(key);
  }

  /// 내 채널: 캐릭터 크게 보기, 기록, 은퇴
  Future<void> _profile() async {
    final retire = await openProfile(context, game);
    if (retire == true && mounted) {
      final ok = await ask(context, '정말 은퇴할까요?', [mutedText('지금까지의 성적으로 엔딩이 정해지고, 이 게임은 끝나요.', size: 14)], const [DialogButton('은퇴하기', primary: true), DialogButton('더 해 볼래요')], icon: '🏳️');
      if (ok == 0 && mounted) await _finish(game.retireEndingKey());
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
    _sfx(Sfx.alert, Buzz.medium);
    final crisis = ev.where == 'crisis';
    final idx = await ask(context, ev.title, [eventText(game.eventText(ev))], [for (final c in ev.choices) DialogButton(c.label, choice: true)], icon: crisis ? '🚨' : (news ? '📰' : '⚡'));
    final out = game.resolveEvent(ev, idx);
    if (!mounted) return;
    final snsPick = await ask(
      context,
      out.won == null ? ev.title : (out.won! ? '${ev.title} · 성공!' : '${ev.title} · 실패…'),
      [eventText(Sns.fill(out.choice.result, s)), changeChips(out.changes)],
      _snsButtons(out.trend),
      icon: out.changes.where((c) => c.good == false).length > out.changes.where((c) => c.good == true).length ? '😥' : '✨',
    );
    if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: out.trend);
  }

  Future<void> _stream() async {
    final c = await chooseContent(context, game);
    if (c == null || !mounted) return;

    var r = game.beginStream(c);
    _startLive(r.viewers, () => game.chatLine(c));
    _scheduleExtras(r);

    // 하루 첫 방송만 콘텐츠별 미니게임. 결과(별 0~5)가 오늘의 컨디션이 되어 그날 방송 모두에 보너스
    _playedMini = false;
    if (game.needMinigame) {
      await Future<void>.delayed(widget.liveDuration * 0.15);
      if (!mounted) return;
      final spec = miniFor(c, petIcon: s.pet == null ? '🐾' : petOf(s.pet!).icon);
      final score = await playMinigame(context, spec, duration: widget.liveDuration * 1.5, rng: game.rng);
      if (!mounted) return;
      final stars = starsOf(score);
      game.setTodayStars(stars);
      _playedMini = true;
      _sfx(stars >= 3 ? Sfx.sparkle : Sfx.pop, Buzz.light);
      if (stars > 0) game.emit('heart', (3 * stars).round());
      setState(() {
        final lines = stars >= 3 ? const ['미쳤다 ㅋㅋㅋ', '이 맛에 봄', '찐텐 나왔다', '레전드 각', '클립 따야지'] : const ['ㅋㅋ', '오늘 좀 피곤해 보임', '괜찮아요~', '힘내요!'];
        for (var i = 0; i < 2; i++) {
          _chat.add(_crowd(lines));
        }
        while (_chat.length > 6) {
          _chat.removeAt(0);
        }
      });
    }

    // 드물게 말실수 사고. 아니면 평소처럼 방송 중 사건
    final gaffe = game.rollGaffe(c);
    if (gaffe != null) {
      await Future<void>.delayed(widget.liveDuration * 0.3);
      if (!mounted) return;
      final kept = await _handleGaffe(gaffe, r);
      if (!mounted || await _checkOver()) return;
      // 사과했다면 방송은 여기서 끝나고 3주 자숙
      if (kept == null) {
        _stopLive();
        await _hiatus();
        return;
      }
      r = kept;
    } else {
      // 방송 중간에 시청자 질문이 올라온다
      await Future<void>.delayed(widget.liveDuration * 0.25);
      if (!mounted) return;
      // 주식 방송은 질문 대신 오늘의 추천 종목을 고른다
      final q = c.id == 'stock' ? null : game.rollQuestion();
      if (c.id == 'stock') await _pickStock(r);
      if (q != null) await _askQuestion(q, r);
      await Future<void>.delayed(widget.liveDuration * 0.35);
      if (!mounted) return;
      // 질문을 받은 방송에는 사건이 겹치지 않는다
      final ev = q != null ? null : game.rollEvent('live', game.liveEventChance(c));
      if (ev != null) {
        _stopChat();
        await _runEvent(ev);
        if (await _checkOver()) return;
      }
    }
    final stars = game.todayStars;
    _stopLive();
    r = game.boostStream(r, stars, hype: _hype);

    final out = game.finishStream(c, r);
    if (r.viral) _sfx(Sfx.sparkle, Buzz.heavy);
    if (r.donation + r.ads > 0) _sfx(Sfx.coin);
    if (!mounted) return;
    final head = r.viral ? '떡상!' : (r.flop ? '오늘은 좀 별로…' : '방송 종료');
    // 하루 한 번: 광고를 보면 광고주가 후원한다
    final adOk = game.canAdDonate && widget.ads.rewardedReady.value;
    final buttons = [..._snsButtons(out.trend), if (adOk) const DialogButton('🎬 광고 보고 광고주 후원 받기')];
    final pick = await ask(
      context,
      head,
      [
        resultGrid([
          ('최고 시청자', '${shortNum(r.viewers)}명'),
          ('새 구독자', '+${shortNum(r.gain)}'),
          ('후원', shortWon(r.donation)),
          ('광고 수익', r.ads > 0 ? shortWon(r.ads) : (s.followers >= 1000 ? '0원' : '구독자 1천 명부터')),
        ]),
        const SizedBox(height: 8),
        Text(
          stars > 0 ? '🎮 오늘의 컨디션 ${starText(stars)}${_playedMini ? '' : ' (첫 방송 미니게임)'} · 시청자 +${(stars * 4).round()}% · 후원 +${(stars * 6).round()}%' : '🎮 오늘의 컨디션 0/5… 내일 첫 방송에서 다시 도전!',
          style: TextStyle(color: stars > 0 ? Pal.good : Pal.muted, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        mutedText(game.hintFor(c), size: 13),
      ],
      buttons,
      icon: r.viral ? '🚀' : (r.flop ? '😓' : c.icon),
    );
    final picked = buttons[pick].label;
    if (picked.startsWith('📱') && mounted) await _phone(trendTab: true, trend: out.trend);
    if (picked.startsWith('🎬') && mounted) await _adDonation();
    // 방송을 보고 DM으로 제안이 왔다: 팝업 대신 알림만 (휴대폰 DM 탭에 쌓인다)
    final offer = out.offer;
    if (offer != null && mounted) {
      _sfx(Sfx.notify, Buzz.medium);
      game.toast('📩 ${offer.from}에게서 DM이 왔어요');
    }
    if (await _checkOver()) return;
    await _advance();
  }

  Future<void> _upload() async {
    final out = game.upload();
    final r = out.result;
    final snsPick = await ask(
      context,
      r.viral ? '쇼츠 대박!' : '업로드 완료',
      [
        resultGrid([('조회수', shortNum(r.views)), ('새 구독자', '+${shortNum(r.gain)}'), ('광고 수익', r.ads > 0 ? shortWon(r.ads) : '-')]),
      ],
      _snsButtons(out.trend),
      icon: r.viral ? '🚀' : '✂️',
    );
    if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: out.trend);
    await _advance();
  }

  // 방송 중 채팅과 시청자 수 연출. 시청자 수는 지금 값에서 [viewers]로 움직인다
  void _startLive(int viewers, (String, int, String) Function() line, {bool keepChat = false}) {
    _stopChat();
    final from = _live ? _shownViewers : 1;
    setState(() {
      _live = true;
      if (!keepChat) _chat.clear();
      _shownViewers = from;
    });
    var i = 0;
    const steps = 22;
    _viewerTimer = Timer.periodic(const Duration(milliseconds: 110), (t) {
      i++;
      final k = (i / steps).clamp(0.0, 1.0);
      setState(() => _shownViewers = ((from + (viewers - from) * k) * (0.95 + game.rng.nextDouble() * 0.1)).round().clamp(1, 1 << 31));
      if (i >= steps) t.cancel();
    });
    _chatTimer = Timer.periodic(const Duration(milliseconds: 320), (_) {
      setState(() {
        _chat.add(line());
        if (_chat.length > 6) _chat.removeAt(0);
      });
    });
  }

  (String, int, String) _crowd(List<String> lines) {
    final u = game.sns.user();
    return (u.nick, u.color, lines[game.rng.nextInt(lines.length)]);
  }

  /// 말실수 → 대처 선택 → (사과 방송 / 강행) → SNS 반응. 사고 영향을 반영한 결과를 돌려준다.
  /// 방송을 강행하면 줄어든 방송 결과를, 사과하면 null(방송 중단 → 자숙)을 돌려준다.
  Future<StreamResult?> _handleGaffe(Gaffe g, StreamResult r) async {
    _sfx(Sfx.alert, Buzz.heavy);
    // 채팅창이 술렁인다
    _stopChat();
    setState(() {
      for (var i = 0; i < 4; i++) {
        _chat.add(_crowd(chatGaffe));
      }
      while (_chat.length > 6) {
        _chat.removeAt(0);
      }
    });
    final idx = await ask(
      context,
      '방송 사고! 말실수',
      [
        eventText(g.text),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Pal.bad.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Pal.bad.withValues(alpha: 0.4)),
          ),
          child: Text(
            g.quote,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        mutedText('채팅창이 얼어붙었다. 어떻게 할까?'),
        const SizedBox(height: 10),
        _tradeoff('🔥 방송 강행', '수입은 줄어도 조금은 남는다. 대신 팬이 떠나고 안티가 생긴다.'),
        const SizedBox(height: 6),
        _tradeoff('🙇 사과 후 자숙', '방송을 접고 3주간 자숙한다. 그동안 수입 0, 생활비는 나간다. 팬은 덜 떠난다.'),
      ],
      const [DialogButton('사과 없이 방송을 이어간다', choice: true), DialogButton('사과하고 3주간 자숙한다', choice: true)],
      icon: '😱',
    );
    if (!mounted) return null;
    final apologize = idx == 1;

    // 연출: 사과 방송(크로마키 + 자막) 또는 싸늘해진 방송
    if (apologize) {
      game.setMode('apology');
      _startLive((r.viewers * 0.85).round(), () => _crowd(chatApology), keepChat: true);
    } else {
      _startLive((r.viewers * 0.55).round(), () => _crowd(chatGaffe), keepChat: true);
    }
    await Future<void>.delayed(widget.liveDuration);
    if (!mounted) return null;
    _stopChat();

    final out = game.resolveGaffe(g, r, apologize: apologize);
    game.setMode('live');
    final snsPick = await ask(
      context,
      apologize ? '사과 방송을 마쳤다' : '분위기가 싸해졌다',
      [eventText(apologize ? '"제 경솔한 발언으로 상처받으신 분들께 진심으로 사과드립니다. 당분간 방송을 쉬며 반성의 시간을 갖겠습니다." 방송을 종료했다.' : '아무 일 없었다는 듯 방송을 이어갔다. 채팅창은 싸늘해졌고, 하나둘 방을 나갔다. 커뮤니티에 클립이 돌기 시작했다.'), changeChips(out.changes)],
      _snsButtons(out.trend),
      icon: apologize ? '🙇' : '😶',
    );
    if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: out.trend);
    return apologize ? null : out.result;
  }

  Widget _tradeoff(String title, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(12)),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$title  ',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(color: Pal.muted),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 12.5, height: 1.5),
    ),
  );

  /// 3주 자숙: 검은 화면에서 날짜가 흐르고, 결과와 복귀 반응을 보여 준다
  Future<void> _hiatus() async {
    final from = s.day;
    final report = game.startHiatus();
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, _, _) => HiatusOverlay(from: from, to: from + report.days, duration: widget.liveDuration * 1.2, onDone: () => Navigator.pop(ctx)),
    );
    if (!mounted) return;
    final snsPick = await ask(
      context,
      '${report.days ~/ 7}주 후…',
      [eventText('자숙 기간이 끝났다. 쉬는 동안 논란은 가라앉았지만, 기다리다 지친 팬도 있었다. 조심스럽게 복귀 방송을 켠다.'), changeChips(report.changes)],
      _snsButtons(report.trend),
      icon: '🌙',
    );
    if (snsPick == 1 && mounted) await _phone(trendTab: true, trend: report.trend);
    await _checkOver();
  }

  /// 방송 중: 후원 팝업 두 번, 채팅 반응 버튼 두 번
  String _pickLabel(Asset a) {
    final ch = game.changeOf(a);
    return '${a.icon} ${a.name}  ${ch >= 0 ? '▲' : '▼'}${(ch.abs() * 100).toStringAsFixed(1)}%${a.kind == 'coin' ? '  (고위험·고수익)' : ''}';
  }

  /// 주식 방송: 오늘의 추천 종목 (내일 아침 결과)
  Future<void> _pickStock(StreamResult r) async {
    _sfx(Sfx.notify, Buzz.light);
    final i = await ask(
      context,
      '📊 오늘의 추천 종목은?',
      [eventText('채팅창이 "오늘 뭐 사요??"로 도배됐다. 어떤 종목을 추천할까?'), const SizedBox(height: 6), mutedText('내일 아침 오르면 구독자가 늘고, 떨어지면 "내 돈 내놔" DM이 쏟아져요. 코인은 더 크게 움직여요.', size: 12.5)],
      [for (final a in assets) DialogButton(_pickLabel(a), choice: true)],
      icon: '📈',
    );
    if (!mounted) return;
    final a = assets[i];
    game.setPick(a, r.viewers);
    setState(() {
      for (final t in ['${a.name} 가즈아!!!', '풀매수 갑니다', '이거 믿어도 돼요?', '저는 이미 물려 있음 ㅋㅋ']) {
        _chat.add(_crowd([t]));
      }
      while (_chat.length > 6) {
        _chat.removeAt(0);
      }
    });
  }

  /// 보상형 광고를 끝까지 보면 광고주가 후원을 보낸다
  Future<void> _adDonation() async {
    final ok = await widget.ads.showRewarded();
    if (!ok || !mounted) return;
    final amount = game.claimAdDonation();
    _sfx(Sfx.donate, Buzz.medium);
    await ask(
      context,
      '광고주 후원!',
      [
        eventText('"방금 본 광고의 광고주님도 ${s.name}님의 방송을 시청하고 있어요!"'),
        const SizedBox(height: 6),
        changeChips([Change('후원', '+${shortWon(amount)}', true)]),
      ],
      const [DialogButton('감사합니다!', primary: true)],
      icon: '💸',
    );
  }

  /// 시청자 질문에 대답하기
  Future<void> _askQuestion(ChatQuestion q, StreamResult r) async {
    _sfx(Sfx.notify, Buzz.light);
    final u = game.sns.user();
    final i = await ask(
      context,
      '시청자 질문',
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(14)),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${u.nick}  ',
                  style: TextStyle(color: Color(u.color), fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: q.question,
                  style: const TextStyle(color: Pal.text),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14.5, height: 1.45),
          ),
        ),
      ],
      [for (final a in q.answers) DialogButton(a.label, choice: true)],
      icon: '🙋',
    );
    if (!mounted) return;
    final (reactions, hype, _) = game.answerQuestion(q, i, r.viewers);
    _hype += hype;
    if (hype > 0) game.emit('heart', 6 * hype);
    setState(() {
      for (final t in reactions) {
        _chat.add(_crowd([t]));
      }
      while (_chat.length > 6) {
        _chat.removeAt(0);
      }
    });
  }

  void _scheduleExtras(StreamResult r) {
    _hype = 0;
    final d = widget.liveDuration.inMilliseconds;
    Timer at(double frac, void Function() f) {
      final tm = Timer(Duration(milliseconds: (d * frac).round()), () {
        if (mounted) f();
      });
      _extraTimers.add(tm);
      return tm;
    }

    if (r.donation > 0) {
      for (final frac in const [0.1, 0.52]) {
        at(frac, () {
          final u = game.sns.user();
          final amount = max(1000, (r.donation * (0.15 + game.rng.nextDouble() * 0.2) / 1000).round() * 1000);
          setState(() => _donation = (u.nick, amount, donationMsgs[game.rng.nextInt(donationMsgs.length)]));
          _sfx(Sfx.donate, Buzz.light);
          game.emit('coin', 4);
        });
        at(frac + 0.3, () => setState(() => _donation = null));
      }
    }
  }

  void _stopChat() {
    for (final tm in _extraTimers) {
      tm.cancel();
    }
    _extraTimers.clear();
    _donation = null;
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
    final i = await ask(
      context,
      e.title,
      [
        Center(
          child: Text(
            'ENDING',
            style: TextStyle(color: Pal.endingColor(e.type), fontWeight: FontWeight.w800, letterSpacing: 3),
          ),
        ),
        const SizedBox(height: 6),
        eventText(e.text),
        const SizedBox(height: 6),
        resultGrid([('구독자', shortNum(s.followers)), ('최고 시청자', '${shortNum(s.peak)}명'), ('총 수입', shortWon(s.earned)), ('방송 횟수', '${s.streams}회'), ('이미지', imageText(s.image)), ('방송한 날', '${s.day}일')]),
        const SizedBox(height: 4),
        Center(child: mutedText('엔딩 도감 ${got.length} / ${endings.length}')),
      ],
      const [DialogButton('📜 발자취 보기', primary: true), DialogButton('📱 마지막 반응 보기'), DialogButton('새 게임')],
      icon: e.type == 'bad' ? '🥀' : (e.type == 'true' ? '👑' : '🏆'),
    );
    if (!mounted) return;
    if (i == 0) await openCareer(context, game);
    if (i == 1) await _phone(trendTab: true);
    if (i == 2) widget.onExit?.call();
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
                        child: Column(children: [_stats(), _todayRow(), const SizedBox(height: 12), const Spacer(), _stage(), const Spacer(), const SizedBox(height: 12), _ticker()]),
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
    final day = s.day;
    // 다음 등급까지 얼마나 남았나
    final cur = rankOf(s.followers);
    final nextIdx = ranks.indexOf(cur) + 1;
    final next = nextIdx < ranks.length ? ranks[nextIdx] : null;
    final progress = next == null ? 1.0 : ((s.followers - cur.min) / (next.min - cur.min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-button'),
                onTap: _profile,
                child: Badge(
                  isLabelVisible: game.isNew('beauty'),
                  smallSize: 10,
                  backgroundColor: Pal.live,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(gradient: Pal.brand, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFF000000 | outfitColor(s.look)),
                      child: Text(
                        s.name.characters.first,
                        // 밝은 옷 색이면 글자를 어둡게
                        style: TextStyle(color: Color(0xFF000000 | outfitColor(s.look)).computeLuminance() > 0.6 ? Pal.bg : Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    ShaderMask(
                      shaderCallback: (r) => Pal.brand.createShader(r),
                      child: Text(
                        rankName(s.followers),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Pill(icon: '👥', text: shortNum(s.followers)),
              const SizedBox(width: 6),
              GestureDetector(
                key: const ValueKey('money-pill'),
                onTap: _showLedger,
                child: Pill(icon: '💰', text: shortWon(s.money), color: s.money < 0 ? Pal.bad : Pal.gold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'DAY $day',
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
              const SizedBox(width: 8),
              // 다음 등급까지 진행도 (기간 제한은 없다)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Stack(
                        children: [
                          Container(height: 6, color: Pal.surface2),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(height: 6, decoration: const BoxDecoration(gradient: Pal.brand)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      next == null ? '최고 등급!' : '다음: ${next.name} ${(progress * 100).floor()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.muted, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (game.unlocked('ranking'))
                Pressable(
                  key: const ValueKey('rank-button'),
                  onTap: _showRanking,
                  radius: 999,
                  color: Pal.surface2,
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Text(
                    // 가장 높은 장르 순위가 3위 안이면 같이 보여 준다
                    '🏆 ${game.myRank}위${switch (game.bestGenre) {
                      (final g, final r) when r <= 3 => ' · ${contentOf(g).icon}$r위',
                      _ => '',
                    }}',
                    style: const TextStyle(color: Pal.gold, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              const SizedBox(width: 6),
              _slotChip(),
              _soundToggle(),
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
              child: Opacity(
                opacity: i == s.slot ? 1 : 0.3,
                child: Text(icons[i], style: TextStyle(fontSize: i == s.slot ? 14 : 11)),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            slotNames[s.slot],
            style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // 체력·멘탈·이미지·논란
  Widget _stats() {
    return Glass(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [_gaugeRow(), if (game.unlocked('fans')) _fans()]),
    );
  }

  Widget _gaugeRow() {
    return Row(
      children: [
        Expanded(child: _gauge('⚡', '체력', s.energy / 100, Pal.energy, '${s.energy}')),
        Expanded(child: _gauge('🧠', '멘탈', s.mental / 100, Pal.mental, '${s.mental}')),
        Expanded(child: _gauge('✨', '이미지', (s.image + 100) / 200, Pal.image, imageText(s.image))),
        Expanded(child: _gauge('🔥', '논란', s.heat / 100, Pal.heat, '${s.heat}', warn: s.heat >= 60)),
      ],
    );
  }

  // 미션 · 방송 예고 · 기록 · 업적
  Widget _todayRow() {
    final done = s.missions.where((m) => m.done).length;
    final sched = s.schedDay != 0 && s.schedContent != null ? '${s.schedDay == s.day ? '오늘' : '내일'} ${slotNames[s.schedSlot]} ${contentOf(s.schedContent!).icon}' : '방송 예고';
    // 새로 열린 기능에는 빨간 점 (한 번 열어 보면 사라진다)
    Widget chip(String feature, String key, String text, VoidCallback onTap, {bool hot = false, int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Pressable(
              key: ValueKey(key),
              onTap: s.ended == null || key == 'stats-button'
                  ? () {
                      game.seen(feature);
                      onTap();
                    }
                  : null,
              radius: 14,
              color: Pal.surface2,
              border: Border.all(color: hot ? Pal.pink : Pal.stroke),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (game.isNew(feature))
              Positioned(
                top: -3,
                right: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Pal.live,
                    shape: BoxShape.circle,
                    border: Border.all(color: Pal.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final chips = [
      if (game.unlocked('missions')) chip('missions', 'missions-button', '🎯 미션 $done/${s.missions.length}', () => openMissions(context, game), hot: done < s.missions.length, flex: 5),
      if (game.unlocked('schedule')) chip('schedule', 'schedule-button', '📅 $sched', () => openSchedule(context, game), hot: s.schedDay != 0, flex: 6),
      if (game.unlocked('stats')) chip('stats', 'stats-button', '📊 기록', () => openStats(context, game), flex: 4),
      if (game.achieved.isNotEmpty) chip('achievements', 'achievements-button', '🏅 ${game.achieved.length}', () => openAchievements(context, game), flex: 3),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: chips),
    );
  }

  // 팬 성비 막대 + 안티 수
  Widget _fans() {
    final m = (s.maleFans * 100).round();
    const male = Color(0xFF60A5FA);
    const female = Color(0xFFF472B6);
    final extra = <Widget>[
      if (s.coreFans > 0)
        Text(
          '💖 찐팬 ${shortNum(s.coreFans)}',
          style: const TextStyle(color: Color(0xFFFF7AB6), fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      if (s.antis > 0)
        Text(
          '😈 안티 ${shortNum(s.antis)}',
          style: const TextStyle(color: Pal.bad, fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      if (s.flags.contains('mcn'))
        const Text(
          '🏢 MCN 소속',
          style: TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '팬 성비',
                style: TextStyle(color: Pal.muted, fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '♂$m%',
                style: const TextStyle(color: male, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        Expanded(
                          flex: max(m, 1),
                          child: Container(color: male),
                        ),
                        Expanded(
                          flex: max(100 - m, 1),
                          child: Container(color: female),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '♀${100 - m}%',
                style: const TextStyle(color: female, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(spacing: 12, runSpacing: 4, children: extra),
            ),
          ],
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
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: Pal.muted, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: warn ? Pal.heat : Pal.text, fontSize: 15, fontWeight: FontWeight.w900),
        ),
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
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                ),
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
          // 사과 방송 자막
          if (s.mode == 'apology')
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xE6000000), borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  children: [
                    Text(
                      '죄송합니다',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '경솔한 발언으로 상처받으신 분들께 진심으로 사과드립니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFD9DBEA), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          if (_live)
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      s.mode == 'apology' ? '● 사과 방송' : '● LIVE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '👁 ${shortNum(_shownViewers)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_live && _chat.isNotEmpty)
            Positioned(
              right: 10,
              bottom: s.mode == 'apology' ? null : 10,
              top: s.mode == 'apology' ? 66 : null,
              child: Container(
                width: 190,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xB8080A16), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (nick, color, text) in s.mode == 'apology' ? _chat.skip(max(0, _chat.length - 3)) : _chat)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: nick,
                              style: TextStyle(color: Color(color), fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: ' $text'),
                          ],
                        ),
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
                decoration: BoxDecoration(
                  color: const Color(0xA6080A16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Pal.stroke),
                ),
                child: Text(
                  '🔥 이번 주 대세  ${trend.icon} ${trend.name}',
                  style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          // 후원 팝업
          Positioned(
            top: 46,
            left: 24,
            right: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: _donation == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_donation),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xEEFFB13B), Color(0xEEFF4D8D)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '💰 ${_donation!.$1}님 ${won(_donation!.$2)} 후원!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          Text(
                            '"${_donation!.$3}"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
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
      onTap: () => _phone(),
      radius: 16,
      color: const Color(0xCCFFFFFF),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox(
            width: 46,
            height: 46,
            child: Center(child: Text('📱', style: TextStyle(fontSize: 22))),
          ),
          if (s.unread + game.dmUnread > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Pal.live,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  s.unread + game.dmUnread > 99 ? '99+' : '${s.unread + game.dmUnread}',
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
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
            child: Text(
              last?.text ?? '아직 기록이 없어요',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _logColor(last?.kind ?? ''), fontSize: 13, fontWeight: FontWeight.w600),
            ),
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

  // 스트리머 인기 순위표
  void _showRanking() {
    // 'all'이면 전체 순위, 아니면 장르(콘텐츠 id)별 순위
    var tab = 'all';
    showSheet<void>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setTab) {
          final all = tab == 'all';
          final rows = all ? game.ranking() : game.genreRanking(tab);
          final title = all ? null : genreTitles[tab];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              sheetHeader(ctx, '🏆 스트리머 인기 순위', sub: all ? '구독자 순 · ▲▼는 하루 전 대비' : '이 장르로 모은 구독자 순 · 1위 칭호 "$title"'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (id, label) in [('all', '전체'), for (final c in contents) (c.id, '${c.icon} ${c.name.replaceAll(' 방송', '')}')])
                      ChoiceChip(
                        key: ValueKey('rank-tab-$id'),
                        visualDensity: VisualDensity.compact,
                        label: Text(id != 'all' && s.flags.contains('crown_$id') ? '👑 $label' : label),
                        selected: tab == id,
                        onSelected: (_) => setTab(() => tab = id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [for (final (i, (id, name, icon, followers)) in rows.indexed) _rankRow(i + 1, id, name, icon, followers, showMove: all)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rankRow(int rank, String id, String name, String icon, int followers, {bool showMove = true}) {
    final me = id == 'me';
    final prev = showMove ? s.prevRanks[id] : null;
    final move = prev == null ? 0 : prev - rank;
    const medals = {1: Color(0xFFFFC94D), 2: Color(0xFFD9DDE3), 3: Color(0xFFE0A06A)};
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: me ? null : Pal.surface2,
        gradient: me ? Pal.brandSoft : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: me ? Pal.pink : Pal.stroke, width: me ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(color: medals[rank] ?? Pal.muted, fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Pal.bg,
              shape: BoxShape.circle,
              border: Border.all(color: medals[rank] ?? Pal.stroke),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              me ? '$name (나)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Pal.text, fontWeight: me ? FontWeight.w900 : FontWeight.w700, fontSize: 14.5),
            ),
          ),
          Text(
            shortNum(followers),
            style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          SizedBox(
            width: 38,
            child: Text(
              move > 0 ? '▲$move' : (move < 0 ? '▼${-move}' : '–'),
              textAlign: TextAlign.right,
              style: TextStyle(color: move > 0 ? Pal.bad : (move < 0 ? Pal.shield : Pal.muted), fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // 통장 내역: 날짜별 수입·지출
  void _showLedger() {
    final today = s.ledger.where((l) => l.day == s.day);
    final week = s.ledger.where((l) => l.day > s.day - 7);
    int sum(Iterable<LedgerEntry> xs, bool income) => xs.where((l) => income ? l.amount > 0 : l.amount < 0).fold(0, (a, l) => a + l.amount);
    Widget box(String label, int v, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                '${v > 0 ? '+' : ''}${shortWon(v)}',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
    final days = <int>[];
    for (final l in s.ledger) {
      if (!days.contains(l.day)) days.add(l.day);
    }
    showSheet<void>(
      context,
      (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sheetHeader(ctx, '💰 통장', sub: '잔고 ${s.money < 0 ? '-' : ''}${won(s.money)} · 매일 밤 생활비 ${shortWon(game.rent)}'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                box('오늘 수입', sum(today, true), Pal.good),
                const SizedBox(width: 8),
                box('최근 7일 수입', sum(week, true), Pal.good),
                const SizedBox(width: 8),
                box('최근 7일 지출', sum(week, false), Pal.bad),
              ],
            ),
          ),
          Flexible(
            child: s.ledger.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: mutedText('아직 내역이 없어요'))
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      for (final d in days) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Text(
                            'DAY $d',
                            style: const TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (final l in s.ledger.where((l) => l.day == d))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.label,
                                    style: const TextStyle(color: Pal.text, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '${l.amount > 0 ? '+' : '-'}${won(l.amount)}',
                                  style: TextStyle(color: l.amount > 0 ? Pal.good : Pal.bad, fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

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
                          child: Text(
                            'D${l.day} ${slotNames[l.slot]}',
                            style: const TextStyle(fontSize: 11, color: Pal.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.text,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: _logColor(l.kind),
                              fontWeight: l.kind == 'day' || l.kind == 'viral' || l.kind == 'milestone' ? FontWeight.w800 : FontWeight.w500,
                            ),
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

  static const _small = [('upload', '✂️', '업로드'), ('work', '🏪', '알바'), ('rest', '🛋️', '휴식'), ('sleep', '😴', '잠자기'), ('shop', '🛒', '상점')];

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
            children: [
              for (final (id, icon, label) in _small) Expanded(child: id == 'work' && game.isPro && s.flags.contains('parentShop') ? _roundAction(id, '🍗', '가게 홍보') : _roundAction(id, icon, label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundAction(String id, String icon, String label) {
    final why = _block(id);
    return SizedBox(
      child: Column(
        children: [
          Pressable(
            key: ValueKey('act-$id'),
            onTap: why == null ? () => _act(id) : null,
            radius: 20,
            color: Pal.surface2,
            border: Border.all(color: Pal.stroke),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(
            why ?? _subFor(id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: why != null ? Pal.bad : Pal.muted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _subFor(String id) => switch (id) {
    'upload' => '⚡15',
    'work' => game.isPro ? '용돈·찐팬' : '+6만',
    'rest' => '회복',
    'sleep' => '하루 끝',
    _ => '시간 0',
  };

  Widget _endDock() => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: const BoxDecoration(
      color: Pal.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Row(
      children: [
        Expanded(
          child: GhostButton(key: const ValueKey('career'), label: '📜 발자취', onTap: () => openCareer(context, game)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GhostButton(label: '📱 반응', onTap: () => _phone(trendTab: true)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GradientButton(label: '새 게임', onTap: widget.onExit),
        ),
      ],
    ),
  );
}

/// 자숙 화면: 검은 바탕에서 날짜가 빠르게 넘어간다
class HiatusOverlay extends StatelessWidget {
  const HiatusOverlay({super.key, required this.from, required this.to, required this.duration, required this.onDone});

  final int from;
  final int to;
  final Duration duration;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          onEnd: () => Future<void>.delayed(const Duration(milliseconds: 600), onDone),
          builder: (context, v, _) {
            final day = (from + (to - from) * Curves.easeInOut.transform(v)).round().clamp(from, to);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '자숙 기간',
                  style: TextStyle(color: Color(0xFF6B6F8A), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 4),
                ),
                const SizedBox(height: 14),
                Text(
                  'DAY $day',
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: v,
                  child: Text(
                    '${(to - from) ~/ 7}주 후…',
                    style: const TextStyle(color: Color(0xFFB9BCD6), fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
