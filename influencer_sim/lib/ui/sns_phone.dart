import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import 'palette.dart';

/// 가상 SNS "버즈" 화면 (휴대폰 모양 팝업).
/// [trend]를 주면 트렌드 탭에서 그 주제를 먼저 보여 준다.
Future<void> showPhone(BuildContext context, GameController game, {bool trendTab = false, Trend? trend}) {
  game.markRead();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: const Color(0x990A0C18),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, _, _) => SafeArea(child: Center(child: _Phone(game: game, trendTab: trendTab, trend: trend))),
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
  const _Phone({required this.game, required this.trendTab, this.trend});
  final GameController game;
  final bool trendTab;
  final Trend? trend;

  @override
  State<_Phone> createState() => _PhoneState();
}

class _PhoneState extends State<_Phone> {
  late bool _trendTab = widget.trendTab;
  late Trend? _topic = widget.trend;
  final _scroll = ScrollController();

  static const _bg = Colors.white;
  static const _text = Color(0xFF0F1419);
  static const _muted = Color(0xFF536471);
  static const _line = Color(0xFFEFF3F4);

  void _show(bool trend, [Trend? topic]) {
    setState(() {
      _trendTab = trend;
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
              child: Row(children: [_tab('타임라인', !_trendTab, () => _show(false)), _tab('트렌드', _trendTab, () => _show(true))]),
            ),
            Expanded(child: _trendTab ? _trendBody() : _feedBody()),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? Pal.sns : Colors.transparent, width: 3))),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? _text : _muted)),
          ),
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.5)),
      );

  Widget _feedBody() {
    final feed = widget.game.s.feed;
    if (feed.isEmpty) return _empty('타임라인이 조용하네요. 첫 방송을 켜 보세요!');
    return ListView(controller: _scroll, children: [for (final p in feed.take(40)) _post(p)]);
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
                child: SizedBox(
                  height: 10,
                  child: Row(children: [
                    Expanded(flex: sp, child: Container(color: Pal.shield)),
                    Expanded(flex: 100 - sp, child: Container(color: Pal.hate)),
                  ]),
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
