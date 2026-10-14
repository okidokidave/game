import 'package:flutter/material.dart';

import '../number_format.dart';

/// 화면 아래에 세 개가 나란히 놓이는 작은 업그레이드 칸.
class UpgradeTile extends StatelessWidget {
  const UpgradeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.cost,
    required this.enabled,
    required this.onPressed,
    this.maxed = false,
  });

  final IconData icon;
  final String title;

  /// 한 줄 요약 (예: "1/3명", "Lv.1 → 2").
  final String description;
  final double cost;
  final bool enabled;
  final bool maxed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A2C20),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.amber, size: 18),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(maxed ? '가득 참' : formatGold(cost)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
