import 'package:flutter/material.dart';

import '../number_format.dart';

/// 업그레이드 한 줄: 아이콘, 이름, 설명, 구매 버튼.
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
  final String description;
  final double cost;
  final bool enabled;
  final bool maxed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF3A2C20),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
