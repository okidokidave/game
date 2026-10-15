// 도트 방 그리기
//
// 싸이월드 미니룸처럼 벽 두 면과 바닥만 보이는 아이소메트릭 단면 방을 그린다.
// 216×186 픽셀로 그린 뒤 화면 크기에 맞춰 (흐리지 않게) 키운다.
//
// 좌표: x는 오른쪽 아래, y는 왼쪽 아래, z는 위. 방 크기는 96×96, 벽 높이 72.
// 화면 좌표 = (ox + x - y, oy + (x + y) / 2 - z)

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../game/game_state.dart';

const roomW = 216;
const roomH = 186;
const _ox = 108.0;
const _oy = 82.0;
const _rw = 96.0;
const _rh = 72.0;

typedef ColFn = int? Function(double a, double b);

ColFn solid(int c) => (_, _) => c;

/// 0xRRGGBB 또는 0xAARRGGBB → 불투명 ARGB
int argb(int c) => c > 0xFFFFFF ? c : 0xFF000000 | c;

int shade(int c, double amt) {
  int f(int v) => (amt > 0 ? v + (255 - v) * amt : v * (1 + amt)).round().clamp(0, 255);
  final r = f((c >> 16) & 0xFF);
  final g = f((c >> 8) & 0xFF);
  final b = f(c & 0xFF);
  return 0xFF000000 | (r << 16) | (g << 8) | b;
}

// ───── 래스터 (픽셀 버퍼) ─────
class Raster {
  final Uint32List buf = Uint32List(roomW * roomH);

  void set(double x, double y, int? c) {
    if (c == null) return;
    final xi = x.floor();
    final yi = y.floor();
    if (xi < 0 || yi < 0 || xi >= roomW || yi >= roomH) return;
    buf[yi * roomW + xi] = argb(c);
  }

  /// 같은 색이 이어지는 칸을 한 번에 그려서 이미지로 만든다.
  ui.Image toImage() {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < roomH; y++) {
      var x = 0;
      while (x < roomW) {
        final c = buf[y * roomW + x];
        if (c == 0) {
          x++;
          continue;
        }
        var e = x + 1;
        while (e < roomW && buf[y * roomW + e] == c) {
          e++;
        }
        paint.color = Color(c);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), (e - x).toDouble(), 1), paint);
        x = e;
      }
    }
    final picture = rec.endRecording();
    final image = picture.toImageSync(roomW, roomH);
    picture.dispose();
    return image;
  }
}

double _sx(double x, double y) => _ox + x - y;
double _sy(double x, double y, double z) => _oy + (x + y) / 2 - z;

/// 방 좌표 → 화면 좌표
Offset at(double x, double y, [double z = 0]) => Offset(_sx(x, y), _sy(x, y, z));

// 바닥과 평행한 면 (윗면)
void _top(Raster r, double x0, double y0, double x1, double y1, double z, ColFn col) {
  for (var x = x0; x < x1; x += 0.5) {
    for (var y = y0; y < y1; y += 0.5) {
      r.set(_sx(x, y), _sy(x, y, z), col(x - x0, y - y0));
    }
  }
}

// x가 일정한 면 (왼쪽 벽과 평행, 화면에서 오른쪽 앞면)
void _sideX(Raster r, double x, double y0, double y1, double z0, double z1, ColFn col) {
  for (var y = y0; y < y1; y += 0.5) {
    for (var z = z0; z < z1; z += 0.5) {
      r.set(_sx(x, y), _sy(x, y, z), col(y - y0, z - z0));
    }
  }
}

// y가 일정한 면 (오른쪽 벽과 평행, 화면에서 왼쪽 앞면)
void _sideY(Raster r, double y, double x0, double x1, double z0, double z1, ColFn col) {
  for (var x = x0; x < x1; x += 0.5) {
    for (var z = z0; z < z1; z += 0.5) {
      r.set(_sx(x, y), _sy(x, y, z), col(x - x0, z - z0));
    }
  }
}

void _box(Raster r, double x, double y, double z, double w, double d, double h, int c, {int? l, int? rt, int? t}) {
  _sideY(r, y + d, x, x + w, z, z + h, solid(l ?? argb(c)));
  _sideX(r, x + w, y, y + d, z, z + h, solid(rt ?? shade(c, -0.22)));
  _top(r, x, y, x + w, y + d, z + h, solid(t ?? shade(c, 0.14)));
}

