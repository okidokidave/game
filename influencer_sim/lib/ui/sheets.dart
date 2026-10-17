import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import '../game/rules.dart';
import '../scene/room_painter.dart';
import 'dialogs.dart';
import 'palette.dart';

// 오늘의 미션, 방송 예고, 기록(그래프), 업적 도감 시트

// ───── 오늘의 미션 ─────
Future<void> openMissions(BuildContext context, GameController game) => showSheet<void>(
  context,
  (ctx) => ListenableBuilder(
    listenable: game,
    builder: (ctx, _) {
      final s = game.s;
      final done = s.missions.where((m) => m.done).length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sheetHeader(ctx, '🎯 오늘의 미션', sub: '$done / ${s.missions.length} 완료 · 매일 아침 새 미션'),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [for (final m in s.missions) _missionRow(game, m), const SizedBox(height: 4), mutedText('미션을 끝내면 보상과 함께 찐팬이 늘어요. 지금까지 완료한 미션 ${s.missionsDone}개', size: 12.5)],
            ),
          ),
        ],
      );
    },
  ),
);

Widget _missionRow(GameController game, Mission m) {
  final v = m.goal == 0 ? 1.0 : m.progress / m.goal;
  final count = m.kind == 'donation' ? '${shortWon(m.progress)} / ${shortWon(m.goal)}' : '${shortNum(m.progress)} / ${shortNum(m.goal)}';
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Pal.surface2,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: m.done ? Pal.good : Pal.stroke),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                game.missionText(m),
                style: TextStyle(fontWeight: FontWeight.w800, color: m.done ? Pal.good : Pal.text),
              ),
            ),
            Text(
              m.done ? '✅ 완료' : '🎁 ${shortWon(m.reward)}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: m.done ? Pal.good : Pal.gold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: v.clamp(0.0, 1.0), minHeight: 6, backgroundColor: Pal.bg, color: m.done ? Pal.good : Pal.pink),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              count,
              style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

// ───── 방송 예고 ─────
Future<void> openSchedule(BuildContext context, GameController game) => showSheet<void>(context, (ctx) => _ScheduleSheet(game: game));

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.game});
  final GameController game;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final slots = widget.game.scheduleSlots();
  late (int, int) _slot = slots.firstWhere((x) => x.$2 == 2, orElse: () => slots.first);
  String? _content;

  String _when((int, int) x) => '${x.$1 == widget.game.s.day ? '오늘' : '내일'} ${slotNames[x.$2]}';

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.s;
    final open = contents.where((c) => game.contentBlock(c) == null || game.contentBlock(c)!.startsWith('체력') || game.contentBlock(c) == '돈 부족').toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sheetHeader(context, '📅 방송 예고', sub: '예고를 지키면 시청자 +25%·찐팬 증가, 어기면 찐팬이 실망해요'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (s.schedDay != 0 && s.schedContent != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Pal.surface2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Pal.pink),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '지금 예고: ${_when((s.schedDay, s.schedSlot))} ${contentOf(s.schedContent!).icon} ${contentOf(s.schedContent!).name}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('schedule-cancel'),
                        onPressed: () {
                          game.cancelSchedule();
                          Navigator.pop(context);
                        },
                        child: const Text('취소', style: TextStyle(color: Pal.muted)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                '언제?',
                style: TextStyle(color: Pal.muted, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final x in slots) ChoiceChip(key: ValueKey('sched-slot-${x.$1}-${x.$2}'), label: Text(_when(x)), selected: _slot == x, onSelected: (_) => setState(() => _slot = x))],
              ),
              const SizedBox(height: 14),
              const Text(
                '무슨 방송?',
                style: TextStyle(color: Pal.muted, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in open)
                    ChoiceChip(key: ValueKey('sched-content-${c.id}'), label: Text('${c.icon} ${c.name}'), selected: _content == c.id, onSelected: (_) => setState(() => _content = c.id)),
                ],
              ),
              const SizedBox(height: 18),
              GradientButton(
                key: const ValueKey('schedule-confirm'),
                label: '📢 예고 올리기',
                onTap: _content == null
                    ? null
                    : () {
                        game.setSchedule(_slot.$1, _slot.$2, _content!);
                        Navigator.pop(context);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───── 기록 (그래프) ─────
Future<void> openStats(BuildContext context, GameController game) => showSheet<void>(context, (ctx) => _StatsSheet(game: game));

class _StatsSheet extends StatefulWidget {
  const _StatsSheet({required this.game});
  final GameController game;

  @override
  State<_StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends State<_StatsSheet> {
  /// 0 구독자, 1 통장, 2 시청자, 3 찐팬
  int _kind = 0;

  static const _kinds = [('👥 구독자', Pal.pink), ('💰 통장', Pal.gold), ('📺 시청자', Pal.sns), ('💖 찐팬', Pal.good)];

  int _value(DayStat d) => switch (_kind) {
    0 => d.followers,
    1 => d.money,
    2 => d.peak,
    _ => d.core,
  };

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.s;
    // 오늘까지 포함한 기록
    final points = [...s.history, DayStat(s.day, s.followers, s.money, s.todayPeak, s.coreFans)];
    final values = [for (final d in points) _value(d)];
    final color = _kinds[_kind].$2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sheetHeader(context, '📊 방송 기록', sub: 'DAY ${points.first.day} ~ ${points.last.day}'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _kinds.length; i++) ChoiceChip(key: ValueKey('stats-kind-$i'), label: Text(_kinds[i].$1), selected: _kind == i, onSelected: (_) => setState(() => _kind = i)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 190,
                padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
                decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18)),
                child: CustomPaint(
                  painter: _LineChart(values, color, money: _kind == 1),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 14),
              resultGrid([
                ('총 방송', '${s.streams}회'),
                ('총 수입', shortWon(s.earned)),
                ('최고 시청자', '${shortNum(s.peak)}명'),
                ('찐팬', '${shortNum(s.coreFans)}명 (${(game.loyalty * 100).toStringAsFixed(1)}%)'),
              ]),
              const SizedBox(height: 14),
              const Text(
                '🏅 기억에 남는 방송',
                style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (s.best.isEmpty) mutedText('아직 방송 기록이 없어요.'),
              for (final (i, b) in s.best.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Text(const ['🥇', '🥈', '🥉'][i], style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'D${b.day} ${contentOf(b.content).icon} ${contentOf(b.content).name}',
                          style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${shortNum(b.viewers)}명',
                        style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChart extends CustomPainter {
  _LineChart(this.values, this.color, {this.money = false});
  final List<int> values;
  final Color color;
  final bool money;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    final w = size.width - left, h = size.height - 16;
    final hi = values.fold<int>(1, max);
    final lo = min(0, values.fold<int>(0, min));
    final span = (hi - lo).toDouble();
    double y(int v) => h - (v - lo) / span * h;
    final grid = Paint()..color = Pal.stroke;
    final label = TextStyle(color: Pal.muted, fontSize: 10, fontFamily: 'Pretendard');
    for (var i = 0; i <= 2; i++) {
      final v = lo + (span * i / 2).round();
      final yy = y(v);
      canvas.drawLine(Offset(left, yy), Offset(size.width, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: money ? shortWon(v) : shortNum(v), style: label),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      tp.paint(canvas, Offset(left - 4 - tp.width, yy - tp.height / 2));
    }
    if (values.isEmpty) return;
    final n = values.length;
    Offset at(int i) => Offset(left + (n == 1 ? w / 2 : w * i / (n - 1)), y(values[i]));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(n - 1).dx, h)
      ..lineTo(at(0).dx, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(n - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LineChart old) => old.values != values || old.color != color;
}

// ───── 업적 도감 · 다회차 혜택 ─────
Future<void> openAchievements(BuildContext context, GameController game) => showSheet<void>(context, (ctx) {
  final got = game.achieved;
  final endings = game.endingsSeen.length;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      sheetHeader(ctx, '🏅 업적 도감', sub: '업적 ${got.length} / ${achievements.length} · 엔딩 $endings / ${endingsCount()}'),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              '🎁 다회차 혜택 (새 게임에 적용)',
              style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final p in perks)
              Builder(
                builder: (_) {
                  final on = p.unlocked(endings, got.length);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(on ? p.icon : '🔒', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.text,
                            style: TextStyle(color: on ? Pal.text : Pal.muted, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          on ? '적용 중' : p.need,
                          style: TextStyle(color: on ? Pal.good : Pal.muted, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                for (final a in achievements)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Pal.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: got.contains(a.id) ? Pal.gold : Pal.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          got.contains(a.id) ? '${a.icon} ${a.title}' : '🔒 ${a.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: got.contains(a.id) ? Pal.text : Pal.muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          a.desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Pal.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
});

int endingsCount() => endings.length;

// ───── 내 채널 (캐릭터 크게 보기 · 은퇴) ─────
/// 은퇴하기를 누르면 true
Future<bool?> openProfile(BuildContext context, GameController game) => showSheet<bool>(context, (ctx) => _ProfileSheet(game: game));

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.game});
  final GameController game;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => setState(() => _tick++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.s;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sheetHeader(context, '📺 내 채널', sub: 'DAY ${s.day} · ${rankOf(s.followers).name}'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: Pal.brandSoft,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Pal.stroke),
                ),
                child: CustomPaint(painter: PortraitPainter(s.look, _tick), size: Size.infinite),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  s.name,
                  style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              resultGrid([
                ('구독자', shortNum(s.followers)),
                ('찐팬', shortNum(s.coreFans)),
                ('인기 순위', '${game.myRank}위'),
                ('총 수입', shortWon(s.earned)),
                ('방송 횟수', '${s.streams}회'),
                ('이미지', imageText(s.image)),
              ]),
              const SizedBox(height: 16),
              GradientButton(
                key: const ValueKey('beauty-button'),
                icon: '👗',
                label: '뷰티샵 · 펫샵',
                sub: '헤어 · 옷 · 소품 · 반려동물',
                onTap: () {
                  game.seen('beauty');
                  openBeauty(context, game);
                },
              ),
              const SizedBox(height: 10),
              GhostButton(key: const ValueKey('retire'), label: '🏳️ 은퇴하고 엔딩 보기', onTap: () => Navigator.pop(context, true)),
            ],
          ),
        ),
      ],
    );
  }
}

// ───── 뷰티샵 · 펫샵 ─────
Future<void> openBeauty(BuildContext context, GameController game) => showSheet<void>(context, (ctx) => _BeautySheet(game: game));

class _BeautySheet extends StatefulWidget {
  const _BeautySheet({required this.game});
  final GameController game;

  @override
  State<_BeautySheet> createState() => _BeautySheetState();
}

class _BeautySheetState extends State<_BeautySheet> {
  static const _tabs = [('hair', '💇 헤어'), ('dye', '🎨 염색'), ('outfit', '👕 옷'), ('acc', '👓 소품'), ('pet', '🐾 펫')];
  String _tab = 'hair';

  /// 입어 보는 중인 아이템 / 보고 있는 펫
  StyleItem? _try;
  Pet? _pet;
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) => setState(() => _tick++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final s = game.s;
        final look = _try == null ? s.look : tryOn(s.look, _try!);
        final pet = _pet ?? (s.pet == null ? null : petOf(s.pet!));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sheetHeader(context, '👗 뷰티샵', sub: '💰 통장 ${s.money < 0 ? '-' : ''}${won(s.money)} · 눌러서 미리 입어 보기'),
            Container(
              height: 170,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: BoxDecoration(
                gradient: Pal.brandSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Pal.stroke),
              ),
              child: _tab == 'pet'
                  ? (pet == null ? Center(child: mutedText('반려동물을 눌러 보세요')) : CustomPaint(painter: PetPainter(pet, _tick), size: Size.infinite))
                  : CustomPaint(painter: PortraitPainter(look, _tick), size: Size.infinite),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (id, label) in _tabs)
                    ChoiceChip(
                        key: ValueKey('beauty-tab-$id'),
                        label: Text(label),
                        selected: _tab == id,
                        onSelected: (_) => setState(() {
                          _tab = id;
                          _try = null;
                          _pet = null;
                        }),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _tab == 'pet' ? [for (final p in pets) _petRow(game, p)] : [for (final it in styleItems.where((x) => x.kind == _tab)) _styleRow(game, it)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row({required Key key, required bool selected, required VoidCallback onTap, required Widget lead, required String title, required String sub, required Widget trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Pressable(
      key: key,
      onTap: onTap,
      radius: 18,
      color: Pal.surface2,
      border: Border.all(color: selected ? Pal.pink : Pal.stroke),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Pal.text),
                ),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: Pal.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    ),
  );

  Widget _btn(String label, VoidCallback? onTap, Key key, {bool primary = true}) => Pressable(
    key: key,
    onTap: onTap,
    gradient: onTap != null && primary ? Pal.brand : null,
    color: onTap == null || !primary ? Pal.bg : null,
    radius: 999,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Text(
      label,
      style: TextStyle(color: onTap != null ? Colors.white : Pal.muted, fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );

  Widget _styleRow(GameController game, StyleItem it) {
    final s = game.s;
    final owned = game.owns(it);
    final on = wearing(s.look, it);
    final lead = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: it.kind == 'dye' ? Color(0xFF000000 | it.color) : (it.kind == 'outfit' ? Color(0xFF000000 | (it.color == 0 ? s.look.shirt : it.color)) : Pal.bg),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.stroke),
      ),
      alignment: Alignment.center,
      child: Text(switch (it.kind) {
        'hair' => '💇',
        'acc' => it.value == 'none' ? '✖️' : '👓',
        _ => '',
      }, style: const TextStyle(fontSize: 18)),
    );
    final perks = [if (it.desc.isNotEmpty) it.desc, if (it.bonus > 0) '시청자 +${(it.bonus * 100).round()}%'].join(' · ');
    return _row(
      key: ValueKey('style-${it.id}'),
      selected: _try == it,
      onTap: () => setState(() => _try = it),
      lead: lead,
      title: it.name,
      sub: perks,
      trailing: on
          ? const Text(
              '착용 중',
              style: TextStyle(color: Pal.good, fontWeight: FontWeight.w800),
            )
          : owned
          ? _btn(
              '착용',
              () {
                game.wear(it);
                setState(() => _try = null);
              },
              ValueKey('wear-${it.id}'),
              primary: false,
            )
          : _btn(
              shortWon(it.price),
              s.money >= it.price
                  ? () {
                      game.buyStyle(it);
                      setState(() => _try = null);
                    }
                  : null,
              ValueKey('buy-${it.id}'),
            ),
    );
  }

  Widget _petRow(GameController game, Pet p) {
    final why = game.petBlock(p);
    return _row(
      key: ValueKey('pet-${p.id}'),
      selected: _pet == p,
      onTap: () => setState(() => _pet = p),
      lead: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(12)),
        child: Text(p.icon, style: const TextStyle(fontSize: 22)),
      ),
      title: p.name,
      sub: '${p.desc}\n하루 사료·간식 ${shortWon(p.food)} · 🐾 펫 방송이 열린다',
      trailing: why == '함께 사는 중'
          ? const Text(
              '함께 사는 중',
              style: TextStyle(color: Pal.good, fontWeight: FontWeight.w800, fontSize: 12),
            )
          : why != null && why != '돈 부족'
          ? Text(
              why,
              style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700),
            )
          : _btn('분양 ${shortWon(p.price)}', why == null ? () => game.adoptPet(p) : null, ValueKey('adopt-${p.id}')),
    );
  }
}

