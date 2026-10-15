import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import '../scene/room_view.dart';
import 'palette.dart';

/// 시작 화면: 내 방 미리보기, 닉네임과 외모 고르기, 이어하기
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.game, required this.onStart});

  final GameController game;

  /// 새 게임이면 true
  final void Function(bool isNew) onStart;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  static const hairs = [0x2A2230, 0x6B4226, 0xC98A3C, 0xE8C66A, 0xD9577A, 0x5B7BD6, 0x8FD0C8, 0xE8E8EE];
  static const shirts = [0xF4F4F4, 0xE85D5D, 0xF2A13A, 0x5FBF72, 0x4F8FE0, 0x9B6FE0, 0x2A2A2E, 0xF59BB8];

  final _name = TextEditingController();
  int _hair = hairs[0];
  int _shirt = shirts[1];
  bool _long = false;
  GameState? _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.game.saved;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GameState get _preview => GameState(
        name: '',
        look: Look(hair: _hair, shirt: _shirt, long: _long),
        wallColor: 0xE9DCCB,
        trend: 'talk',
        slot: 2,
        deco: ['neon', 'plant', 'rug'],
        gear: {'camera': 0, 'mic': 0, 'light': 1, 'pc': 0},
      );

  Future<void> _start() async {
    if (_saved != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('저장된 게임이 사라져요. 새로 시작할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새로 시작')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final name = _name.text.trim();
    widget.game.newGame(name.isEmpty ? '방구석스타' : (name.length > 10 ? name.substring(0, 10) : name), Look(hair: _hair, shirt: _shirt, long: _long));
    widget.onStart(true);
  }

  void _continue() {
    widget.game.resume(_saved!);
    widget.onStart(false);
  }

  @override
  Widget build(BuildContext context) {
    final got = widget.game.endingsSeen;
    return Scaffold(
      backgroundColor: Pal.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2F4A), Color(0xFF171A2C)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Pal.stage, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: RoomView(state: _preview, mode: 'live'),
            ),
            const SizedBox(height: 20),
            const Text('도트 방송 시뮬레이션', textAlign: TextAlign.center, style: TextStyle(color: Pal.muted, letterSpacing: 1.5, fontSize: 13)),
            const SizedBox(height: 4),
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('인플루언서 시뮬레이터', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Pal.text)),
            ),
            const SizedBox(height: 8),
            const Text(
              '스마트폰 하나로 시작해 60일 안에 셀럽이 되어 보세요.\n당신의 모든 행동은 SNS에서 토론거리가 됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Pal.muted, height: 1.6),
            ),
            const SizedBox(height: 22),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  children: [
                    _field(
                      '방송 닉네임',
                      Expanded(
                        child: TextField(
                          key: const ValueKey('name-field'),
                          controller: _name,
                          maxLength: 10,
                          decoration: InputDecoration(
                            hintText: '방구석스타',
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: Pal.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pal.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Pal.border)),
                          ),
                        ),
                      ),
                    ),
                    _field('머리 색', _swatches(hairs, _hair, (c) => setState(() => _hair = c))),
                    _field(
                      '머리 길이',
                      SegmentedButton<bool>(
                        segments: const [ButtonSegment(value: false, label: Text('짧게')), ButtonSegment(value: true, label: Text('길게'))],
                        selected: {_long},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => setState(() => _long = v.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: Pal.accent,
                          selectedForegroundColor: Pal.accentText,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    _field('옷 색', _swatches(shirts, _shirt, (c) => setState(() => _shirt = c))),
                    const SizedBox(height: 16),
                    if (_saved != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _bigButton('이어하기 · ${_saved!.name} D+${_saved!.day}', _continue, primary: true, key: const ValueKey('continue')),
                      ),
                    _bigButton('새로 시작', _start, primary: _saved == null, key: const ValueKey('new-game')),
                    if (got.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '엔딩 도감 ${got.length} / ${endings.length} · ${got.map((k) => endings[k]?.title ?? k).join(', ')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Pal.muted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Pal.text))),
            if (child is Expanded) child else Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
          ],
        ),
      );

  Widget _swatches(List<int> colors, int selected, ValueChanged<int> onPick) => Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(0xFF000000 | c),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected == c ? Pal.text : Pal.border, width: selected == c ? 2.5 : 2),
                  boxShadow: selected == c ? const [BoxShadow(color: Pal.accent, spreadRadius: 2)] : null,
                ),
              ),
            ),
        ],
      );

  Widget _bigButton(String label, VoidCallback onTap, {bool primary = false, Key? key}) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: key,
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: primary ? Pal.accent : Pal.surface,
            foregroundColor: primary ? Pal.accentText : Pal.text,
            side: primary ? null : const BorderSide(color: Pal.border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      );
}
