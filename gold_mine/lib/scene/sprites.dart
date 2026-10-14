import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// 가로로 칸이 이어진 스프라이트 시트 한 장.
class SpriteSheet {
  SpriteSheet(this.image, this.frameWidth, this.frameHeight);

  final ui.Image image;
  final double frameWidth;
  final double frameHeight;

  int get frameCount => image.width ~/ frameWidth;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// [frame]번 칸을 (x, y)에 그린다. [flip]이면 좌우를 뒤집는다.
  void draw(Canvas canvas, int frame, double x, double y, {bool flip = false}) {
    final src = Rect.fromLTWH(
      (frame % frameCount) * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );
    if (!flip) {
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(x, y, frameWidth, frameHeight),
        _paint,
      );
      return;
    }
    canvas.save();
    canvas.translate(x + frameWidth, y);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, frameWidth, frameHeight),
      _paint,
    );
    canvas.restore();
  }
}

/// 게임에서 쓰는 모든 도트 그림.
///
/// 그림 파일은 tool/generate_sprites.py 로 만든다.
/// 디자이너 그림으로 바꿀 때는 같은 파일 이름과 아래 칸 크기를 지키면 된다.
class Sprites {
  Sprites._(this._sheets);

  final Map<String, SpriteSheet> _sheets;

  /// 0-3 걷기, 4-7 광석 지고 걷기, 8-10 곡괭이질, 11 서 있기. 오른쪽을 본다.
  SpriteSheet get miner => _sheets['miner']!;

  /// 층 테마별 암벽 (흙, 돌, 깊은 돌, 수정, 용암).
  SpriteSheet get wall => _sheets['wall']!;

  /// 층 테마별 굴 안쪽 배경 타일.
  SpriteSheet get tunnel => _sheets['tunnel']!;

  /// 층 테마별 땅속 흙 타일.
  SpriteSheet get dirt => _sheets['dirt']!;

  /// 0 비어 있음, 1 조금, 2 가득.
  SpriteSheet get crate => _sheets['crate']!;

  /// 0 빈 엘리베이터, 1 광석 실음.
  SpriteSheet get cage => _sheets['cage']!;

  /// 0-1 빈 수레(바퀴 2칸), 2-3 실은 수레.
  SpriteSheet get cart => _sheets['cart']!;

  SpriteSheet get warehouse => _sheets['warehouse']!;
  SpriteSheet get wheel => _sheets['wheel']!;
  SpriteSheet get cloud => _sheets['cloud']!;

  /// 파일 이름 → (칸 너비, 칸 높이)
  static const Map<String, (double, double)> frameSizes = {
    'miner': (24, 22),
    'wall': (20, 34),
    'tunnel': (16, 16),
    'dirt': (16, 16),
    'crate': (14, 12),
    'cage': (16, 18),
    'cart': (20, 13),
    'warehouse': (34, 28),
    'wheel': (10, 10),
    'cloud': (22, 8),
  };

  static Future<Sprites> load([AssetBundle? bundle]) async {
    final assets = bundle ?? rootBundle;
    final sheets = <String, SpriteSheet>{};
    for (final entry in frameSizes.entries) {
      final data = await assets.load('assets/sprites/${entry.key}.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      sheets[entry.key] = SpriteSheet(
        frame.image,
        entry.value.$1,
        entry.value.$2,
      );
    }
    return Sprites._(sheets);
  }
}
