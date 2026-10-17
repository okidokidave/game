import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import 'palette.dart';

/// 가상 SNS "버즈" 화면 (휴대폰 모양 팝업).
/// [trend]를 주면 트렌드 탭에서 그 주제를 먼저 보여 준다.
/// [dmTab]이면 DM함을 먼저 연다.
Future<void> showPhone(BuildContext context, GameController game, {bool trendTab = false, Trend? trend, bool dmTab = false}) {
  game.markRead();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: const Color(0x990A0C18),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, _, _) => SafeArea(child: Center(child: _Phone(game: game, trendTab: trendTab, trend: trend, dmTab: dmTab))),
    transitionBuilder: (ctx, anim, _, child) {
      final t = Curves.easeOutBack.transform(anim.value);
      return Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - t)),
          child: Transform.rotate(angle: -0.05 * (1 - t), child: child),
        ),
      );
    },
  );
}

class _Phone extends StatefulWidget {
  const _Phone({required this.game, required this.trendTab, this.trend, this.dmTab = false});
  final GameController game;
  final bool trendTab;
  final bool dmTab;
  final Trend? trend;

  @override
  State<_Phone> createState() => _PhoneState();
}

class _PhoneState extends State<_Phone> {
  late bool _trendTab = widget.trendTab;
  late Trend? _topic = widget.trend;
  late bool _dmTab = widget.dmTab;
  final _scroll = ScrollController();

  // DM함을 열었을 때 멘탈 변화 (읽은 욕·응원 DM)
  int? _dmMental;

  // 제안 DM에 답장한 결과 (DM id → 글)
  final _dmResult = <String, String>{};

