import 'dart:math';

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/game_controller.dart';
import 'dialogs.dart';
import 'palette.dart';

// 재테크: 주식 · 코인 · 부동산 · 복권

Future<void> openInvest(BuildContext context, GameController game) => showSheet<void>(context, (ctx) => _InvestSheet(game: game));

class _InvestSheet extends StatefulWidget {
  const _InvestSheet({required this.game});
  final GameController game;

  @override
  State<_InvestSheet> createState() => _InvestSheetState();
}

class _InvestSheetState extends State<_InvestSheet> {
  static const _tabs = [('stock', '📈 주식'), ('coin', '🪙 코인'), ('estate', '🏢 부동산'), ('lotto', '🎟️ 복권')];
  String _tab = 'stock';

  /// 방금 긁은 복권 결과
  String? _lotto;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final s = game.s;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            sheetHeader(context, '💹 재테크', sub: '💰 통장 ${s.money < 0 ? '-' : ''}${won(s.money)} · 투자 평가액 ${shortWon(game.portfolioValue)}'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (id, label) in _tabs)
                    ChoiceChip(
                      key: ValueKey('invest-tab-$id'),
                      label: Text(label),
                      selected: _tab == id,
                      onSelected: (_) => setState(() => _tab = id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: switch (_tab) {
                  'estate' => [for (final e in estates) _estateRow(game, e)],
                  'lotto' => [_lottoCard(game)],
                  _ => [
                      mutedText(_tab == 'coin' ? '코인은 하루에도 크게 오르내려요. 잃어도 괜찮은 돈만!' : '가격은 매일 밤 바뀌어요. 주식이나 코인을 사면 📈 주식·코인 방송이 열려요.', size: 12.5),
                      const SizedBox(height: 8),
                      for (final a in assets.where((a) => a.kind == _tab)) _assetRow(game, a),
                    ],
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Pal.surface2, borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  Widget _btn(String label, VoidCallback? onTap, Key key, {bool primary = true}) => Pressable(
        key: key,
        onTap: onTap,
        gradient: onTap != null && primary ? Pal.brand : null,
        color: onTap == null || !primary ? Pal.bg : null,
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(label, style: TextStyle(color: onTap != null ? Colors.white : Pal.muted, fontWeight: FontWeight.w800, fontSize: 12.5)),
      );

  String _price(double p) => p >= 100 ? won(p.round()) : '${p.toStringAsFixed(1)}원';

  Widget _assetRow(GameController game, Asset a) {
    final s = game.s;
    final p = game.priceOf(a);
    final ch = game.changeOf(a);
    final qty = s.holdings[a.id] ?? 0;
    final value = game.holdingValue(a);
    final profit = value - (s.costBasis[a.id] ?? 0);
    final up = ch >= 0;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(a.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                    Text(a.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              SizedBox(width: 60, height: 26, child: CustomPaint(painter: _Spark(s.priceHist[a.id] ?? [a.start, p], up ? Pal.bad : Pal.sns))),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_price(p), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900)),
                  // 한국식: 오르면 빨강, 내리면 파랑
                  Text('${up ? '▲' : '▼'} ${(ch.abs() * 100).toStringAsFixed(1)}%', style: TextStyle(color: up ? Pal.bad : Pal.sns, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  qty > 0 ? '보유 ${shortNum(qty)}${a.kind == 'coin' ? '개' : '주'} · ${shortWon(value)} (${profit >= 0 ? '+' : '-'}${shortWon(profit.abs())})' : '보유 없음',
                  style: TextStyle(color: qty == 0 ? Pal.muted : (profit >= 0 ? Pal.bad : Pal.sns), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              for (final amt in const [100000, 1000000])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _btn('+${shortWon(amt)}', s.money >= min(amt, (p * 1.003).ceil()) ? () => game.buyAsset(a, amt) : null, ValueKey('buy-${a.id}-$amt')),
                ),
              if (qty > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _btn('전부 팔기', () => game.sellAsset(a), ValueKey('sell-${a.id}'), primary: false),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estateRow(GameController game, Estate e) {
    final s = game.s;
    final owned = s.estates.contains(e.id);
    final why = game.estateBlock(e);
    final value = s.estateValue[e.id] ?? e.price;
    return _card(
      Row(
        children: [
          Text(e.icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                Text(
                  owned ? '지금 시세 ${shortWon(value)} · 하루 임대 수익 ${shortWon(e.rent)}' : '${e.desc}\n${shortWon(e.price)} · 하루 임대 수익 ${shortWon(e.rent)}',
                  style: const TextStyle(color: Pal.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          owned
              ? _btn('팔기', () => game.sellEstate(e), ValueKey('sell-${e.id}'), primary: false)
              : why != null && why != '돈 부족'
                  ? Text(why, style: const TextStyle(color: Pal.muted, fontSize: 11.5, fontWeight: FontWeight.w700))
                  : _btn('매입', why == null ? () => game.buyEstate(e) : null, ValueKey('buyestate-${e.id}')),
        ],
      ),
    );
  }

  Widget _lottoCard(GameController game) {
    final left = game.lottoLeft;
    return _card(
      Column(
        children: [
          const Text('🎟️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 6),
          Text('한 장 ${won(lottoPrice)} · 오늘 $left장 더 살 수 있어요', style: const TextStyle(color: Pal.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            lottoTiers.map((t) => '${t.$1} ${shortWon(t.$3)}').join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Pal.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _lotto ?? '긁어 보세요!',
              key: ValueKey(_lotto),
              textAlign: TextAlign.center,
              style: TextStyle(color: _lotto != null && !_lotto!.startsWith('꽝') ? Pal.gold : Pal.text, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            key: const ValueKey('lotto-buy'),
            label: '복권 긁기',
            sub: won(lottoPrice),
            onTap: left > 0 && game.s.money >= lottoPrice
                ? () {
                    final (name, prize) = game.buyLotto();
                    setState(() => _lotto = name == null ? '꽝! 다음 기회에…' : '🎉 $name 당첨! +${shortWon(prize)}');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// 작은 시세 그래프
class _Spark extends CustomPainter {
  _Spark(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min), hi = values.reduce(max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / span * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_Spark old) => old.values != values;
}

/// 주식 방송: 오늘의 추천 종목 고르기 버튼 글
String pickLabel(GameController game, Asset a) {
  final ch = game.changeOf(a);
  return '${a.icon} ${a.name}  ${ch >= 0 ? '▲' : '▼'}${(ch.abs() * 100).toStringAsFixed(1)}%${a.kind == 'coin' ? '  (고위험·고수익)' : ''}';
}
