import 'package:flutter/material.dart';

/// 앱 색 (어두운 남색 바탕 + 핑크·보라 그라데이션 포인트)
class Pal {
  Pal._();

  static const bg = Color(0xFF0E1020);
  static const bg2 = Color(0xFF1A1D3A);
  static const surface = Color(0xFF1B1F3B);
  static const surface2 = Color(0xFF262B52);
  static const stroke = Color(0x1AFFFFFF);
  static const text = Color(0xFFF4F5FF);
  static const muted = Color(0xFF9AA0C3);

  static const pink = Color(0xFFFF4D8D);
  static const purple = Color(0xFF8B5CF6);
  static const gold = Color(0xFFFFC94D);
  static const brand = LinearGradient(colors: [pink, purple]);
  static const brandSoft = LinearGradient(colors: [Color(0x33FF4D8D), Color(0x338B5CF6)]);

  static const good = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);
  static const normal = Color(0xFFFBBF24);
  static const trueEnd = Color(0xFFA78BFA);

  static const live = Color(0xFFFF3B5C);
  static const energy = Color(0xFFFBBF24);
  static const mental = Color(0xFFA78BFA);
  static const image = Color(0xFF34D399);
  static const heat = Color(0xFFFF5C5C);

  static const sns = Color(0xFF1D9BF0);
  static const shield = Color(0xFF3B82F6);
  static const hate = Color(0xFFEF4444);

  static const screen = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg2, bg]);

  static Color endingColor(String type) => switch (type) {
        'true' => trueEnd,
        'good' => good,
        'normal' => normal,
        _ => bad,
      };
}

/// 누르면 살짝 작아지는 버튼 틀. [onTap]이 null이면 흐리게 (누를 수 없음).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.radius = 16, this.color, this.gradient, this.border, this.padding = EdgeInsets.zero, this.glow});

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final EdgeInsets padding;
  final Color? glow;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.38,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.gradient == null ? (widget.color ?? Pal.surface2) : null,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.border,
              boxShadow: widget.glow != null && enabled ? [BoxShadow(color: widget.glow!.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))] : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 핑크→보라 그라데이션 큰 버튼
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onTap, this.sub, this.icon, this.height = 54});

  final String label;
  final String? sub;
  final String? icon;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      gradient: Pal.brand,
      glow: Pal.pink,
      radius: height / 2,
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8)],
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  if (sub != null) Text(sub!, maxLines: 1, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 어두운 보조 버튼
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap, this.alignLeft = false, this.height = 52});

  final String label;
  final VoidCallback? onTap;
  final bool alignLeft;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: Pal.surface2,
      border: Border.all(color: Pal.stroke),
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: alignLeft ? 16 : 12, vertical: alignLeft ? 14 : 0),
      child: SizedBox(
        height: alignLeft ? null : height,
        child: Row(
          mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(label, style: const TextStyle(color: Pal.text, fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.35)),
            ),
            if (alignLeft) ...[const SizedBox(width: 8), const Icon(Icons.chevron_right_rounded, color: Pal.muted)],
          ],
        ),
      ),
    );
  }
}

/// 반투명 카드
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 20});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Pal.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Pal.stroke),
        ),
        child: child,
      );
}

/// 둥근 알약 모양 표시 (구독자, 통장 등)
class Pill extends StatelessWidget {
  const Pill({super.key, required this.icon, required this.text, this.color = Pal.text});

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: Pal.stroke)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
}