  @override
  void initState() {
    super.initState();
    // 빌드 중에 상태를 바꾸지 않도록 첫 프레임 뒤에 읽음 처리
    if (_dmTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delta = widget.game.readDms();
        if (mounted && delta != 0) setState(() => _dmMental = delta);
      });
    }
  }

  void _showDm() {
    final delta = widget.game.readDms();
    setState(() {
      _dmTab = true;
      if (delta != 0) _dmMental = delta;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // 방금 한 대응 결과 (트렌드 화면 위에 보여 준다)
  String? _result;
  Trend? _resultFor;

  static const _bg = Colors.white;
  static const _text = Color(0xFF0F1419);
  static const _muted = Color(0xFF536471);
  static const _line = Color(0xFFEFF3F4);

  void _show(bool trend, [Trend? topic]) {
    setState(() {
      _trendTab = trend;
      _dmTab = false;
      _topic = topic;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size.width.clamp(0, 380).toDouble() - 24,
        height: (size.height - 32).clamp(0, 720).toDouble(),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF111111), width: 10),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 20))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('9:41', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text)),
                  Text('📶 🔋', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
              child: Row(
                children: [
                  const Text('🐝 버즈', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text)),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('phone-close'),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(backgroundColor: _line),
                    icon: const Icon(Icons.close, size: 18, color: _text),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
              child: Row(children: [
                _tab('타임라인', !_trendTab && !_dmTab, () => _show(false)),
                _tab('트렌드', _trendTab && !_dmTab, () => _show(true)),
                _tab('DM', _dmTab, _showDm, badge: widget.game.dmUnread, key: const ValueKey('dm-tab')),
              ]),
            ),
            Expanded(child: _dmTab ? _dmBody() : (_trendTab ? _trendBody() : _feedBody())),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap, {int badge = 0, Key? key}) => Expanded(
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? Pal.sns : Colors.transparent, width: 3))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? _text : _muted)),
                if (badge > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Pal.live, borderRadius: BorderRadius.circular(999)),
                    child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        ),
      );

  // ───── DM함 ─────
  Widget _dmBody() {
    final dms = widget.game.s.dms;
    if (dms.isEmpty) return _empty('아직 DM이 없어요. 방송을 하다 보면 팬도, 회사도 연락해 올 거예요.');
    final m = _dmMental;
    return ListView(
      controller: _scroll,
      children: [
        if (m != null && m != 0)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: m < 0 ? const Color(0xFFFFEEF0) : const Color(0xFFEFFAF3), borderRadius: BorderRadius.circular(12)),
            child: Text(
              m < 0 ? '😣 욕 DM을 읽고 멘탈이 흔들렸다 (멘탈 $m)' : '🥹 응원 DM에 힘이 났다 (멘탈 +$m)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: m < 0 ? Pal.hate : Pal.good),
            ),
          ),
        for (final d in dms) _dm(d),
      ],
    );
  }

  Widget _dm(Dm d) {
    final hate = d.kind == 'hate', offer = d.kind == 'offer';
    final bubble = hate ? const Color(0xFFFFF1F2) : (offer ? const Color(0xFFF2F6FF) : const Color(0xFFF4F5F7));
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(d.color),
            child: Text(offer ? '🏢' : d.nick.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: d.nick, style: const TextStyle(fontWeight: FontWeight.w800, color: _text)),
                    if (offer) const TextSpan(text: ' ✔', style: TextStyle(fontWeight: FontWeight.w900, color: Pal.sns)),
                    TextSpan(text: ' · D${d.day}', style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: bubble,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16), topLeft: Radius.circular(4)),
                  ),
                  child: Text(d.text, style: TextStyle(fontSize: 14, height: 1.45, color: hate ? const Color(0xFF9F1239) : _text)),
                ),
                if (offer) _offerBar(d),
                if (d.kind == 'weird') _weirdBar(d),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 생뚱맞은 DM: 답장 고르기
  Widget _weirdBar(Dm d) {
    final game = widget.game;
    if (d.status != 'open') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('↪ ${_dmResult[d.id] ?? d.note ?? ''}', style: const TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w700, height: 1.4)),
      );
    }
    final w = weirdOf(d.offer!.substring(6));
    return Wrap(
      children: [
        for (final (i, r) in w.replies.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 8),
            child: Material(
              color: const Color(0xFFEFF3F4),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: ValueKey('dm-reply-${d.id}-$i'),
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  final (text, changes) = game.answerWeird(d, i);
                  setState(() => _dmResult[d.id] = [text, for (final c in changes) '${c.label} ${c.text}'].join('  '));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(r.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _text)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _offerBar(Dm d) {
    final game = widget.game;
    if (d.status != 'open') {
      final label = switch (d.status) { 'accepted' => '✅ 수락함', 'declined' => '🙅 거절함', _ => '⌛ 만료됨' };
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('$label · ${_dmResult[d.id] ?? d.note ?? ''}', style: const TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w700, height: 1.4)),
      );
    }
    final o = dmOfferOf(d.offer!);
    void answer(bool accept) {
      final (text, changes, _) = game.answerOffer(d, accept: accept);
      setState(() => _dmResult[d.id] = [text, for (final c in changes) '${c.label} ${c.text}'].join('  '));
    }

    Widget btn(String label, bool accept) => Padding(
          padding: const EdgeInsets.only(right: 6, top: 8),
          child: Material(
            color: accept ? Pal.sns : const Color(0xFFEFF3F4),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: ValueKey('dm-${accept ? 'accept' : 'decline'}-${d.offer}'),
              borderRadius: BorderRadius.circular(999),
              onTap: () => answer(accept),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accept ? Colors.white : _text)),
              ),
            ),
          ),
        );
    return Wrap(children: [btn(o.accept, true), btn('거절', false)]);
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.5)),
      );

  Widget _feedBody() {
    final feed = widget.game.s.feed;
    if (feed.isEmpty) return _empty('타임라인이 조용하네요. 첫 방송을 켜 보세요!');
    return ListView(controller: _scroll, children: [for (final p in feed.take(40)) _post(p)]);
  }

  static const _responseNames = {
    'explain_ok': '✍️ 해명 글 (먹혔다)',
    'explain_bad': '✍️ 해명 글 (역풍)',
    'sue': '⚖️ 악플러 고소',
    'pin': '📌 팬 댓글 고정',
    'ignore': '🤐 무대응',
  };

  // 내 계정으로 대응하기
  Widget _responseBar(Trend t) {
    final game = widget.game;
    if (_result != null && identical(_resultFor, t)) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF2F6FF), borderRadius: BorderRadius.circular(12)),
        child: Text(_result!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text, height: 1.4)),
      );
    }
    if (t.response != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('내 대응: ${_responseNames[t.response] ?? t.response}', style: const TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w700)),
      );
    }
    if (!game.canRespond(t)) return const SizedBox.shrink();
    Widget chip(String kind, String label, {bool enabled = true}) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: Material(
            color: enabled ? const Color(0xFFEFF3F4) : const Color(0xFFF7F9F9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: ValueKey('respond-$kind'),
              borderRadius: BorderRadius.circular(999),
              onTap: enabled
                  ? () {
                      final (summary, changes) = game.respond(t, kind);
                      setState(() {
                        _resultFor = t;
                        _result = [summary, for (final c in changes) '${c.label} ${c.text}'].join('\n');
                      });
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: enabled ? _text : _muted)),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 계정으로 대응하기 (한 번만)', style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(children: [
            chip('explain', '✍️ 해명 글'),
            chip('sue', game.s.money >= game.lawyerFee ? '⚖️ 고소 (${shortWon(game.lawyerFee)})' : '⚖️ 고소 (돈 부족)', enabled: game.s.money >= game.lawyerFee),
            chip('pin', '📌 팬 댓글 고정'),
            chip('ignore', '🤐 무대응'),
          ]),
        ],
      ),
    );
  }

  Widget _trendBody() {
    final list = widget.game.s.trends.reversed.toList();
    final t = _topic ?? (list.isEmpty ? null : list.first);
    if (t == null) return _empty('아직 트렌드에 오른 적이 없어요. 방송을 하다 보면 사람들이 당신 이야기를 시작할 거예요.');
    final total = t.shield + t.hate == 0 ? 1 : t.shield + t.hate;
    final sp = (t.shield / total * 100).round();
    final count = ((t.shield + t.hate + 3) * (10 + widget.game.s.followers * 0.02)).round();
    return ListView(
      controller: _scroll,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('실시간 트렌드 1위', style: TextStyle(fontSize: 12.5, color: _muted)),
              Text('#${t.tag}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
              Text('${shortNum(count)}개의 게시물', style: const TextStyle(fontSize: 12.5, color: _muted)),
              const SizedBox(height: 10),
              // 여론 막대: 쉴드 vs 비난
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 10,
                  color: Pal.hate,
                  alignment: Alignment.centerLeft,
                  // 대응하면 여론 막대가 움직인다
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: sp / 100),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(widthFactor: v.clamp(0.0, 1.0), child: Container(color: Pal.shield)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🛡️ 쉴드 $sp%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Pal.shield)),
                  Text('💢 비난 ${100 - sp}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Pal.hate)),
                ],
              ),
              _responseBar(t),
            ],
          ),
        ),
        for (final p in t.posts) _post(p),
        if (list.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('지난 트렌드', style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final x in list.where((x) => x != t))
                  InkWell(
                    onTap: () => _show(true, x),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${x.tag}', style: const TextStyle(fontWeight: FontWeight.w800, color: _text)),
                          Text('D${x.day} · ${x.headline}', style: const TextStyle(fontSize: 12.5, color: _muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _post(Post p, {bool reply = false}) {
    final avatar = reply ? 28.0 : 36.0;
    return Container(
      padding: reply ? const EdgeInsets.fromLTRB(8, 10, 0, 0) : const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.news ? const Color(0x0F1D9BF0) : null,
        border: reply ? null : const Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatar / 2,
            backgroundColor: Color(p.color),
            child: Text(p.nick.characters.first, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: reply ? 12 : 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: p.nick, style: const TextStyle(fontWeight: FontWeight.w800, color: _text)),
                    if (p.side == 'me') const TextSpan(text: ' ✔', style: TextStyle(fontWeight: FontWeight.w900, color: Pal.sns)),
                    if (p.g.isNotEmpty)
                      TextSpan(
                        text: p.g == 'm' ? ' ♂' : ' ♀',
                        style: TextStyle(fontWeight: FontWeight.w900, color: p.g == 'm' ? const Color(0xFF3B82F6) : const Color(0xFFEC4899)),
                      ),
                    TextSpan(text: ' @${p.handle} · D${p.day} ${slotNames[p.slot]}', style: const TextStyle(fontSize: 12, color: _muted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.replyTo != null) Text('↳ ${p.replyTo}님에게 답글', style: const TextStyle(fontSize: 12, color: _muted)),
                Padding(padding: const EdgeInsets.only(top: 2, bottom: 6), child: _tagged(p.text, reply)),
                DefaultTextStyle(
                  style: const TextStyle(fontSize: 12, color: _muted),
                  child: Wrap(spacing: 18, children: [
                    Text('💬 ${p.replies.length}'),
                    Text('🔁 ${shortNum(p.reposts)}'),
                    Text('♥ ${shortNum(p.likes)}'),
                  ]),
                ),
                if (p.replies.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.only(left: 4),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: _line, width: 2))),
                    child: Column(children: [for (final r in p.replies) _post(r, reply: true)]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // #태그는 파란색
  Widget _tagged(String text, bool reply) {
    final spans = <TextSpan>[];
    text.splitMapJoin(
      RegExp(r'#[^\s#]+'),
      onMatch: (m) {
        spans.add(TextSpan(text: m[0], style: const TextStyle(color: Pal.sns)));
        return '';
      },
      onNonMatch: (t) {
        spans.add(TextSpan(text: t));
        return '';
      },
    );
    return Text.rich(TextSpan(children: spans), style: TextStyle(fontSize: reply ? 14 : 15, height: 1.45, color: _text));
  }
}
