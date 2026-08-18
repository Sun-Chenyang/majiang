/// 裁剪 PNG（视觉验收辅助）：解码 → 裁剪区域 → 可选放大 → 输出。
/// 运行：dart run tool/crop_png.dart 输入.png 输出.png x y w h [scale]
library;

import 'dart:io';
import 'dart:typed_data';

import 'gen_icon.dart' show encodePng;
import 'make_icon_from_image.dart' show decodePng;

Future<void> main(List<String> args) async {
  final inPath = args[0];
  final outPath = args[1];
  final x = int.parse(args[2]);
  final y = int.parse(args[3]);
  final w = int.parse(args[4]);
  final h = int.parse(args[5]);
  final scale = args.length > 6 ? int.parse(args[6]) : 1;

  final img = decodePng(File(inPath).readAsBytesSync());
  final cw = w * scale;
  final ch = h * scale;
  final out = Uint8List(cw * ch * 4);
  for (var yy = 0; yy < ch; yy++) {
    final sy = y + yy ~/ scale;
    for (var xx = 0; xx < cw; xx++) {
      final sx = x + xx ~/ scale;
      final s = (sy * img.width + sx) * 4;
      final d = (yy * cw + xx) * 4;
      out[d] = img.rgba[s];
      out[d + 1] = img.rgba[s + 1];
      out[d + 2] = img.rgba[s + 2];
      out[d + 3] = 255; // 桌面截图无透明，压平便于查看
    }
  }
  await File(outPath).writeAsBytes(encodePng(out, cw));
  // ignore: avoid_print
  print('cropped $w x $h @$x,$y -> $cw x $ch $outPath');
}
