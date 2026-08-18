/// 从指定 PNG 图片生成应用图标（M9.3 图片版）。
///
/// 与 gen_icon.dart（自绘方案）并列：本工具把用户提供的图片做成
///  - legacy mipmap-*/ic_launcher.png（48~192，透明像素填背景色）
///  - 自适应前景 mipmap-*/ic_launcher_foreground.png（整图铺满 108dp
///    画布，保留透明边角；遮罩裁圆后露出的外圈由背景层补）
///  - values/ic_launcher_background.xml（取图片边缘平均色，视觉无缝）
///
/// 缩放用箱式滤波（区域平均，alpha 预乘，透明区颜色不污染）。
/// 运行：dart run tool/make_icon_from_image.dart <源图.png>
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'gen_icon.dart' show encodePng;

// ---------------- PNG 解码（8bit，色彩类型 0/2/3/4/6） ----------------

class DecodedImage {
  final int width, height;
  final Uint8List rgba; // RGBA8
  const DecodedImage(this.width, this.height, this.rgba);
}

DecodedImage decodePng(Uint8List bytes) {
  var pos = 8;
  var width = 0, height = 0, colorType = 0;
  final idat = BytesBuilder();
  var palette = <int>[];
  var trns = <int>[];
  while (pos < bytes.length) {
    int be32(int o) =>
        (bytes[pos + o] << 24) |
            (bytes[pos + o + 1] << 16) |
            (bytes[pos + o + 2] << 8) |
            bytes[pos + o + 3];
    final len = be32(0);
    final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
    final dataStart = pos + 8;
    if (type == 'IHDR') {
      width = be32(8);
      height = be32(12);
      if (bytes[dataStart + 8] != 8) throw '仅支持 8bit PNG';
      colorType = bytes[dataStart + 9];
    } else if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(bytes, dataStart, dataStart + len));
    } else if (type == 'PLTE') {
      palette = bytes.sublist(dataStart, dataStart + len);
    } else if (type == 'tRNS') {
      trns = bytes.sublist(dataStart, dataStart + len);
    }
    pos = dataStart + len + 4; // +CRC
  }

  final raw = Uint8List.fromList(ZLibCodec().decode(idat.toBytes()));
  final channels = switch (colorType) {
    0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4, _ => throw '不支持的 colorType',
  };
  final bpp = channels;
  final stride = width * bpp;
  final pixels = Uint8List(width * height * 4);
  var prev = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final filter = raw[y * (stride + 1)];
    final line = Uint8List.sublistView(
        raw, y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (var x = 0; x < stride; x++) {
      final a = x >= bpp ? line[x - bpp] : 0;
      final b = prev[x];
      final c = x >= bpp ? prev[x - bpp] : 0;
      switch (filter) {
        case 0:
          break;
        case 1:
          line[x] = (line[x] + a) & 0xFF;
        case 2:
          line[x] = (line[x] + b) & 0xFF;
        case 3:
          line[x] = (line[x] + ((a + b) >> 1)) & 0xFF;
        case 4:
          final p = a + b - c;
          final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
          final pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
          line[x] = (line[x] + pr) & 0xFF;
        default:
          throw 'bad filter $filter';
      }
    }
    for (var x = 0; x < width; x++) {
      final o = x * bpp;
      final i = (y * width + x) * 4;
      switch (colorType) {
        case 6:
          pixels[i] = line[o];
          pixels[i + 1] = line[o + 1];
          pixels[i + 2] = line[o + 2];
          pixels[i + 3] = line[o + 3];
        case 2:
          pixels[i] = line[o];
          pixels[i + 1] = line[o + 1];
          pixels[i + 2] = line[o + 2];
          pixels[i + 3] = 255;
        case 3:
          final idx = line[o];
          pixels[i] = palette[idx * 3];
          pixels[i + 1] = palette[idx * 3 + 1];
          pixels[i + 2] = palette[idx * 3 + 2];
          pixels[i + 3] = idx < trns.length ? trns[idx] : 255;
        case 4:
          pixels[i] = pixels[i + 1] = pixels[i + 2] = line[o];
          pixels[i + 3] = line[o + 1];
        case 0:
          pixels[i] = pixels[i + 1] = pixels[i + 2] = line[o];
          pixels[i + 3] = 255;
      }
    }
    prev = line;
  }
  return DecodedImage(width, height, pixels);
}

// ---------------- 箱式缩放（alpha 预乘） ----------------

