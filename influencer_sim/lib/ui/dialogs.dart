import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/rules.dart';
import 'palette.dart';

class DialogButton {
  const DialogButton(this.label, {this.primary = false, this.choice = false});
  final String label;
  final bool primary;

  /// 선택지 버튼 (왼쪽 정렬, 테두리)
  final bool choice;
}

/// 제목 + 내용 + 버튼 목록. 누른 버튼의 번호를 돌려준다. (뒤로 가기로 닫을 수 없음)
Future<int> ask(BuildContext context, String title, List<Widget> body, List<DialogButton> buttons) async {
  final r = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Sheet(
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Pal.text)),
          const SizedBox(height: 10),
          ...body,
          const SizedBox(height: 14),
          for (var i = 0; i < buttons.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _button(buttons[i], () => Navigator.pop(ctx, i)),
            ),
        ],
      ),
    ),
  );
  return r ?? 0;
}

Widget _button(DialogButton b, VoidCallback onTap) {
  if (b.choice) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Pal.text,
        side: const BorderSide(color: Pal.border),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
      child: Text(b.label),
    );
  }
  return SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: b.primary ? Pal.accent : Pal.surface,
        foregroundColor: b.primary ? Pal.accentText : Pal.text,
        side: b.primary ? null : const BorderSide(color: Pal.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
      child: Text(b.label),
    ),
  );
}

/// 흰 카드 모양 팝업 틀
class Sheet extends StatelessWidget {
  const Sheet({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Pal.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Pal.border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

Widget eventText(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 15.5, height: 1.6, color: Pal.text)),
    );

Widget mutedText(String text, {double size = 13.5}) => Text(text, style: TextStyle(fontSize: size, color: Pal.muted, height: 1.5));

/// 수치 변화 칩 (+1,234 구독자, 이미지 -5 …)
Widget changeChips(List<Change> changes) {
  if (changes.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in changes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(999)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${c.label} ', style: const TextStyle(color: Pal.text)),
              TextSpan(
                text: c.text,
                style: TextStyle(fontWeight: FontWeight.w800, color: c.good == null ? Pal.text : (c.good! ? Pal.good : Pal.bad)),
              ),
            ])),
          ),
      ],
    ),
  );
}

/// 결과 칸 (2열)
Widget resultGrid(List<(String, String)> cells) {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 2.5,
    children: [
      for (final (label, value) in cells)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted)),
              FittedBox(child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Pal.text))),
            ],
          ),
        ),
    ],
  );
}

// ───── 콘텐츠 고르기 ─────
Future<Content?> chooseContent(BuildContext context, GameController game) {
  final s = game.s;
  return showDialog<Content>(
    context: context,
    builder: (ctx) => Sheet(
      children: [
        Text('📡 ${slotNames[s.slot]} 방송', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Pal.text)),
        const SizedBox(height: 4),
        mutedText(s.slot == 2 ? '밤 방송은 시청자가 가장 많아요.' : (s.slot == 0 ? '오전 방송은 시청자가 적어요.' : '오후 방송은 무난해요.')),
        const SizedBox(height: 10),
        for (final c in contents) _contentCard(ctx, game, c),
        const SizedBox(height: 8),
        _button(const DialogButton('취소'), () => Navigator.pop(ctx)),
      ],
    ),
  );
}