// ───── 은퇴 · 엔딩 뒤 발자취 ─────
/// 이번 판의 발자취 (모든 기록)와 지난 회차 비교
Future<void> openCareer(BuildContext context, GameController game) => showSheet<void>(context, (ctx) {
  final s = game.s;
  final runs = game.runs;
  final e = endings[s.ended] ?? endings['zero']!;
  // 구독자 1천·1만·10만·100만을 넘긴 날
  int? dayOf(int n) => s.history.where((d) => d.followers >= n).map((d) => d.day).firstOrNull ?? (s.followers >= n ? s.day : null);
  final marks = [
    for (final n in const [1000, 10000, 100000, 1000000]) (n, dayOf(n)),
  ].where((m) => m.$2 != null).toList();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      sheetHeader(ctx, '📜 ${s.name}의 발자취', sub: '${e.title} · ${s.day}일 동안의 방송'),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Container(
              height: 170,
              padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
              decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18)),
              child: CustomPaint(painter: _LineChart([for (final d in s.history) d.followers, s.followers], Pal.pink), size: Size.infinite),
            ),
            const SizedBox(height: 4),
            Center(child: mutedText('구독자 변화', size: 12)),
            const SizedBox(height: 12),
            resultGrid([
              ('구독자', shortNum(s.followers)),
              ('찐팬', shortNum(s.coreFans)),
              ('최고 시청자', '${shortNum(s.peak)}명'),
              ('최종 순위', '${game.myRank}위'),
              ('총 수입', shortWon(s.earned)),
              ('방송 · 업로드', '${s.streams}회 · ${s.uploads}개'),
              ('살던 집', houseOf(s.house).name),
              ('사업 · 직원', '${s.business.length}개 · ${s.staff.length}명'),
              ('이미지', imageText(s.image)),
              ('업적', '${game.achieved.length}개'),
            ]),
            if (marks.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '🏁 성장 기록',
                style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final (n, d) in marks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('DAY $d · 구독자 ${shortNum(n)} 돌파', style: const TextStyle(color: Pal.text, fontSize: 13.5)),
                ),
            ],
            if (s.best.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '🏅 기억에 남는 방송',
                style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final b in s.best)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('D${b.day} ${contentOf(b.content).icon} ${contentOf(b.content).name} · ${shortNum(b.viewers)}명', style: const TextStyle(color: Pal.text, fontSize: 13.5)),
                ),
            ],
            const SizedBox(height: 16),
            runsTable(runs, highlight: game.lastRun),
          ],
        ),
      ),
    ],
  );
});