// 2D 스프라이트 (rows: 문자열 목록, pal: 문자 → 색). p는 아래쪽 가운데
void _sprite(Raster r, Offset p, List<String> rows, Map<String, int> pal) {
  final w = rows.first.length;
  final ox = (p.dx - w / 2).roundToDouble();
  final oy = (p.dy - rows.length).roundToDouble();
  for (var j = 0; j < rows.length; j++) {
    final row = rows[j];
    for (var i = 0; i < row.length; i++) {
      final c = pal[row[i]];
      if (c != null) r.set(ox + i, oy + j, c);
    }
  }
}

// ───── 소품 스프라이트 ─────
const _spr = <String, List<String>>{
  'plant': ['...g.g.g...', '..gGg.gGg..', '.gGGgggGGg.', 'gGg.gGg.gGg', '.g.gGGGg.g.', '...gGgGg...', '....ggg....', '....pPp....', '...pPPPp...', '...pPPPp...', '....ppp....'],
  'phone': ['kk', 'kb', 'kb', 'kk', '.s', 'ss'],
  'webcam': ['kkkk', 'kbbk', 'kkkk', '.kk.'],
  'mirrorless': ['..kk..', 'kkkkkk', 'kkbbkk', 'kbBbkk', 'kkbbkk', 'kkkkkk', '..k...', '..k...', '..k...', '..k...', '.k.k..', 'k...k.'],
  'cinema': ['...kkkkk.', '.kkkkkkkk', 'bkkkkkkkk', 'Bbkkkrkkk', 'bkkkkkkkk', '.kkkkkkkk', '....kk...', '....k....', '....k....', '....k....', '....k....', '...k.k...', '..k...k..', '.k.....k.'],
  'boom': ['....kkk', '...k...', '..k....', '.k.....', 'kk.....', 'kk.....', 'kk.....', '.k.....'],
  'studio': ['.sss.', 'sSsSs', 'sSsSs', 'sSsSs', '.sss.', '..k..', '..k..', '.kkk.'],
  'lamp': ['wwww.', 'wyyw.', '..k..', '..k..', '.k...', 'kkk..'],
  'ring': ['..wwww..', '.w....w.', 'w......w', 'w..kk..w', 'w......w', '.w....w.', '..wwww..', '...kk...', '...k....', '...k....', '...k....', '...k....', '...k....', '...k....', '...k....', '..k.k...', '.k...k..', 'k.....k.'],
  'softbox': ['kwwwwwk', 'kwwwwwk', 'kwwwwwk', 'kwwwwwk', '.kkkkk.', '...k...', '...k...', '...k...', '...k...', '...k...', '...k...', '...k...', '...k...', '..k.k..', '.k...k.', 'k.....k'],
  'beanbag': ['....bbbb....', '..bbBBBBbb..', '.bBBBBBBBBb.', 'bBBBBBBBBBBb', 'bBBBbbbbBBBb', 'bbBbbbbbbbBb', '.bbbbbbbbbb.', '..dddddddd..'],
  'figure': ['r.', 'rr', 'kk'],
  'figure2': ['.y', 'yy', 'bb'],
  'cushion': ['..pppppp..', '.pPPPPPPp.', 'pPPPPPPPPp', '.pppppppp.'],
};

// ───── 캐릭터 스프라이트 (12칸) ─────
// h 머리, s 피부, e 눈, m 입, b 볼, t 옷, d 옷 그림자, p 바지, k 신발
const _head = ['...hhhhhh...', '..hhhhhhhh..', '.hhhhhhhhhh.', '.hhhhhhhhhh.', '.hhsshhsssh.', '.hssssssssh.', '.hsessssesh.', '.hsessssesh.', '.hbssmmssbh.', '..ssssssss..'];
const _bodySit = ['...dttttd...', '..tttttttt..', '.stttttttts.', '.stttttttts.', '..dddddddd..', '..pppppppp..'];
const _bodyStand = ['...dttttd...', '..tttttttt..', '.stttttttts.', '.stttttttts.', '..dddddddd..', '...pp..pp...', '...pp..pp...', '...kk..kk...'];
const _armsUp = ['s..dttttd..s', 'st.tttttt.ts', '..tttttttt..', '..tttttttt..', '..dddddddd..', '..pppppppp..'];
const _heart = ['.#.#.', '#####', '#####', '.###.', '..#..'];
const _zz = ['###', '..#', '.#.', '###'];

