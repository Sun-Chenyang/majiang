/// 应用图标生成器（开发计划 M9.3 · 技术方案 §7）。
///
/// 自绘"五星"图案（五筒梅花式：四角花瓣 + 中心星），纯 Dart 光栅化 +
/// 手写 PNG 编码（zlib via dart:io），零第三方依赖。产出：
///  - legacy mipmap-{mdpi..xxxhdpi}/ic_launcher.png（48~192，满幅）
///  - 自适应前景 mipmap-*/ic_launcher_foreground.png（108dp 画布，
///    图案收进 66dp 安全区；minSdk 26 起自适应图标恒生效）
///  - mipmap-anydpi-v26/{ic_launcher,ic_launcher_round}.xml + 背景色
///
/// 运行：dart run tool/gen_icon.dart
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class _RGB {
  final int r, g, b;
  const _RGB(this.r, this.g, this.b);

  _RGB lighten(double t) => _RGB(
        (r + (255 - r) * t).round(),
        (g + (255 - g) * t).round(),
        (b + (255 - b) * t).round(),
      );

  _RGB darken(double t) => _RGB(
        (r * (1 - t)).round(),
        (g * (1 - t)).round(),
        (b * (1 - t)).round(),
      );
}

// 设计参数（与设计系统同源：薄荷 / 冰蓝 / 深板岩）
const _bgTop = _RGB(0x1B, 0x2E, 0x3D);
const _bgBottom = _RGB(0x0E, 0x18, 0x22);
const _petal = _RGB(0x64, 0xD2, 0xB7);
const _star = _RGB(0x70, 0xB6, 0xFF);
const _shine = _RGB(0xFF, 0xFF, 0xFF);

class _Canvas {
  final int size;
  final Uint8List px;

  _Canvas(this.size) : px = Uint8List(size * size * 4);

  void blend(int x, int y, _RGB c, double a) {
    if (a <= 0) return;
    final i = (y * size + x) * 4;
    final dstA = px[i + 3] / 255.0;
    final outA = a + dstA * (1 - a);
    if (outA <= 0) return;
    px[i] = ((c.r * a + px[i] * dstA * (1 - a)) / outA).round();
    px[i + 1] = ((c.g * a + px[i + 1] * dstA * (1 - a)) / outA).round();
    px[i + 2] = ((c.b * a + px[i + 2] * dstA * (1 - a)) / outA).round();
    px[i + 3] = (outA * 255).round();
  }
}

/// 圆覆盖度（1px 反走样过渡带）。
double _circleCover(double cx, double cy, double r, double x, double y) {
  final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
  return ((r - d)).clamp(0.0, 1.0);
}

/// 渲染图标。[patternScale] 图案占边长比例；[opaqueBg] false 时背景透明
/// （自适应前景用）。
Uint8List render(int size, double patternScale, {bool opaqueBg = true}) {
  final cv = _Canvas(size);
  _RGB mix(_RGB a, _RGB b, double t) => _RGB(
        (a.r + (b.r - a.r) * t).round(),
        (a.g + (b.g - a.g) * t).round(),
        (a.b + (b.b - a.b) * t).round(),
      );

  // 五筒梅花布局：四角花瓣 + 中心大星
  final c = size / 2;
  final petalR = size * patternScale * 0.175;
  final starR = size * patternScale * 0.21;
  final off = size * patternScale * 0.235;
  final petals = [
    (c - off, c - off),
    (c + off, c - off),
    (c - off, c + off),
    (c + off, c + off),
  ];

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final fx = x + 0.5, fy = y + 0.5;

      if (opaqueBg) {
        // 背景：对角渐变（左上亮 → 右下暗，全局光照方向）+ 顶部反光带
        final diagT = (fx + fy) / (2 * size);
        var bg = mix(_bgTop, _bgBottom, diagT);
        final sheen = (1 - fy / (size * 0.30)).clamp(0.0, 1.0) * 0.10;
        bg = mix(bg, _shine, sheen);
        cv.blend(x, y, bg, 1);
      }

      for (final (pcx, pcy) in petals) {
        final cover = _circleCover(pcx, pcy, petalR, fx, fy);
        if (cover > 0) {
          final pt = ((fx - (pcx - petalR)) + (fy - (pcy - petalR))) /
              (4 * petalR);
          cv.blend(x, y,
              mix(_petal.lighten(0.18), _petal.darken(0.12), pt), cover);
        }
      }
      final starCover = _circleCover(c, c, starR, fx, fy);
      if (starCover > 0) {
        final st = ((fx - (c - starR)) + (fy - (c - starR))) / (4 * starR);
        cv.blend(x, y, mix(_star.lighten(0.22), _star.darken(0.10), st),
            starCover);
      }
      // 高光点（左上受光，与全局光源一致）
      final hlStar =
          _circleCover(c - starR * 0.34, c - starR * 0.34, starR * 0.22, fx, fy);
      if (hlStar > 0) cv.blend(x, y, _shine, hlStar * 0.85);
      for (final (pcx, pcy) in petals) {
        final hl = _circleCover(
            pcx - petalR * 0.32, pcy - petalR * 0.32, petalR * 0.20, fx, fy);
        if (hl > 0) cv.blend(x, y, _shine, hl * 0.8);
      }
    }
  }
  return cv.px;
}

