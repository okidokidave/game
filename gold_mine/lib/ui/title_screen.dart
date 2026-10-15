import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/sound_service.dart';
import '../game/game_controller.dart';
import '../scene/sprites.dart';
import 'number_format.dart';

/// 게임을 켜면 처음 보이는 메인 화면.
///
/// 언덕의 광산 입구, 드나드는 광차, 광석을 지고 오가는 광부가 움직이고,
/// "광산으로 출발" 버튼을 누르면 게임 화면으로 넘어간다.
class TitleScreen extends StatefulWidget {
  const TitleScreen({
    super.key,
    required this.game,
    required this.onStart,
    this.sprites,
    this.sound,
  });

  final GameController game;
  final Sprites? sprites;
  final SoundService? sound;

  /// 출발 버튼을 눌렀을 때 (게임 화면으로 넘어가기).
  final VoidCallback onStart;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  bool get _hasProgress => widget.game.totalEarned > 0;

  void _start() {
    widget.sound?.play(Sfx.buy);
    widget.onStart();
  }

  void _showSettings() {
    final sound = widget.sound;
    if (sound == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListenableBuilder(
          listenable: sound,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('효과음 · 진동'),
                value: sound.sfxOn,
                onChanged: sound.setSfxOn,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.music_note),
                title: const Text('배경음악'),
                value: sound.musicOn,
                onChanged: sound.setMusicOn,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      backgroundColor: const Color(0xFF1E1610),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TitlePainter(time: _time, sprites: widget.sprites),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                const _Logo(),
                const SizedBox(height: 10),
                Text(
                  _hasProgress
                      ? '${game.mineName} B${game.mineLevel} · '
                            '💰 ${formatGold(game.gold)}'
                      : '현장 소장님, 새 광산이 기다려요!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  height: 56,
                  child: FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFF6B4423),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(_hasProgress ? '⛏ 이어서 채굴하기' : '⛏ 광산으로 출발!'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _showSettings,
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  label: const Text(
                    '설정',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 테두리가 있는 큰 제목 글자.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    Widget outlined(String text, double size, Color fill) => Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 6
              ..color = const Color(0xFF3B2414),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: fill,
            shadows: const [Shadow(color: Color(0xFFFFF3A8), blurRadius: 12)],
          ),
        ),
      ],
    );
    return Column(
      children: [
        outlined('골드 광산', 48, const Color(0xFFFFC83D)),
        outlined('키우기', 30, Colors.white),
      ],
    );
  }
}

/// 메인 화면 배경: 하늘, 먼 산, 광산 입구가 있는 언덕, 광차와 광부.
class _TitlePainter extends CustomPainter {
  _TitlePainter({required this.time, this.sprites}) : super(repaint: time);

  final ValueNotifier<double> time;
  final Sprites? sprites;

  static const double _width = 80; // 도트 단위 화면 너비 (작을수록 도트가 크다)

  final Paint _fill = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _width;
    final h = size.height / scale;
    final t = time.value;
    canvas.save();
    canvas.scale(scale);

    // 하늘 (노을빛으로 아래가 밝다)
    const top = Color(0xFF4A8FD0);
    const low = Color(0xFFFFD9A0);
    final ground = h * 0.72;
    for (var i = 0; i < 10; i++) {
      _rect(
        canvas,
        0,
        i * ground / 10,
        _width,
        ground / 10 + 0.5,
        Color.lerp(top, low, i / 9)!,
      );
    }
    // 해
    _rect(canvas, 58, ground * 0.46, 10, 10, const Color(0xFFFFE36E));
    _rect(canvas, 60, ground * 0.46 + 2, 6, 6, const Color(0xFFFFF6C0));

    final s = sprites;
    if (s != null) {
      for (var i = 0; i < 3; i++) {
        final x = (t * (2 + i) + i * 47) % (_width + 30) - 24;
        s.cloud.draw(canvas, 0, x, ground * (0.18 + i * 0.12));
      }
    }

