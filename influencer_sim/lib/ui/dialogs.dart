import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/rules.dart';
import 'palette.dart';

class DialogButton {
  const DialogButton(this.label, {this.primary = false, this.choice = false});
  final String label;
  final bool primary;

  /// 선택지 버튼 (왼쪽 정렬, 화살표)
  final bool choice;
}

/// 가운데 팝업. 아이콘 + 제목 + 내용 + 버튼. 누른 버튼의 번호를 돌려준다. (뒤로 가기로 닫을 수 없음)
Future<int> ask(BuildContext context, String title, List<Widget> body, List<DialogButton> buttons, {String? icon}) async {
  final r = await showGeneralDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB3060814),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => PopScope(
      canPop: false,
      child: GameCard(
        icon: icon,
        title: title,
        children: [
          ...body,
          const SizedBox(height: 16),
          for (var i = 0; i < buttons.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _button(buttons[i], () => Navigator.pop(ctx, i), ValueKey('dlg-$i')),
            ),
        ],
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final t = Curves.easeOutBack.transform(anim.value);
      return Opacity(opacity: anim.value, child: Transform.scale(scale: 0.88 + 0.12 * t, child: child));
    },
  );
  return r ?? 0;
}

Widget _button(DialogButton b, VoidCallback onTap, Key key) {
  if (b.primary) return GradientButton(key: key, label: b.label, onTap: onTap);
  return GhostButton(key: key, label: b.label, onTap: onTap, alignLeft: b.choice);
}

/// 팝업 카드 틀 (위에 동그란 아이콘)
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.title, required this.children, this.icon});
  final String title;
  final String? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: icon != null ? 30 : 0),
                    decoration: BoxDecoration(
                      color: Pal.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Pal.stroke),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 16))],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, icon != null ? 42 : 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, textAlign: icon != null ? TextAlign.center : TextAlign.start, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pal.text)),
                          const SizedBox(height: 12),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                  if (icon != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: Pal.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Pal.surface, width: 4),
                            boxShadow: [BoxShadow(color: Pal.pink.withValues(alpha: 0.5), blurRadius: 18)],
                          ),
                          child: Text(icon!, style: const TextStyle(fontSize: 26)),
                        ),
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
}

Widget eventText(String text) => Text(text, style: const TextStyle(fontSize: 15.5, height: 1.65, color: Pal.text));

Widget mutedText(String text, {double size = 13.5}) => Text(text, style: TextStyle(fontSize: size, color: Pal.muted, height: 1.5));

/// 수치 변화 칩 (+1,234 구독자, 이미지 -5 …)
Widget changeChips(List<Change> changes) {
  if (changes.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in changes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (c.good == null ? Pal.muted : (c.good! ? Pal.good : Pal.bad)).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${c.label} ', style: const TextStyle(color: Pal.muted, fontWeight: FontWeight.w600)),
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
    childAspectRatio: 2.3,
    children: [
      for (final (label, value) in cells)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Pal.text))),
            ],
          ),
        ),
    ],
  );
}

// ───── 아래에서 올라오는 시트 ─────
Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Pal.surface,
    barrierColor: const Color(0x99060814),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    builder: (ctx) => SafeArea(child: builder(ctx)),
  );
}

/// 시트 머리 (손잡이, 제목, 닫기)
Widget sheetHeader(BuildContext ctx, String title, {String? sub}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Pal.stroke, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Pal.text)),
                    if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: mutedText(sub, size: 13)),
                  ],
                ),
              ),
              Pressable(
                key: const ValueKey('sheet-close'),
                onTap: () => Navigator.pop(ctx),
                radius: 999,
                color: Pal.surface2,
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close_rounded, color: Pal.muted, size: 20),
              ),
            ],
          ),
        ],
      ),
    );

// ───── 콘텐츠 고르기 ─────
Future<Content?> chooseContent(BuildContext context, GameController game) {
  final s = game.s;
  return showSheet<Content>(
    context,
    (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sheetHeader(ctx, '오늘은 어떤 방송?', sub: '${slotNames[s.slot]} · ${s.slot == 2 ? '밤 방송은 시청자가 가장 많아요' : (s.slot == 0 ? '오전 방송은 시청자가 적어요' : '오후 방송은 무난해요')}'),
        Flexible(
          child: GridView.count(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [for (final c in contents) _contentCard(ctx, game, c)],
          ),
        ),
      ],
    ),
  );
}

