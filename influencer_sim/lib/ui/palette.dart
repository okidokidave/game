import 'package:flutter/material.dart';

/// 웹 버전과 같은 색 (따뜻한 베이지 + 갈색 포인트)
class Pal {
  Pal._();

  static const bg = Color(0xFFF6F3EE);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF2A2622);
  static const muted = Color(0xFF7A726A);
  static const border = Color(0xFFE3DDD4);
  static const accent = Color(0xFF8A5A2B);
  static const accentText = Color(0xFFFFFFFF);

  static const good = Color(0xFF2F7D4F);
  static const bad = Color(0xFFA33B3B);
  static const normal = Color(0xFF8A6D1F);
  static const trueEnd = Color(0xFF6A4BB0);

  static const live = Color(0xFFFF3B3B);
  static const energy = Color(0xFFF59E0B);
  static const mental = Color(0xFF8B5CF6);
  static const image = Color(0xFF10B981);
  static const heat = Color(0xFFEF4444);

  static const stage = Color(0xFF171A2C);
  static const sns = Color(0xFF1D9BF0);
  static const shield = Color(0xFF3B82F6);
  static const hate = Color(0xFFEF4444);

  static Color endingColor(String type) => switch (type) {
        'true' => trueEnd,
        'good' => good,
        'normal' => normal,
        _ => bad,
      };
}

/// 위로 볼록한 버튼 (웹 버전의 3D 버튼 느낌)
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({super.key, required this.child, required this.onTap, this.edge = Pal.border, this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 6)});

  final Widget child;
  final VoidCallback? onTap;
  final Color edge;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: edge, width: 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border(bottom: BorderSide(color: edge, width: 3)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
