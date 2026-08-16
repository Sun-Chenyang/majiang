import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/engine.dart';
import 'package:kawuxing/core/win.dart';

import 'test_util.dart';

export 'test_util.dart' show describeHand;

void main() {
  group('decompose 基础判定', () {
    test('标准型胡牌产出唯一分解', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '5条',
      ]);
      final structs = decompose(c);
      expect(structs, hasLength(1));
      expect(structs.first.pair, parseTile('5条'));
      expect(structs.first.melds, hasLength(4));
    });

    test('未胡返回空', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '6条',
      ]);
      expect(decompose(c), isEmpty);
    });

    test('字牌只可刻子/雀头', () {
      final c = hand(['中', '发', '白', '白', '白']);
      expect(decompose(c), isEmpty);
      final d = hand(['中', '中', '发', '发', '发']);
      final structs = decompose(d);
      expect(structs, hasLength(1));
      expect(structs.first.pair, parseTile('中'));
    });

    test('龙七对：4 张同牌产出七对形态', () {
      final c = hand([
        '1筒', '1筒', '1筒', '1筒', //
        '3条', '3条', '5条', '5条', '7条', '7条', '9条', '9条', '中', '中',
      ]);
      final structs = decompose(c);
      expect(structs.any((s) => s.isSevenPairs), isTrue);
    });

    test('副露省录：11 张（1 组副露）分解为雀头 + 3 面子', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '3条', '5条', '5条',
      ]);
      final structs = decompose(c);
      expect(structs, hasLength(1));
      expect(structs.first.melds, hasLength(3));
    });
  });

  group('decompose 多分解枚举', () {
    test('222333444+55筒+678条：三种分解并存', () {
      final c = hand([
        '2筒', '2筒', '2筒', '3筒', '3筒', '3筒', '4筒', '4筒', '4筒', //
        '5筒', '5筒', '6条', '7条', '8条',
      ]);
      final structs = decompose(c);
      // {222,333,444,678}、{234,234,234,678}（雀头 5筒5筒）
      // 与 {234,345,345,678}（雀头 2筒2筒）
      expect(structs, hasLength(3));
      final meldSets = structs.map((s) => s.melds.toSet()).toSet();
      expect(meldSets, hasLength(3));
    });

    test('11223344556677：七对形态与多个标准型分解并存', () {
      final c = handKinds([0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]);
      final structs = decompose(c);
      expect(structs.any((s) => s.isSevenPairs), isTrue);
      expect(structs.where((s) => !s.isSevenPairs).length, greaterThanOrEqualTo(2));
    });
  });

  group('与旧引擎一致性（随机）', () {
    test('decompose 非空 ⟺ Engine.canWin（随机 5000 组 3n+2 张）', () {
      final rng = Random(42);
      for (final total in [2, 5, 8, 11, 14]) {
        for (var i = 0; i < 1000; i++) {
          final c = randomHand(rng, total);
          final win = decompose(c).isNotEmpty;
          expect(win, Engine.canWin(c),
              reason: 'total=$total hand=${describeHand(c)}');
        }
      }
    });
  });
}