Map<String, int> _charPalette(Look look, {required bool blink, required bool talk}) => {
      'h': argb(look.hair),
      's': 0xFFF3C9A5,
      'e': blink ? 0xFFE0A98A : 0xFF2A2230,
      'm': talk ? 0xFFA33B3B : 0xFFE0A98A,
      'b': 0xFFF19A9A,
      't': argb(look.shirt),
      'd': shade(look.shirt, -0.25),
      'p': 0xFF3B4A6B,
      'k': 0xFF2A2230,
    };

List<String> _headRows(Look look, bool closed) {
  var rows = [..._head];
  if (look.long) {
    rows = [for (var i = 0; i < rows.length; i++) i >= 4 ? 'h${rows[i].substring(1, 11)}h' : rows[i]];
    rows.addAll(['hh........hh', 'h..........h']);
  }
  if (closed) rows = rows.map((r) => r.replaceAll('e', 'm')).toList();
  return rows;
}

// ───── 방 구성 ─────
const _seatX = 30.0;
const _seatY = 40.0;
const _pillowX = 70.0;
const _pillowY = 13.0;
const _pillowZ = 14.0;
const _deskX = 42.0;

class _Sky {
  const _Sky(this.sky, this.sky2, this.sun);
  final int sky;
  final int sky2;
  final int sun;
}

const _skies = [
  _Sky(0xFF9FD8F5, 0xFFD5F0FF, 0xFFFFF3B0),
  _Sky(0xFFF5B37A, 0xFFFFD9A8, 0xFFFF8A5C),
  _Sky(0xFF1B2350, 0xFF2D3A78, 0xFFF5F0C8),
];

int _g(GameState s, String k) => s.gear[k]!;