    // 먼 산 (계단식 삼각형)
    _mountain(canvas, 10, ground, 22, const Color(0xFF6F7FA8));
    _mountain(canvas, 50, ground, 30, const Color(0xFF5E6E98));
    _mountain(canvas, 78, ground, 20, const Color(0xFF6F7FA8));

    // 광산 입구가 있는 언덕
    const hillColor = Color(0xFF7A5434);
    const hillDark = Color(0xFF5C3E26);
    for (var row = 0; row < 22; row++) {
      final half = 18 + row * 1.6;
      _rect(
        canvas,
        34 - half,
        ground - 22 + row,
        half * 2,
        1,
        row < 2 ? const Color(0xFF5FB246) : hillColor,
      );
    }
    // 입구 (어두운 굴과 나무 틀)
    _rect(canvas, 26, ground - 14, 16, 14, const Color(0xFF140D08));
    _rect(canvas, 28, ground - 16, 12, 2, const Color(0xFF140D08));
    _rect(canvas, 24, ground - 16, 2, 16, const Color(0xFF96623A));
    _rect(canvas, 42, ground - 16, 2, 16, const Color(0xFF96623A));
    _rect(canvas, 23, ground - 18, 22, 3, const Color(0xFFBA824C));
    _rect(canvas, 23, ground - 16, 22, 1, hillDark);
    // 등불
    final glow = 0.25 + 0.08 * sin(t * 7);
    canvas.drawCircle(
      Offset(25, ground - 12),
      5,
      Paint()..color = const Color(0xFFFFD35A).withValues(alpha: glow),
    );
    _rect(canvas, 24, ground - 13, 2, 2, const Color(0xFFFFE9A0));

    // 땅
    if (s != null) {
      for (var x = 0.0; x < _width; x += 16) {
        for (var y = ground; y < h; y += 16) {
          s.dirt.draw(canvas, 0, x, y);
        }
      }
    } else {
      _rect(canvas, 0, ground, _width, h - ground, const Color(0xFF7A5434));
    }
    _rect(canvas, 0, ground, _width, 2, const Color(0xFF5FB246));
    _rect(canvas, 0, ground + 2, _width, 1, const Color(0xFF3F8A34));
    // 레일
    _rect(canvas, 30, ground - 1, 90, 1, const Color(0xFF7D8A96));

    if (s != null) {
      // 광차: 굴에서 나왔다가 들어간다
      const period = 9.0;
      final p = (t % period) / period;
      final out = p < 0.5 ? p * 2 : (1 - p) * 2;
      final cartX = 28 + out * 62;
      final moving = (p % 0.5) > 0.05 && (p % 0.5) < 0.45;
      s.cart.draw(
        canvas,
        (p < 0.5 ? 2 : 0) + (moving ? (t * 6).floor() % 2 : 0),
        cartX,
        ground - 13,
      );

      // 광부: 광석 자루를 지고 나왔다가 빈손으로 돌아간다
      const walk = 7.0;
      final q = (t % (walk * 2)) / walk;
      final carrying = q < 1;
      final mx = carrying ? 40 + q * 66 : 106 - (q - 1) * 66;
      final frame = (t * 8).floor() % 4 + (carrying ? 4 : 0);
      s.miner.draw(canvas, frame, mx, ground - 21, flip: !carrying, row: 1);
    }

    canvas.restore();
  }

  void _mountain(Canvas c, double cx, double base, double height, Color col) {
    for (var row = 0; row < height; row += 2) {
      final half = row * 1.3;
      _rect(c, cx - half, base - height + row, half * 2, 2, col);
    }
    // 눈 덮인 꼭대기
    _rect(c, cx - 2, base - height, 4, 3, const Color(0xFFEFF4FA));
  }

  @override
  bool shouldRepaint(_TitlePainter old) => true;
}
