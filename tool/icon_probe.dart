/// PNG 解码诊断：读取图片四角/边缘/中心的颜色与 alpha，
/// 决定图标生成的背景层方案。运行：dart run tool/icon_probe.dart 路径.png
library;

import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'icon.png';
  final bytes = File(path).readAsBytesSync();

  // ---- 解析 chunk ----
  var pos = 8;
  var width = 0, height = 0, bitDepth = 0, colorType = 0;
  final idat = BytesBuilder();
  var palette = <int>[];
  var trns = <int>[];
  while (pos < bytes.length) {
    int be32(int o) =>
        (bytes[pos + o] << 24) | (bytes[pos + o + 1] << 16) |
        (bytes[pos + o + 2] << 8) | bytes[pos + o + 3];
    final len = be32(0);
    final type = String.fromCharCodes(bytes, pos + 4, pos + 8);
    final dataStart = pos + 8;
    if (type == 'IHDR') {
      width = be32(8);
      height = be32(12);
      bitDepth = bytes[dataStart + 8];
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
  // ignore: avoid_print
  // ignore: avoid_print
  print('size=$width x $height bitDepth=$bitDepth colorType=$colorType');

  // ---- inflate + 反滤波（仅支持 8bit 的 0/2/3/4/6 色彩类型）----
  final raw = Uint8List.fromList(ZLibCodec().decode(idat.toBytes()));
  final channels = switch (colorType) {
    0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4, _ => throw 'unsupported colorType',
  };
  final bpp = channels; // 8bit
  final stride = width * bpp;
  final pixels = Uint8List(width * height * 4); // RGBA
  var prev = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final filter = raw[y * (stride + 1)];
    final line = Uint8List.sublistView(raw, y * (stride + 1) + 1, (y + 1) * (stride + 1));
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

  // ---- 诊断采样 ----
  int px(int x, int y) => (y * width + x) * 4;
  String at(int x, int y) {
    final i = px(x, y);
    return '(${pixels[i]},${pixels[i + 1]},${pixels[i + 2]},${pixels[i + 3]})';
  }

  // ignore: avoid_print
  // ignore: avoid_print
  print('corners: TL${at(2, 2)} TR${at(width - 3, 2)} BL${at(2, height - 3)} BR${at(width - 3, height - 3)}');
  // ignore: avoid_print
  // ignore: avoid_print
  print('edge mids: T${at(width ~/ 2, 2)} B${at(width ~/ 2, height - 3)} L${at(2, height ~/ 2)} R${at(width - 3, height ~/ 2)}');
  // ignore: avoid_print
  // ignore: avoid_print
  print('center: ${at(width ~/ 2, height ~/ 2)}');

  // alpha 直方图 + 不透明区域 bounding box
  var transparent = 0, semi = 0, opaque = 0;
  var minX = width, minY = height, maxX = 0, maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final a = pixels[px(x, y) + 3];
      if (a == 0) {
        transparent++;
      } else {
        if (a < 255) semi++;
        if (a >= 32) {
          opaque++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
  }
  // ignore: avoid_print
  // ignore: avoid_print
  print('alpha: transparent=${(transparent * 100 / (width * height)).toStringAsFixed(1)}% '
      'semi=${(semi * 100 / (width * height)).toStringAsFixed(1)}% '
      'opaque>=32=${(opaque * 100 / (width * height)).toStringAsFixed(1)}%');
  // ignore: avoid_print
  // ignore: avoid_print
  print('content bbox: x[$minX,$maxX] y[$minY,$maxY] '
      '(${(maxX - minX + 1)}x${(maxY - minY + 1)}, '
      '占宽${(((maxX - minX + 1) / width) * 100).toStringAsFixed(0)}%)');
}
