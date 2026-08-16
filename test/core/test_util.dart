/// 算法测试共享工具：手牌字符串构造 + 随机手牌生成（固定种子可复现）。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:kawuxing/core/tile.dart';

/// 构造暗牌计数：['1筒','1筒','2条','中'] → 长 21 计数。
Uint8List hand(List<String> tiles) {
  final c = Uint8List(kTileKindCount);
  for (final s in tiles) {
    c[parseTile(s)]++;
  }
  return c;
}

/// 直接用牌种编码构造。
Uint8List handKinds(List<int> kinds) {
  final c = Uint8List(kTileKindCount);
  for (final t in kinds) {
    c[t]++;
  }
  return c;
}

/// "中"/"发"/"白" → 18/19/20；"5筒" → 4；"5条" → 13。
int parseTile(String s) {
  if (s == '中') return 18;
  if (s == '发') return 19;
  if (s == '白') return 20;
  final rank = int.parse(s.substring(0, 1));
  return s.endsWith('筒') ? rank - 1 : 8 + rank;
}

/// 随机生成合计 [total] 张的合法计数（每种 ≤ 4）。
Uint8List randomHand(Random rng, int total) {
  final c = Uint8List(kTileKindCount);
  var n = 0;
  while (n < total) {
    final t = rng.nextInt(kTileKindCount);
    if (c[t] < 4) {
      c[t]++;
      n++;
    }
  }
  return c;
}

/// 调试输出用：手牌描述（断言失败 reason 里展示）。
String describeHand(Uint8List c) {
  final parts = <String>[];
  for (var t = 0; t < kTileKindCount; t++) {
    for (var i = 0; i < c[t]; i++) {
      parts.add(tileName(t));
    }
  }
  return parts.join(' ');
}
