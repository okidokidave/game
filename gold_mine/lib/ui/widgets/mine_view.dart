import 'package:flutter/material.dart';

import '../number_format.dart';

/// 광산 그림, 인부 목록, 터치 채굴 영역.
class MineView extends StatefulWidget {
  const MineView({
    super.key,
    required this.mineName,
    required this.mineLevel,
    required this.workers,
    required this.maxWorkers,
    required this.onTap,
  });

  final String mineName;
  final int mineLevel;
  final int workers;
  final int maxWorkers;

  /// 터치로 채굴하고 얻은 골드를 돌려준다.
  final double Function() onTap;

  @override
  State<MineView> createState() => _MineViewState();
}

class _MineViewState extends State<MineView> {
  final List<_FloatingGold> _floats = [];
  int _nextId = 0;
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    final earned = widget.onTap();
    setState(() {
      _pressed = true;
      _floats.add(_FloatingGold(_nextId++, earned, details.localPosition));
    });
  }

  void _release() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${widget.mineName}  Lv.${widget.mineLevel}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: (_) => _release(),
            onTapCancel: _release,
            child: Stack(
              children: [
                Center(
                  child: AnimatedScale(
                    scale: _pressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF6D4C41), Color(0xFF3E2723)],
                        ),
                        border: Border.all(color: Colors.amber, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 16),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('⛏️', style: TextStyle(fontSize: 80)),
                    ),
                  ),
                ),
                for (final f in _floats)
                  _FloatingGoldText(
                    key: ValueKey(f.id),
                    data: f,
                    onDone: () => setState(() => _floats.remove(f)),
                  ),
              ],
            ),
          ),
        ),
        const Text(
          '광산을 터치해서 직접 캐 보세요!',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        _WorkerRow(workers: widget.workers, maxWorkers: widget.maxWorkers),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// 고용된 인부는 밝게, 빈 자리는 흐리게 표시한다.
class _WorkerRow extends StatelessWidget {
  const _WorkerRow({required this.workers, required this.maxWorkers});

  static const _maxIcons = 15;

  final int workers;
  final int maxWorkers;

  @override
  Widget build(BuildContext context) {
    if (maxWorkers > _maxIcons) {
      return Text(
        '👷 인부 $workers / $maxWorkers명',
        style: const TextStyle(fontSize: 16),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        for (var i = 0; i < maxWorkers; i++)
          Icon(
            Icons.engineering,
            size: 28,
            color: i < workers ? Colors.amber : Colors.white24,
          ),
      ],
    );
  }
}

class _FloatingGold {
  _FloatingGold(this.id, this.amount, this.position);

  final int id;
  final double amount;
  final Offset position;
}

/// 터치한 위치에서 "+N" 글자가 위로 떠오르며 사라진다.
class _FloatingGoldText extends StatelessWidget {
  const _FloatingGoldText({
    super.key,
    required this.data,
    required this.onDone,
  });

  final _FloatingGold data;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      onEnd: onDone,
      builder: (context, t, child) => Positioned(
        left: data.position.dx - 30,
        top: data.position.dy - 20 - 60 * t,
        child: IgnorePointer(
          child: Opacity(opacity: 1 - t, child: child),
        ),
      ),
      child: Text(
        '+${formatRate(data.amount)}',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.amber,
        ),
      ),
    );
  }
}
