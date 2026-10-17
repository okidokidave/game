import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import '../game/game_state.dart';
import '../scene/room_view.dart';
import 'dialogs.dart';
import 'palette.dart';
import 'sheets.dart';

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
  bool _long = true;
  String _gender = 'f';
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
        look: Look(hair: _hair, shirt: _shirt, long: _long, gender: _gender),
        wallColor: 0xE9DCCB,
        trend: 'talk',
        slot: 2,
        deco: ['neon', 'plant', 'rug'],
        gear: {'camera': 0, 'mic': 0, 'light': 1, 'pc': 0},
      );

  Future<void> _start() async {
    if (_saved != null) {
      final i = await ask(context, '새로 시작할까요?', [mutedText('저장된 게임(${_saved!.name}, D+${_saved!.day})이 사라져요.', size: 14.5)], const [
        DialogButton('새로 시작', primary: true),
        DialogButton('취소'),
      ]);
      if (i != 0) return;
    }
    final name = _name.text.trim();
    widget.game.newGame(name.isEmpty ? '방구석스타' : (name.length > 10 ? name.substring(0, 10) : name), Look(hair: _hair, shirt: _shirt, long: _long, gender: _gender));
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Pal.screen),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // 방 미리보기
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2F5A), Color(0xFF14172E)]),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Pal.stroke),
                  boxShadow: [BoxShadow(color: Pal.pink.withValues(alpha: 0.18), blurRadius: 32)],
                ),
                clipBehavior: Clip.antiAlias,
                child: RoomView(state: _preview, mode: 'live'),
              ),
              const SizedBox(height: 22),
              // 로고
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(gradient: Pal.brandSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: Pal.stroke)),
                  child: const Text('● LIVE  도트 방송 시뮬레이션', style: TextStyle(color: Color(0xFFFFB3CF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFFFC2DA), Color(0xFFC9B5FF)]).createShader(r),
                child: const Text(
                  '스트리머 키우기',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, height: 1.15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '스마트폰 하나로 시작해 최고의 스트리머가 되어 보세요.\n당신의 모든 행동은 SNS에서 토론거리가 됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pal.muted, height: 1.6, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (_saved != null) ...[
                GradientButton(
                  key: const ValueKey('continue'),
                  icon: '▶',
                  label: '이어하기',
                  sub: '${_saved!.name} · DAY ${_saved!.day} · 구독자 ${shortNum(_saved!.followers)}',
                  onTap: _continue,
                  height: 60,
                ),
                const SizedBox(height: 18),
              ],
              // 캐릭터 만들기
              Glass(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('새 방송인 만들기', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('name-field'),
                      controller: _name,
                      maxLength: 10,
                      style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 16),
                      cursorColor: Pal.pink,
                      decoration: InputDecoration(
                        hintText: '방송 닉네임 (예: 방구석스타)',
                        hintStyle: const TextStyle(color: Pal.muted, fontWeight: FontWeight.w500),
                        counterText: '',
                        filled: true,
                        fillColor: Pal.bg,
                        prefixIcon: const Padding(padding: EdgeInsets.only(left: 14, right: 8), child: Text('🎙️', style: TextStyle(fontSize: 18))),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Pal.pink, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('성별'),
                    _segments([
                      // 성별을 바꾸면 머리 길이 기본값도 바꾼다 (나중에 따로 바꿀 수 있음)
                      _seg('🙋‍♀️ 여자', _gender == 'f', () => _setGender('f'), const ValueKey('gender-f')),
                      _seg('🙋‍♂️ 남자', _gender == 'm', () => _setGender('m'), const ValueKey('gender-m')),
                    ]),
                    const SizedBox(height: 6),
                    mutedText(_gender == 'f' ? '여자 방송인은 남자 팬이 더 많이 모여요.' : '남자 방송인은 여자 팬이 더 많이 모여요.', size: 12),
                    const SizedBox(height: 14),
                    _label('머리 색'),
                    _swatches(hairs, _hair, (c) => setState(() => _hair = c)),
                    const SizedBox(height: 14),
                    _label('머리 길이'),
                    _segments([
                      _seg('짧게', !_long, () => setState(() => _long = false)),
                      _seg('길게', _long, () => setState(() => _long = true)),
                    ]),
                    const SizedBox(height: 14),
                    _label('옷 색'),
                    _swatches(shirts, _shirt, (c) => setState(() => _shirt = c)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _saved == null
                  ? GradientButton(key: const ValueKey('new-game'), icon: '📡', label: '방송 시작하기', onTap: _start, height: 58)
                  : GhostButton(key: const ValueKey('new-game'), label: '새로 시작하기', onTap: _start),
              if (widget.game.runs.isNotEmpty) ...[
                const SizedBox(height: 10),
                GhostButton(key: const ValueKey('runs-title'), label: '📜 지난 회차 기록 ${widget.game.runs.length}판', onTap: () => openRuns(context, widget.game)),
              ],
              if (got.isNotEmpty || widget.game.achieved.isNotEmpty) ...[
                const SizedBox(height: 10),
                GhostButton(
                  key: const ValueKey('achievements-title'),
                  label: '🏅 업적 도감 · 🎁 다회차 혜택 ${widget.game.unlockedPerks.length}/${perks.length}',
                  onTap: () => openAchievements(context, widget.game),
                ),
              ],
              if (got.isNotEmpty) ...[
                const SizedBox(height: 16),
                Glass(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏆 엔딩 도감 ${got.length} / ${endings.length}', style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in endings.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: got.contains(e.key) ? Pal.endingColor(e.value.type).withValues(alpha: 0.16) : Pal.bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                got.contains(e.key) ? e.value.title : '???',
                                style: TextStyle(color: got.contains(e.key) ? Pal.endingColor(e.value.type) : Pal.muted, fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Pal.muted, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  void _setGender(String g) => setState(() {
        _gender = g;
        _long = g == 'f';
      });

  Widget _segments(List<Widget> children) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Pal.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(children: children),
      );

  Widget _seg(String label, bool active, VoidCallback onTap, [Key? key]) => Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: active ? Pal.brand : null, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : Pal.muted)),
          ),
        ),
      );

  Widget _swatches(List<int> colors, int selected, ValueChanged<int> onPick) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onPick(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: selected == c ? Pal.brand : null),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | c),
                    shape: BoxShape.circle,
                    border: Border.all(color: selected == c ? Pal.surface : Pal.stroke, width: selected == c ? 2.5 : 1),
                  ),
                ),
              ),
            ),
        ],
      );
}