Uint8List resizeBox(DecodedImage src, int dw, int dh) {
  final sw = src.width, sh = src.height;
  final out = Uint8List(dw * dh * 4);
  final sx = sw / dw, sy = sh / dh;
  for (var y = 0; y < dh; y++) {
    final y0 = (y * sy).floor();
    final y1 = math.min(((y + 1) * sy).ceil(), sh);
    for (var x = 0; x < dw; x++) {
      final x0 = (x * sx).floor();
      final x1 = math.min(((x + 1) * sx).ceil(), sw);
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          final i = (yy * sw + xx) * 4;
          final al = src.rgba[i + 3] / 255.0;
          r += src.rgba[i] * al;
          g += src.rgba[i + 1] * al;
          b += src.rgba[i + 2] * al;
          a += al;
        }
      }
      final n = (y1 - y0) * (x1 - x0);
      final o = (y * dw + x) * 4;
      if (a <= 0) {
        out[o + 3] = 0; // 全透明区：颜色置 0，避免黑边
      } else {
        out[o] = (r / a).round();
        out[o + 1] = (g / a).round();
        out[o + 2] = (b / a).round();
        out[o + 3] = ((a / n) * 255).round();
      }
    }
  }
  return out;
}

// ---------------- 主流程 ----------------

Future<void> main(List<String> args) async {
  final srcPath = args.isNotEmpty ? args[0] : 'icon.png';
  final src = decodePng(File(srcPath).readAsBytesSync());
  // ignore: avoid_print
  print('source: $srcPath ${src.width}x${src.height}');

  // 边缘平均色（一圈 2% 边框内的不透明像素）→ 背景层色
  var r = 0, g = 0, b = 0, n = 0;
  final m = (math.min(src.width, src.height) * 0.02).ceil();
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final edge = x < m || y < m || x >= src.width - m || y >= src.height - m;
      if (!edge) continue;
      final i = (y * src.width + x) * 4;
      if (src.rgba[i + 3] < 128) continue;
      r += src.rgba[i];
      g += src.rgba[i + 1];
      b += src.rgba[i + 2];
      n++;
    }
  }
  if (n == 0) n = 1;
  final bgR = r ~/ n, bgG = g ~/ n, bgB = b ~/ n;
  final bgHex =
      '#${[bgR, bgG, bgB].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  // ignore: avoid_print
  print('edge-average background: $bgHex');

  final res = 'android/app/src/main/res';

  // legacy：整图缩放，透明像素填背景色（无黑角）
  const legacy = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
  };
  for (final e in legacy.entries) {
    final s = e.value;
    final px = resizeBox(src, s, s);
    for (var i = 0; i < s * s; i++) {
      if (px[i * 4 + 3] < 8) {
        px[i * 4] = bgR;
        px[i * 4 + 1] = bgG;
        px[i * 4 + 2] = bgB;
        px[i * 4 + 3] = 255;
      }
    }
    final f = File('$res/mipmap-${e.key}/ic_launcher.png');
    await f.writeAsBytes(encodePng(px, s));
    // ignore: avoid_print
    print('written ${f.path}');
  }

  // 自适应前景：满幅不透明（图案 + 背景色填充透明角），缩放由
  // adaptive-icon XML 的 <inset android:inset="16%"> 承担（参考
  // plant_assistant 的结构：内容等效占画布 68%，边缘是图案自带底色，
  // 任何遮罩下无断层）。资源放 drawable-（与参考项目一致）。
  const adaptive = {
    'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432,
  };
  for (final e in adaptive.entries) {
    final s = e.value;
    final px = resizeBox(src, s, s);
    for (var i = 0; i < s * s; i++) {
      if (px[i * 4 + 3] < 8) {
        px[i * 4] = bgR;
        px[i * 4 + 1] = bgG;
        px[i * 4 + 2] = bgB;
        px[i * 4 + 3] = 255;
      }
    }
    final f = File('$res/drawable-${e.key}/ic_launcher_foreground.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(encodePng(px, s));
    // ignore: avoid_print
    print('written ${f.path}');
    // 旧位置清理：先前版本放在 mipmap-，避免重复资源
    final stale = File('$res/mipmap-${e.key}/ic_launcher_foreground.png');
    if (await stale.exists()) await stale.delete();
  }

  // 自适应图标 XML：inset 16% 缩前景（参考项目同款结构）
  const adaptiveXml = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="16%" />
  </foreground>
</adaptive-icon>
''';
  await File('$res/mipmap-anydpi-v26/ic_launcher.xml')
      .writeAsString(adaptiveXml);
  await File('$res/mipmap-anydpi-v26/ic_launcher_round.xml')
      .writeAsString(adaptiveXml);
  // ignore: avoid_print
  print('written adaptive-icon xml (inset 16%) x2');

  final bgFile = File('$res/values/ic_launcher_background.xml');
  await bgFile.writeAsString(
      '<resources><color name="ic_launcher_background">$bgHex</color></resources>');
  // ignore: avoid_print
  print('written ${bgFile.path}');
  // ignore: avoid_print
  print('done');
}