/// 지난 회차 기록 (시작 화면)
Future<void> openRuns(BuildContext context, GameController game) => showSheet<void>(
  context,
  (ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      sheetHeader(ctx, '📜 지난 회차 기록', sub: '지금까지 ${game.runs.length}판'),
      Flexible(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [runsTable(game.runs)]),
      ),
    ],
  ),
);

/// 회차 비교표. 항목마다 가장 좋은 기록에 👑
Widget runsTable(List<RunRecord> runs, {RunRecord? highlight}) {
  if (runs.isEmpty) return const SizedBox.shrink();
  final best = (
    followers: runs.map((r) => r.followers).reduce(max),
    earned: runs.map((r) => r.earned).reduce(max),
    peak: runs.map((r) => r.peak).reduce(max),
    rank: runs.map((r) => r.rank).where((x) => x > 0).fold(99, min),
  );
  Widget cell(String t, {bool crown = false, bool bold = false, double w = 64}) => SizedBox(
    width: w,
    child: Text(
      crown ? '👑$t' : t,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: crown ? Pal.gold : Pal.text, fontSize: 12.5, fontWeight: bold || crown ? FontWeight.w800 : FontWeight.w600),
    ),
  );
  Widget header(String t, {double w = 64}) => SizedBox(
    width: w,
    child: Text(
      t,
      style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w800),
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        runs.length > 1 ? '🔁 회차 비교' : '🔁 회차 기록',
        style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      if (runs.length > 1) mutedText('항목마다 가장 좋은 기록에 👑', size: 12),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [header('회차', w: 40), header('이름', w: 76), header('엔딩', w: 92), header('일수', w: 48), header('구독자'), header('최고 시청'), header('총 수입', w: 72), header('순위', w: 48)]),
            const SizedBox(height: 6),
            for (final (i, r) in runs.indexed.toList().reversed)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: highlight != null && r.at == highlight.at ? Pal.pink.withValues(alpha: 0.14) : Pal.surface2, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    cell(' ${i + 1}', w: 40, bold: true),
                    cell(r.name, w: 76),
                    cell(endings[r.ending]?.title ?? r.ending, w: 92),
                    cell('${r.days}일', w: 48),
                    cell(shortNum(r.followers), crown: runs.length > 1 && r.followers == best.followers),
                    cell(shortNum(r.peak), crown: runs.length > 1 && r.peak == best.peak),
                    cell(shortWon(r.earned), crown: runs.length > 1 && r.earned == best.earned, w: 72),
                    cell(r.rank > 0 ? '${r.rank}위' : '-', crown: runs.length > 1 && r.rank == best.rank, w: 48),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