/// 캐릭터 뒤에 그려지는 것 (바닥, 벽, 침대, 의자 등)
ui.Image drawBack(GameState s) {
  final r = Raster();
  final deco = s.deco.toSet();
  final wall = argb(s.wallColor);
  final wallR = shade(wall, -0.08);
  const trim = 0xFFB58A62;
  final slot = min(s.slot, 2);

  // 바닥 판
  _box(r, 0, 0, -6, _rw, _rw, 6, 0xFF8A6040);
  _top(r, 0, 0, _rw, _rw, 0, (x, y) {
    final row = (y / 8).floor();
    final seam = (x + row * 13) % 32 < 0.6 || y % 8 < 0.6;
    final tone = row.isOdd ? 0xFFC99A6B : 0xFFC49364;
    return seam ? 0xFFA8784D : tone;
  });

  // 벽 (두께 포함)
  _box(r, -4, 0, -6, 4, _rw, _rh + 6, trim);
  _box(r, -4, -4, -6, _rw + 4, 4, _rh + 6, trim);
  _sideX(r, 0, 0, _rw, 0, _rh, (y, z) {
    if (z < 2) return 0xFF7A5A40;
    if (z < 16) return (y / 4).floor().isOdd ? 0xFFCFAE8A : 0xFFC6A47F;
    if (z < 17) return trim;
    return (y / 6).floor().isOdd ? wall : shade(wall, -0.04);
  });
  _sideY(r, 0, 0, _rw, 0, _rh, (x, z) {
    if (z < 2) return 0xFF6C4F38;
    if (z < 16) return (x / 4).floor().isOdd ? 0xFFC3A27F : 0xFFBB9A76;
    if (z < 17) return shade(trim, -0.1);
    return (x / 6).floor().isOdd ? wallR : shade(wallR, -0.04);
  });

  // 창문 (왼쪽 벽)
  final sky = _skies[slot];
  _sideX(r, 0, 52, 84, 28, 58, (y, z) {
    if (y < 2 || y >= 30 || z < 2 || z >= 28 || (y - 16).abs() < 1) return 0xFFF4EDE2;
    if (slot == 2 && (y * 7 + z * 13) % 37 < 0.6) return 0xFFFFFFFF;
    if (pow(y - 22, 2) + pow(z - 21, 2) < 10) return sky.sun;
    return z > 14 ? sky.sky : sky.sky2;
  });
  _sideX(r, 0.5, 49, 53, 24, 60, solid(0xFFD97F8F));
  _sideX(r, 0.5, 83, 87, 24, 60, solid(0xFFD97F8F));

  // 네온사인 (왼쪽 벽, 캐릭터 뒤)
  if (deco.contains('neon')) {
    const heart = ['..##...##..', '.####.####.', '###########', '###########', '.#########.', '..#######..', '...#####...', '....###....', '.....#.....'];
    _sideX(r, 0.5, 6, 28, 34, 52, (y, z) {
      final ri = 8 - (z / 2).floor();
      final ci = (y / 2).floor();
      if (ri < 0 || ri >= heart.length || ci >= heart[ri].length) return null;
      return heart[ri][ci] == '#' ? 0xFFFF5FA8 : null;
    });
  }

  // 포스터 (오른쪽 벽)
  if (deco.contains('poster')) {
    _sideY(r, 0.5, 44, 58, 30, 52, (x, z) {
      if (x < 1 || x >= 13 || z < 1 || z >= 21) return 0xFFFAFAFA;
      if (z > 14) return 0xFF2B3A67;
      if (z > 8) return pow(x - 7, 2) + pow(z - 11, 2) < 9 ? 0xFFF2C14E : 0xFF2B3A67;
      return 0xFFE85D5D;
    });
  }

  // 선반 + 트로피 (오른쪽 벽)
  final buttons = <int>[
    if (s.followers >= 10000) 0xFFD9DDE3,
    if (s.followers >= 100000) 0xFFF2C14E,
    if (s.followers >= 1000000) 0xFF8FE3F5,
  ];
  if (buttons.isNotEmpty || deco.contains('figure')) {
    _box(r, 8, 0, 38, 30, 6, 2, 0xFF8A6040);
    for (var i = 0; i < buttons.length; i++) {
      final col = buttons[i];
      _sideY(r, 3, 10.0 + i * 9, 17.0 + i * 9, 40, 48, (x, z) {
        if (x < 1 || x >= 6 || z < 1 || z >= 7) return shade(col, -0.2);
        return x > 2 && x < 4.5 && z > 2.5 && z < 5.5 ? 0xFFE8463C : col;
      });
    }
    if (deco.contains('figure')) {
      _sprite(r, at(34, 3, 40), _spr['figure']!, {'r': 0xFFE8463C, 'k': 0xFF333333});
      _sprite(r, at(31, 3, 40), _spr['figure2']!, {'y': 0xFFF2C14E, 'b': 0xFF3E7BD6});
    }
  }

  // 러그
  if (deco.contains('rug')) {
    _top(r, 18, 46, 74, 90, 0.3, (x, y) {
      if (x < 2 || y < 2 || x > 54 || y > 42) return 0xFFE7A9B8;
      return ((x / 6).floor() + (y / 6).floor()).isOdd ? 0xFFF5D6DD : 0xFFF0C4CF;
    });
  }

  // 침대 (오른쪽 벽)
  _box(r, 62, 0, 0, 32, 28, 8, 0xFF8A6040);
  _box(r, 62, 0, 8, 32, 28, 4, 0xFFF5F2EC);
  _box(r, 64, 3, 12, 8, 20, 3, 0xFFFFFFFF);
  _box(r, 74, 1, 12, 20, 26, 2, 0xFF7FB3D5);
  _box(r, 60, 0, 0, 2, 28, 18, 0xFF7A5236);

  // 소프트박스 (뒤쪽 하나)
  if (_g(s, 'light') >= 3) _sprite(r, at(6, 30), _spr['softbox']!, {'k': 0xFF333333, 'w': 0xFFFFFBE8});

  // 의자 / 방석
  final pc = _g(s, 'pc');
  if (pc == 0) {
    _sprite(r, at(_seatX, _seatY), _spr['cushion']!, {'p': 0xFFE07A7A, 'P': 0xFFF09A9A});
  } else if (pc == 1) {
    _box(r, _seatX - 6, _seatY - 4, 0, 2, 8, 22, 0xFF6B6B6B);
    _box(r, _seatX - 4, _seatY - 4, 10, 8, 8, 2, 0xFF7A7A7A);
  } else {
    _box(r, _seatX - 7, _seatY - 5, 0, 3, 10, 30, 0xFF222222, t: 0xFFE8463C);
    _box(r, _seatX - 4, _seatY - 5, 10, 9, 10, 3, 0xFF2A2A2A);
  }

  return r.toImage();
}