Widget _contentCard(BuildContext ctx, GameController game, Content c) {
  final s = game.s;
  final lack = game.contentBlock(c);
  final hot = s.trend == c.id;
  final lv = s.skills[c.id] ?? 0;
  return Pressable(
    key: ValueKey('content-${c.id}'),
    onTap: lack == null ? () => Navigator.pop(ctx, c) : null,
    radius: 20,
    color: Pal.surface2,
    border: Border.all(color: hot ? Pal.pink : Pal.stroke, width: hot ? 1.5 : 1),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(c.icon, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            if (game.isScheduled(c)) _tag('📅 예고', Pal.good) else if (hot) _tag('🔥 대세', Pal.pink) else if (s.lastContent == c.id) _tag('연속', Pal.muted),
          ],
        ),
        const Spacer(),
        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Pal.text)),
        const SizedBox(height: 2),
        Text(lack ?? c.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: lack != null ? Pal.bad : Pal.muted, height: 1.35)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tag('⚡${game.energyCost(c)}', Pal.energy),
              const SizedBox(width: 4),
              if (c.cost > 0) ...[_tag(shortWon(c.cost), Pal.gold), const SizedBox(width: 4)],
              _tag('Lv.$lv', Pal.trueEnd),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );

// ───── 상점 ─────
const wallColors = [0xE9DCCB, 0xDFE8F0, 0xF3DDE2, 0xE2EFDC, 0xECE4F5];

Future<void> openShop(BuildContext context, GameController game) => showSheet<void>(context, (ctx) => _ShopSheet(game: game));

class _ShopSheet extends StatefulWidget {
  const _ShopSheet({required this.game});
  final GameController game;

  @override
  State<_ShopSheet> createState() => _ShopSheetState();
}

