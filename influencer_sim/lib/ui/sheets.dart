import 'dart:math';

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
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
                  children: [
                    for (final m in s.missions) _missionRow(game, m),
                    const SizedBox(height: 4),
                    mutedText('미션을 끝내면 보상과 함께 찐팬이 늘어요. 지금까지 완료한 미션 ${s.missionsDone}개', size: 12.5),
                  ],
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
            Text(m.done ? '✅ 완료' : '🎁 ${shortWon(m.reward)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: m.done ? Pal.good : Pal.gold)),
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
            Text(count, style: const TextStyle(fontSize: 12, color: Pal.muted, fontWeight: FontWeight.w700)),
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
                  decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18), border: Border.all(color: Pal.pink)),
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
              const Text('언제?', style: TextStyle(color: Pal.muted, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final x in slots)
                    ChoiceChip(
                      key: ValueKey('sched-slot-${x.$1}-${x.$2}'),
                      label: Text(_when(x)),
                      selected: _slot == x,
                      onSelected: (_) => setState(() => _slot = x),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('무슨 방송?', style: TextStyle(color: Pal.muted, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in open)
                    ChoiceChip(
                      key: ValueKey('sched-content-${c.id}'),
                      label: Text('${c.icon} ${c.name}'),
                      selected: _content == c.id,
                      onSelected: (_) => setState(() => _content = c.id),
                    ),
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

  int _value(DayStat d) => switch (_kind) { 0 => d.followers, 1 => d.money, 2 => d.peak, _ => d.core };

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
                  for (var i = 0; i < _kinds.length; i++)
                    ChoiceChip(
                      key: ValueKey('stats-kind-$i'),
                      label: Text(_kinds[i].$1),
                      selected: _kind == i,
                      onSelected: (_) => setState(() => _kind = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 190,
                padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
                decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18)),
                child: CustomPaint(painter: _LineChart(values, color, money: _kind == 1), size: Size.infinite),
              ),
              const SizedBox(height: 14),
              resultGrid([
                ('총 방송', '${s.streams}회'),
                ('총 수입', shortWon(s.earned)),
                ('최고 시청자', '${shortNum(s.peak)}명'),
                ('찐팬', '${shortNum(s.coreFans)}명 (${(game.loyalty * 100).toStringAsFixed(1)}%)'),
              ]),
              const SizedBox(height: 14),
              const Text('🏅 기억에 남는 방송', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
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
                        child: Text('D${b.day} ${contentOf(b.content).icon} ${contentOf(b.content).name}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
                      ),
                      Text('${shortNum(b.viewers)}명', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900)),
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
      final tp = TextPainter(text: TextSpan(text: money ? shortWon(v) : shortNum(v), style: label), textDirection: TextDirection.ltr)..layout(maxWidth: left - 4);
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
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)])
            .createShader(Rect.fromLTWH(0, 0, size.width, h)),
    );
    canvas.drawPath(line, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(at(n - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LineChart old) => old.values != values || old.color != color;
}

// ───── 업적 도감 · 다회차 혜택 ─────
Future<void> openAchievements(BuildContext context, GameController game) => showSheet<void>(
      context,
      (ctx) {
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
                  const Text('🎁 다회차 혜택 (새 게임에 적용)', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final p in perks)
                    Builder(builder: (_) {
                      final on = p.unlocked(endings, got.length);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(on ? p.icon : '🔒', style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p.text, style: TextStyle(color: on ? Pal.text : Pal.muted, fontWeight: FontWeight.w700))),
                            Text(on ? '적용 중' : p.need, style: TextStyle(color: on ? Pal.good : Pal.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      );
                    }),
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
                              Text(got.contains(a.id) ? '${a.icon} ${a.title}' : '🔒 ${a.title}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: got.contains(a.id) ? Pal.text : Pal.muted)),
                              const SizedBox(height: 3),
                              Text(a.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Pal.muted)),
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
      },
    );

int endingsCount() => endings.length;