/// 카메라 스프라이트의 아래쪽 가운데 (화면 좌표)
Offset camPos(GameState s) {
  final cam = _g(s, 'camera');
  final pc = _g(s, 'pc');
  const dx = _deskX;
  if (cam >= 2) return at(dx + 20, 44);
  if (cam == 0) return at(dx + 3, 32, pc == 0 ? 10 : 22);
  if (pc >= 3) return at(dx + 5, 31, 37);
  if (pc == 2) return at(dx + 5, 29, 37);
  if (pc == 1) return at(dx + 3, 32, 31);
  return at(dx + 4, 32, 10);
}

const _camH = [6, 4, 12, 14];

/// 캐릭터 앞에 그려지는 것 (책상, 장비, 소품)
ui.Image drawFront(GameState s) {
  final r = Raster();
  final deco = s.deco.toSet();
  const dx = _deskX;
  final pc = _g(s, 'pc');
  final mic = _g(s, 'mic');
  final light = _g(s, 'light');
  final cam = _g(s, 'camera');
  double deskTop;

  if (pc == 0) {
    // 좌식 밥상
    deskTop = 10;
    _box(r, dx + 1, 31, 0, 2, 2, 8, 0xFF8A6040);
    _box(r, dx + 11, 31, 0, 2, 2, 8, 0xFF8A6040);
    _box(r, dx + 1, 51, 0, 2, 2, 8, 0xFF8A6040);
    _box(r, dx + 11, 51, 0, 2, 2, 8, 0xFF8A6040);
    _box(r, dx, 30, 8, 14, 24, 2, 0xFFC89A64);
  } else {
    deskTop = 22;
    _box(r, dx, 14, 0, 14, 36, 22, 0xFFD7C2A3, l: 0xFFC4AD8C);
    _top(r, dx, 14, dx + 14, 50, 22, solid(0xFFE8D6BA));
    if (pc >= 3) {
      const rgb = [0xFFFF5FA8, 0xFF5FD3FF, 0xFFB48CFF];
      _sideY(r, 50, dx, dx + 14, 20, 21, (x, _) => rgb[(x / 3).floor() % 3]);
      _sideX(r, dx + 14, 14, 50, 20, 21, (y, _) => rgb[(y / 3).floor() % 3]);
    }
  }

  // PC / 모니터 (화면은 캐릭터 쪽을 보고 있어 뒷면이 보임, 얼굴을 가리지 않게 안쪽에 둠)
  if (pc == 1) {
    _box(r, dx + 3, 26, deskTop, 7, 12, 1, 0xFF9AA0A8);
    _box(r, dx + 2, 26, deskTop + 1, 1, 12, 8, 0xFFB8BEC6);
  } else if (pc >= 2) {
    final mons = pc >= 3 ? [15.0, 31.0] : [22.0];
    for (final my in mons) {
      _box(r, dx + 5, my + 6, deskTop, 2, 3, 4, 0xFF333333);
      _box(r, dx + 4, my, deskTop + 4, 3, 15, 11, 0xFF2A2A2E);
    }
    _box(r, dx + 2, 56, 0, 10, 6, 18, 0xFF222226);
    _sideY(r, 62, dx + 4, dx + 10, 4, 16, (x, z) => (z / 2).floor().isOdd ? 0xFF5FD3FF : 0xFFFF5FA8);
  }

  // 카메라
  final cp = camPos(s);
  if (cam == 0) {
    _sprite(r, cp, _spr['phone']!, {'k': 0xFF222222, 'b': 0xFF5C7CFA, 's': 0xFF888888});
  } else if (cam == 1) {
    _sprite(r, cp, _spr['webcam']!, {'k': 0xFF222222, 'b': 0xFF5C7CFA});
  } else if (cam == 2) {
    _sprite(r, cp, _spr['mirrorless']!, {'k': 0xFF222222, 'b': 0xFF5C7CFA, 'B': 0xFF9FB4FF});
  } else {
    _sprite(r, cp, _spr['cinema']!, {'k': 0xFF1B1B1B, 'b': 0xFF5C7CFA, 'B': 0xFF9FB4FF, 'r': 0xFFE8463C});
  }

  // 마이크
  if (mic == 2) _sprite(r, at(dx + 1, 46, deskTop), _spr['boom']!, {'k': 0xFF222222});
  if (mic >= 3) {
    _sprite(r, at(dx + 2, 45, deskTop), _spr['studio']!, {'s': 0xFFC0C4CA, 'S': 0xFF8A8F96, 'k': 0xFF333333});
    _box(r, dx + 8, 40, deskTop, 5, 6, 3, 0xFFC0392B);
  }

  // 조명
  if (light == 1) _sprite(r, at(dx + 4, pc >= 1 ? 18 : 33, deskTop), _spr['lamp']!, {'w': 0xFFF4F4F4, 'y': 0xFFFFF3B0, 'k': 0xFF555555});
  if (light == 2) _sprite(r, at(dx + 16, 64), _spr['ring']!, {'w': 0xFFFFFBE8, 'k': 0xFF444444});
  if (light >= 3) _sprite(r, at(dx + 18, 70), _spr['softbox']!, {'k': 0xFF333333, 'w': 0xFFFFFBE8});

  // 꾸미기 소품
  if (deco.contains('plant')) _sprite(r, at(6, 88), _spr['plant']!, {'g': 0xFF3F8F4F, 'G': 0xFF62B86E, 'p': 0xFFB5653A, 'P': 0xFFD07A4A});
  if (deco.contains('beanbag')) _sprite(r, at(84, 64), _spr['beanbag']!, {'b': 0xFFE0864F, 'B': 0xFFF2A066, 'd': 0xFF9C5A33});

  return r.toImage();
}