Widget _contentCard(BuildContext ctx, GameController game, Content c) {
  final s = game.s;
  final lack = game.contentBlock(c);
  final hot = s.trend == c.id;
  final lv = s.skills[c.id] ?? 0;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Opacity(
      opacity: lack == null ? 1 : 0.45,
      child: Material(
        color: hot ? const Color(0xFFFEF6EA) : Pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: hot ? const Color(0xFFF59E0B) : Pal.border)),
        child: InkWell(
          key: ValueKey('content-${c.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: lack == null ? () => Navigator.pop(ctx, c) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(c.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c.name}${hot ? ' 🔥' : ''}${s.lastContent == c.id ? ' · 연속' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text)),
                      Text(lack ?? c.desc, style: const TextStyle(fontSize: 12.5, color: Pal.muted, height: 1.4)),
                      Text('체력 ${c.energy}${c.cost > 0 ? ' · 비용 ${shortWon(c.cost)}' : ''} · 숙련 Lv.$lv', style: const TextStyle(fontSize: 11.5, color: Pal.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ───── 상점 ─────
const wallColors = [0xE9DCCB, 0xDFE8F0, 0xF3DDE2, 0xE2EFDC, 0xECE4F5];

Future<void> openShop(BuildContext context, GameController game) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ShopSheet(game: game),
  );
}

class _ShopSheet extends StatefulWidget {
  const _ShopSheet({required this.game});
  final GameController game;

  @override
  State<_ShopSheet> createState() => _ShopSheetState();
}

class _ShopSheetState extends State<_ShopSheet> {
  bool _deco = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.s;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Sheet(
        children: [
          const Text('🛒 장비 쇼핑', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Pal.text)),
          const SizedBox(height: 4),
          mutedText('통장 잔고 ${won(s.money)}'),
          const SizedBox(height: 10),
          Row(
            children: [
              _tab('장비', !_deco, () => setState(() => _deco = false)),
              const SizedBox(width: 6),
              _tab('방 꾸미기', _deco, () => setState(() => _deco = true)),
            ],
          ),
          const SizedBox(height: 6),
          if (!_deco)
            for (final g in gearTypes) _gearRow(game, g)
          else ...[
            for (final d in decos) _decoRow(game, d),
            _row(
              '🎨',
              '벽지 색 바꾸기',
              '무료',
              Wrap(
                spacing: 6,
                children: [
                  for (final w in wallColors)
                    GestureDetector(
                      onTap: () => game.setWall(w),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Color(0xFF000000 | w),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: s.wallColor == w ? Pal.text : Pal.border, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _button(const DialogButton('닫기'), () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Pal.accent : Pal.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? Pal.accent : Pal.border),
            ),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? Pal.accentText : Pal.text)),
          ),
        ),
      );

  Widget _row(String icon, String title, String sub, Widget trailing) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Pal.border))),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text)),
                  Text(sub, style: const TextStyle(fontSize: 12.5, color: Pal.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      );

  Widget _buy(String label, VoidCallback? onTap, Key key) => FilledButton(
        key: key,
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Pal.accent,
          foregroundColor: Pal.accentText,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  static const _owned = TextStyle(color: Pal.muted, fontWeight: FontWeight.w800);

  Widget _gearRow(GameController game, GearType g) {
    final lv = game.s.gear[g.key]!;
    final cur = g.tiers[lv];
    final next = lv + 1 < g.tiers.length ? g.tiers[lv + 1] : null;
    return _row(
      g.icon,
      '${g.label} · Lv.$lv',
      next != null ? '${cur.name} → ${next.name}' : '${cur.name} (최고 단계)',
      next != null
          ? _buy(shortWon(next.price), game.s.money >= next.price ? () => game.buyGear(g.key) : null, ValueKey('buy-${g.key}'))
          : const Text('MAX', style: _owned),
    );
  }

  Widget _decoRow(GameController game, Deco d) {
    final owned = game.s.deco.contains(d.id);
    return _row(
      '🪴',
      d.name,
      '방 매력도 +1 (시청자 +3%)',
      owned ? const Text('보유', style: _owned) : _buy(shortWon(d.price), game.s.money >= d.price ? () => game.buyDeco(d) : null, ValueKey('buy-${d.id}')),
    );
  }
}

/// 게임 시작 안내
List<Widget> introBody() => [
      eventText('가진 건 스마트폰 한 대와 작은 원룸뿐. 방송으로 돈을 벌어 장비를 하나씩 맞춰 가세요.'),
      const SizedBox(height: 8),
      for (final t in const [
        '하루는 오전·오후·밤 세 번 행동할 수 있어요. 밤 방송이 시청자가 가장 많아요.',
        '돈이 없으면 편의점 알바! 장비를 사면 화질과 음질이 좋아져요.',
        "당신의 모든 행동은 SNS '버즈'에서 토론거리가 돼요. 📱를 눌러 반응을 확인하세요.",
        '논란이 100이 되거나 멘탈이 0이 되면 게임 오버예요.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(color: Pal.text)),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 14, height: 1.5, color: Pal.text))),
            ],
          ),
        ),
    ];

/// 랭크 이름 (HUD)
String rankName(int followers) => rankOf(followers).name;