class _ShopSheetState extends State<_ShopSheet> {
  /// 0 장비, 1 꾸미기, 2 이사, 3 직원, 4 사업
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final s = game.s;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sheetHeader(context, '🛒 상점', sub: '💰 통장 ${s.money < 0 ? '-' : ''}${won(s.money)}'),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _segment()),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _tab == 0
                    ? [for (final g in gearTypes) _gearRow(game, g)]
                    : _tab == 2
                        ? [for (final h in houses) _houseRow(game, h)]
                        : _tab == 3
                        ? [for (final st in staffList) _staffRow(game, st)]
                        : _tab == 4
                        ? [for (final b in businesses) _businessRow(game, b)]
                        : [
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
                                      shape: BoxShape.circle,
                                      border: Border.all(color: s.wallColor == w ? Pal.pink : Pal.stroke, width: s.wallColor == w ? 3 : 1),
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
        );
      },
    );
  }

  Widget _segment() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          _segBtn('장비', 0),
          _segBtn('꾸미기', 1),
          _segBtn('이사', 2),
          if (widget.game.unlocked('staff')) _segBtn('직원', 3),
          if (widget.game.unlocked('business')) _segBtn('사업', 4),
        ]),
      );

  Widget _segBtn(String label, int tab) {
    final active = _tab == tab;
    return Expanded(
        child: GestureDetector(
          key: ValueKey('shop-tab-$tab'),
          onTap: () => setState(() => _tab = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: active ? Pal.brand : null, borderRadius: BorderRadius.circular(999)),
            child: Text(label, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? Colors.white : Pal.muted)),
          ),
        ),
      );
  }

  Widget _staffRow(GameController game, Staff st) {
    final hired = game.hasStaff(st.id);
    final why = game.hireBlock(st);
    return _row(
      st.icon,
      st.name,
      '${st.desc}\n일당 ${shortWon(st.wage)} (매일 밤)',
      hired
          ? _buy('해고', () => game.dismiss(st), ValueKey('fire-${st.id}'))
          : why != null && why != '돈 부족'
              ? Text(why, textAlign: TextAlign.right, style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700))
              : _buy('고용', why == null ? () => game.hire(st) : null, ValueKey('hire-${st.id}')),
    );
  }

  Widget _businessRow(GameController game, Business b) {
    final owned = game.s.business.contains(b.id);
    final why = game.businessBlock(b);
    final income = game.businessIncome(b);
    return _row(
      b.icon,
      b.name,
      '${b.desc}\n${owned ? '오늘 밤 수익' : '창업비 ${shortWon(b.cost)} · 지금 열면 하루'} 약 ${shortWon(income)}',
      owned
          ? const Text('운영 중', style: TextStyle(color: Pal.good, fontWeight: FontWeight.w800))
          : why != null && why != '돈 부족'
              ? Text(why, textAlign: TextAlign.right, style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700))
              : _buy('창업', why == null ? () => game.openBusiness(b) : null, ValueKey('open-${b.id}')),
    );
  }

  Widget _houseRow(GameController game, House h) {
    final here = game.s.house == h.id;
    final why = game.moveBlock(h);
    final sub = '${h.desc}\n하루 생활비 ${shortWon(h.rent)}${h.deposit > 0 ? ' · 보증금 ${shortWon(h.deposit)}' : ''}';
    return _row(
      h.icon,
      h.name,
      sub,
      here
          ? const Text('거주 중', style: TextStyle(color: Pal.good, fontWeight: FontWeight.w800))
          : why == '이미 지나온 집'
              ? const Text('지나옴', style: _owned)
              : why != null && why != '돈 부족'
                  ? Text(why, textAlign: TextAlign.right, style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700))
                  : _buy('이사', why == null ? () => game.moveHouse(h) : null, ValueKey('move-${h.id}')),
    );
  }

  Widget _row(String icon, String title, String sub, Widget trailing, {Widget? extra}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 12, color: Pal.muted)),
                  ?extra,
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      );

  Widget _buy(String label, VoidCallback? onTap, Key key) => Pressable(
        key: key,
        onTap: onTap,
        gradient: onTap != null ? Pal.brand : null,
        color: Pal.bg,
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5)),
      );

  static const _owned = TextStyle(color: Pal.muted, fontWeight: FontWeight.w800);

  Widget _levelDots(int lv, int max) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            for (var i = 1; i <= max; i++)
              Container(
                width: 18,
                height: 4,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(gradient: i <= lv ? Pal.brand : null, color: i <= lv ? null : Pal.bg, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      );

  Widget _gearRow(GameController game, GearType g) {
    final lv = game.s.gear[g.key]!;
    final cur = g.tiers[lv];
    final next = lv + 1 < g.tiers.length ? g.tiers[lv + 1] : null;
    return _row(
      g.icon,
      '${g.label} · ${cur.name}',
      next != null ? '다음: ${next.name}' : '최고 단계',
      next != null ? _buy(shortWon(next.price), game.s.money >= next.price ? () => game.buyGear(g.key) : null, ValueKey('buy-${g.key}')) : const Text('MAX', style: _owned),
      extra: _levelDots(lv, g.tiers.length - 1),
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
      mutedText('가진 건 스마트폰 한 대와 반지하 방 한 칸뿐. 방송으로 돈을 벌어 장비를 맞추고, 스트리머 순위 1위를 향해 가 보세요.', size: 14.5),
      const SizedBox(height: 12),
      for (final (icon, t) in const [
        ('🌙', '하루는 오전·오후·밤 세 번 행동할 수 있어요. 밤 방송이 시청자가 가장 많아요.'),
        ('🏪', '돈이 없으면 편의점 알바! 장비를 사면 화질과 음질이 좋아져요.'),
        ('📱', "모든 행동은 SNS '버즈'에서 토론거리가 돼요. 오른쪽 위 폰을 눌러 반응을 확인하세요."),
        ('🔓', '구독자가 늘수록 새로운 기능이 하나씩 열려요. 기간 제한은 없으니 천천히 키워 보세요.'),
        ('⚠️', '논란이 100이 되거나 멘탈이 0이 되면 게임 오버예요.'),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13.5, height: 1.5, color: Pal.text))),
            ],
          ),
        ),
    ];

/// 랭크 이름 (HUD)
String rankName(int followers) => rankOf(followers).name;
