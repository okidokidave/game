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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
              const SizedBox(width: 6),
              // 숫자가 길어지면 글자를 줄여서 옆 버튼과 겹치지 않게 한다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatGold(gold),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            '초당 ${formatRate(goldPerSecond)} 골드',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
