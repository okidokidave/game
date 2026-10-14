import 'package:flutter/material.dart';

import '../number_format.dart';

/// 화면 상단의 보유 골드와 초당 생산량.
class GoldHeader extends StatelessWidget {
  const GoldHeader({
    super.key,
    required this.gold,
    required this.goldPerSecond,
  });

  final double gold;
  final double goldPerSecond;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 32),
              const SizedBox(width: 8),
              Text(
                formatGold(gold),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '초당 ${formatRate(goldPerSecond)} 골드',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
