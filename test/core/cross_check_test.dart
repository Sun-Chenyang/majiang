/// 对拍测试（开发计划 M6.4 / 技术方案 §8.1）：防回溯剪枝 bug 的核心手段。
///
/// 暴力枚举器 [bruteForceWin] 刻意采用与主算法完全不同的实现路径
/// （排序牌列表 + sublist 递归 vs 计数数组原址回溯），随机 10 万组
/// 手牌上三方对拍：decompose / Engine.canWin / calculateShanten(−1)。
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/engine.dart';
import 'package:kawuxing/core/shanten.dart';
import 'package:kawuxing/core/tile.dart';
import 'package:kawuxing/core/win.dart';

import 'test_util.dart';

/// 独立暴力胡牌判定（列表式实现，与主算法的计数回溯无共享代码）。
bool bruteForceWin(Uint8List counts) {
  final tiles = <int>[];
  for (var t = 0; t < kTileKindCount; t++) {
    for (var i = 0; i < counts[t]; i++) {
      tiles.add(t);
    }
  }
  if (tiles.length < 2 || (tiles.length - 2) % 3 != 0) return false;

  // 七对：14 张且相邻全部成对
  if (tiles.length == 14) {
    var allPairs = true;
    for (var i = 0; i < 14; i += 2) {
      if (tiles[i] != tiles[i + 1]) {
        allPairs = false;
        break;
      }
    }
    if (allPairs) return true;
  }

  // 枚举雀头（跳过同值重复组合）
  for (var i = 0; i + 1 < tiles.length; i++) {
    if (tiles[i] != tiles[i + 1]) continue;
    final rest = [...tiles]..removeAt(i + 1)..removeAt(i);
    if (_bruteMelds(rest)) return true;
    while (i + 1 < tiles.length && tiles[i] == tiles[i + 1]) {
      i++;
    }
  }
  return false;
}

bool _bruteMelds(List<int> ts) {
  if (ts.isEmpty) return true;
  final first = ts[0];
  if (ts.length >= 3 && ts[1] == first && ts[2] == first) {
    if (_bruteMelds(ts.sublist(3))) return true;
  }
  if (first <= 17 && first % 9 <= 6) {
    final i1 = ts.indexOf(first + 1);
    final i2 = ts.indexOf(first + 2);
    if (i1 > 0 && i2 > 0) {
      final rest = [...ts]
        ..removeAt(i2)
        ..removeAt(i1)
        ..removeAt(0);
      if (_bruteMelds(rest)) return true;
    }
  }
  return false;
}

void main() {
  test('三方对拍：bruteForceWin ⟺ decompose ⟺ canWin ⟺ shanten==−1（14 张 × 7 万）', () {
    final rng = Random(2026);
    var wins = 0;
    for (var i = 0; i < 70000; i++) {
      final c = randomHand(rng, 14);
      final brute = bruteForceWin(c);
      final byDecompose = decompose(c).isNotEmpty;
      final byEngine = Engine.canWin(c);
      final byShanten = calculateShanten(c, 0) == -1;
      if (brute) wins++;
      expect(byDecompose, brute, reason: 'hand=${describeHand(c)}');
      expect(byEngine, brute, reason: 'hand=${describeHand(c)}');
      expect(byShanten, brute, reason: 'hand=${describeHand(c)}');
    }
    // 随机 14 张里胡牌占比极低（构造性手牌见下组）
    expect(wins, lessThan(700));
  });

  test('三方对拍：省录张数（11/8/5/2 张 × 各 1 万）', () {
    final rng = Random(2027);
    for (final total in [11, 8, 5, 2]) {
      final melds = (14 - total) ~/ 3;
      for (var i = 0; i < 10000; i++) {
        final c = randomHand(rng, total);
        final brute = bruteForceWin(c);
        expect(decompose(c).isNotEmpty, brute, reason: 'hand=${describeHand(c)}');
        expect(Engine.canWin(c), brute, reason: 'hand=${describeHand(c)}');
        expect(calculateShanten(c, melds) == -1, brute,
            reason: 'hand=${describeHand(c)}');
      }
    }
  });

  test('构造性已知胡牌：打乱后仍必须被三方识别（1 万组）', () {
    final rng = Random(2028);
    for (var i = 0; i < 10000; i++) {
      final c = _randomWinHand(rng);
      expect(bruteForceWin(c), isTrue);
      expect(decompose(c).isNotEmpty, isTrue, reason: 'hand=${describeHand(c)}');
      expect(Engine.canWin(c), isTrue);
      expect(calculateShanten(c, 0), -1);
    }
  });

  test('听牌对拍：shanten==0 ⟺ hasWait（13 张 × 1 万）', () {
    final rng = Random(2029);
    for (var i = 0; i < 10000; i++) {
      final c = randomHand(rng, 13);
      final tenpai = calculateShanten(c, 0) == 0;
      expect(tenpai, Engine.hasWait(c), reason: 'hand=${describeHand(c)}');
    }
  });
}

/// 构造一把已知必胡的手牌：随机选 4 组面子 + 雀头，或七对形态。
/// 面子/雀头随机堆叠可能使某种牌超过 4 张，此时重摇。
Uint8List _randomWinHand(Random rng) {
  while (true) {
    final c = Uint8List(kTileKindCount);
    if (rng.nextBool()) {
      // 七对：随机凑 7 对（4 张同牌算 2 对）
      var pairs = 0;
      while (pairs < 7) {
        final t = rng.nextInt(kTileKindCount);
        final take = pairs <= 5 && rng.nextBool() ? 2 : 1;
        if (c[t] > 0) continue;
        c[t] = take == 2 ? 4 : 2;
        pairs += take;
      }
      return c; // 七对构造天然合法（每种 2/4 张）
    }
    for (var m = 0; m < 4; m++) {
      if (rng.nextBool()) {
        c[rng.nextInt(kTileKindCount)] += 3; // 刻子
      } else {
        final suit = rng.nextBool() ? 0 : 9;
        final t = suit + rng.nextInt(7); // 顺子最低张（点数 ≤ 7）
        c[t]++;
        c[t + 1]++;
        c[t + 2]++;
      }
    }
    c[rng.nextInt(kTileKindCount)] += 2; // 雀头
    var legal = true;
    for (final v in c) {
      if (v > 4) legal = false;
    }
    if (legal) return c;
  }
}