// ───── 움직이는 것 (캐릭터, 효과) ─────
class Particle {
  Particle(this.kind, this.x, this.y, this.vy, this.life);
  final String kind;
  double x;
  double y;
  final double vy;
  double life;
}

/// 한 프레임 그리기. [back]/[front]는 [drawBack]/[drawFront]로 미리 만든 이미지.
class RoomPainter extends CustomPainter {
  RoomPainter({required this.state, required this.mode, required this.back, required this.front, required this.tick, required this.particles});

  final GameState state;
  final String mode;
  final ui.Image back;
  final ui.Image front;
  final int tick;
  final List<Particle> particles;

  static final _px = Paint()..isAntiAlias = false;

  void _rect(Canvas c, double x, double y, double w, double h, int color, [double alpha = 1]) {
    _px.color = Color(color).withValues(alpha: alpha);
    c.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), w, h), _px);
  }

  void _rows(Canvas c, List<String> rows, Map<String, int> pal, double x0, double y0, [double alpha = 1]) {
    for (var j = 0; j < rows.length; j++) {
      final row = rows[j];
      for (var i = 0; i < row.length; i++) {
        final col = pal[row[i]];
        if (col != null) _rect(c, x0 + i, y0 + j, 1, 1, col, alpha);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = state;
    canvas.save();
    canvas.scale(size.width / roomW, size.height / roomH);
    final img = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImage(back, Offset.zero, img);

    final live = mode == 'live';
    final pal = _charPalette(s.look, blink: tick % 40 == 0 || tick % 40 == 1, talk: live && (tick ~/ 2) % 3 != 0);

    if (mode == 'sleep') {
      final h = at(_pillowX, _pillowY, _pillowZ);
      _rows(canvas, _headRows(s.look, true).take(10).toList(), pal, h.dx - 6, h.dy - 9);
    } else if (mode != 'away') {
      final seated = live || mode == 'idle';
      final c = seated ? at(_seatX, _seatY, _g(s, 'pc') == 0 ? 0 : 12) : at(48, 74);
      final bob = live ? (tick % 6 < 3 ? 0 : -1) : (tick % 20 < 10 ? 0 : -1);
      final body = !seated
          ? _bodyStand
          : live && tick % 14 < 4
              ? _armsUp
              : _bodySit;
      final head = _headRows(s.look, false);
      final total = 10 + body.length;
      final x0 = c.dx - 6;
      final y0 = c.dy - total + bob;
      _rows(canvas, body, pal, x0, y0 + 10 - bob);
      _rows(canvas, head, pal, x0, y0);
      if (_g(s, 'mic') == 1) _rect(canvas, x0 + 4, y0 + 11 - bob, 1, 1, 0xFF222222);
      if (live && _g(s, 'light') >= 2) _rect(canvas, x0 - 2, y0 - 2, 16, total + 4.0, 0xFFFFFADC, 0.18);
    }

    canvas.drawImage(front, Offset.zero, img);

    // 시간대 조명
    final slot = min(s.slot, 2);
    const full = Rect.fromLTWH(0, 0, roomW + 0.0, roomH + 0.0);
    if (slot == 2) {
      final dim = const [0.42, 0.34, 0.24, 0.16][_g(s, 'light')];
      canvas.drawRect(full, Paint()..color = const Color(0xFF101234).withValues(alpha: dim));
    } else if (slot == 1) {
      canvas.drawRect(full, Paint()..color = const Color(0xFFFF963C).withValues(alpha: 0.08));
    }

    // 네온 빛 번짐
    if (s.deco.contains('neon')) {
      final n = at(0, 17, 44);
      final a = (slot == 2 ? 0.35 : 0.15) + (tick % 10 < 5 ? 0.05 : 0);
      canvas.drawRect(
        Rect.fromCenter(center: n, width: 52, height: 52),
        Paint()
          ..shader = ui.Gradient.radial(n, 26, [const Color(0xFFFF5FA8).withValues(alpha: a), const Color(0x00FF5FA8)], [2 / 26, 1]),
      );
    }

    // 방송 중 빨간 불
    if (live && tick % 8 < 5) {
      final cp = camPos(s);
      _rect(canvas, cp.dx + 1, cp.dy - _camH[_g(s, 'camera')] - 2, 2, 2, 0xFFFF3B3B);
    }
    // 모니터 빛
    if (live && _g(s, 'pc') >= 1) {
      final c = at(_seatX, _seatY, 30);
      _rect(canvas, c.dx - 4, c.dy - 2, 12, 10, 0xFF5FD3FF, 0.12);
    }

    for (final p in particles) {
      final a = min(1.0, p.life / 10);
      switch (p.kind) {
        case 'heart':
          _rows(canvas, _heart, {'#': 0xFFFF5F8F}, p.x, p.y, a);
        case 'coin':
          _rect(canvas, p.x, p.y, 4, 4, 0xFFF2C14E, a);
          _rect(canvas, p.x + 1, p.y + 1, 2, 2, 0xFFC99A2E, a);
        case 'chat':
          _rect(canvas, p.x, p.y, 7, 4, 0xFFFFFFFF, a);
          _rect(canvas, p.x + 1, p.y + 4, 1, 1, 0xFFFFFFFF, a);
          _rect(canvas, p.x + 1, p.y + 1, 5, 1, 0xFF9AA0A8, a);
          _rect(canvas, p.x + 1, p.y + 2, 3, 1, 0xFF9AA0A8, a);
        case 'z':
          _rows(canvas, _zz, {'#': 0xFFFFFFFF}, p.x, p.y, a);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RoomPainter old) => true;
}

/// 방 효과 입자 만들기
List<Particle> burstParticles(String kind, int n, Random rng) {
  final c = at(_seatX, _seatY, 26);
  return [
    for (var i = 0; i < n; i++) Particle(kind, c.dx + (rng.nextDouble() * 24 - 12), c.dy + rng.nextDouble() * 6, -(0.6 + rng.nextDouble() * 0.8), 22 + rng.nextDouble() * 14),
  ];
}

Particle sleepParticle() {
  final p = at(_pillowX, _pillowY, _pillowZ + 10);
  return Particle('z', p.dx + 2, p.dy - 6, -0.4, 26);
}
