import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/engine.dart';
import 'package:kawuxing/core/tile.dart';

/// 构造暗牌计数：kinds 如 ['1筒','1筒','2筒'] 或直接用牌种编码。
Uint8List hand(List<String> tiles) {
  final c = Uint8List(kTileKindCount);
  for (final s in tiles) {
    c[_parse(s)]++;
  }
  return c;
}

int _parse(String s) {
  if (s == '中') return 18;
  if (s == '发') return 19;
  if (s == '白') return 20;
  final rank = int.parse(s.substring(0, 1));
  return s.endsWith('筒') ? rank - 1 : 8 + rank;
}

void main() {
  group('胡牌判定', () {
    test('标准型：4 面子 + 1 对将', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '5条']);
      expect(Engine.canWin(c), isTrue);
    });

    test('标准型：缺将不胡', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '6条']);
      expect(Engine.canWin(c), isFalse);
    });

    test('字牌不可组顺子', () {
      // 中/发/白 各 1 张无法成面子 → 不胡（若字牌可组顺子则会误判为胡）
      final c = hand(['中', '发', '白', '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '5条', '5条']);
      expect(Engine.canWin(c), isFalse);
    });

    test('七对（4 张同牌算 2 对 → 龙七对）', () {
      final c = hand(['1筒', '1筒', '1筒', '1筒', '3条', '3条', '5条', '5条', '7条', '7条', '9条', '9条', '中', '中']);
      expect(Engine.isSevenPairs(c), isTrue);
      expect(Engine.canWin(c), isTrue);
    });
  });

  group('听牌枚举', () {
    test('单钓将', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条']);
      final waits = Engine.waitsOf(c);
      expect(waits, [_parse('5条')]);
    });

    test('两面听', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '1条', '2条', '3条', '4条']);
      final waits = Engine.waitsOf(c)..sort();
      expect(waits, [_parse('1条'), _parse('4条')]);
    });

    test('卡五星：4筒 6筒 夹 5筒', () {
      final c = hand(['1筒', '2筒', '3筒', '7筒', '8筒', '9筒', '4筒', '6筒', '1条', '2条', '3条', '5条', '5条']);
      final r = Engine.analyze(c);
      expect(r.isTenpai, isTrue);
      expect(r.waits.map((w) => w.tile), [kWuXing]);
      expect(r.waits.first.fanLabels, contains('卡五星 ×2'));
    });
  });

  group('整体分析', () {
    test('14 张已胡', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '5条']);
      final r = Engine.analyze(c);
      expect(r.drawPhase, isTrue);
      expect(r.isWin, isTrue);
    });

    test('副露省录：11 张（碰过 1 组）按 3n+2 处理', () {
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '1条', '2条', '3条', '5条', '5条']);
      final r = Engine.analyze(c);
      expect(r.validPhase, isTrue);
      expect(r.drawPhase, isTrue);
      expect(r.meldCount, 1);
    });

    test('差 1 张进听：进张枚举（摸后打出可进听）', () {
      // 123筒 456筒 12条 4555条 中：摸 3条 打 中 → 听 4条
      final c = hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '1条', '2条', '4条', '5条', '5条', '5条', '中']);
      final r = Engine.analyze(c);
      expect(r.isTenpai, isFalse);
      expect(r.oneAway, isTrue);
      expect(r.advances.map((w) => w.tile), contains(_parse('3条')));
    });

    test('非法张数（3 的倍数）', () {
      final r = Engine.analyze(hand(['1筒', '2筒', '3筒']));
      expect(r.validPhase, isFalse);
    });
  });
}