// ---- PNG 编码（RGBA8，filter 0，zlib） ----

final Uint32List _crcTable = _makeCrcTable();

Uint32List _makeCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c & 0xFFFFFFFF;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List _chunk(String type, List<int> data) {
  final b = BytesBuilder();
  void w32(int v) {
    b.addByte((v >> 24) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte(v & 0xFF);
  }

  w32(data.length);
  final typeBytes = type.codeUnits;
  b.add(typeBytes);
  b.add(data);
  w32(_crc32([...typeBytes, ...data]));
  return b.toBytes();
}

Uint8List encodePng(Uint8List rgba, int size) {
  final raw = Uint8List(size * (size * 4 + 1));
  for (var y = 0; y < size; y++) {
    final rowStart = y * (size * 4 + 1);
    raw[rowStart] = 0; // filter: none
    raw.setRange(rowStart + 1, rowStart + 1 + size * 4, rgba, y * size * 4);
  }
  final idat = zlib.encode(raw);

  final ihdr = BytesBuilder();
  void w32(int v) {
    ihdr.addByte((v >> 24) & 0xFF);
    ihdr.addByte((v >> 16) & 0xFF);
    ihdr.addByte((v >> 8) & 0xFF);
    ihdr.addByte(v & 0xFF);
  }

  w32(size);
  w32(size);
  ihdr.addByte(8); // bit depth
  ihdr.addByte(6); // RGBA
  ihdr.addByte(0); // compression
  ihdr.addByte(0); // filter
  ihdr.addByte(0); // interlace

  final png = BytesBuilder();
  png.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  png.add(_chunk('IHDR', ihdr.toBytes()));
  png.add(_chunk('IDAT', idat));
  png.add(_chunk('IEND', const []));
  return png.toBytes();
}

Future<void> _write(String path, List<int> bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
  // ignore: avoid_print
  print('written $path (${bytes.length} bytes)');
}

Future<void> main() async {
  final res = 'android/app/src/main/res';

  const legacy = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final e in legacy.entries) {
    final s = e.value;
    await _write('$res/mipmap-${e.key}/ic_launcher.png', encodePng(render(s, 0.80), s));
  }

  // 自适应前景：108dp 画布，图案收进 66dp 安全区（0.56 ≈ 61%×0.92）
  const adaptive = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  for (final e in adaptive.entries) {
    final s = e.value;
    await _write('$res/mipmap-${e.key}/ic_launcher_foreground.png',
        encodePng(render(s, 0.56, opaqueBg: false), s));
  }

  const adaptiveXml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''';
  await _write('$res/mipmap-anydpi-v26/ic_launcher.xml', adaptiveXml.codeUnits);
  await _write(
      '$res/mipmap-anydpi-v26/ic_launcher_round.xml', adaptiveXml.codeUnits);
  await _write(
      '$res/values/ic_launcher_background.xml',
      '<resources><color name="ic_launcher_background">#14212D</color></resources>'
          .codeUnits);
  // ignore: avoid_print
  print('done');
}
