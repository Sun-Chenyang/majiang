import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/advice.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/rules_config.dart';

import 'test_util.dart';

DiscardAdvice adviceOf(List<String> tiles14, {Set<int> honorMelds = const {}}) =>
    rankDiscards(HandState(hand(tiles14), honorMelds),
        WinContext.defaults);

void main() {
  group('排序键 (shanten, totalRemain)', () {
    test('经典决策：打孤张进听 > 拆搭子（向听数优先）', () {
      // 123筒456筒789条 12条 55条 白：打白 → 听 3条；其余打法均一向听
      final a = adviceOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '1条', '2条', '5条', '5条', '白',
      ]);
      expect(a.options.first.discard, parseTile('白'));
      expect(a.options.first.shanten, 0);
      expect(a.options.first.ukeire.accepted.map((x) => x.tile),
          [parseTile('3条')]);
    });

    test('同为听牌：多面听（12 张）排在单钓（4 张）前', () {
      // 123筒456筒789筒 4555条 白：打白 → 听 3/4/6条（12 张）；
      // 打4条 → 555条 + 单钓白（4 张）
      final a = adviceOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '4条', '5条', '5条', '5条', '白',
      ]);
      final first = a.options.first;
      expect(first.tenpai, isTrue);
      expect(first.ukeire.accepted.map((x) => x.tile).toSet(),
          {parseTile('3条'), parseTile('4条'), parseTile('6条')});
      expect(first.totalRemain, 11); // 3条/6条 各 4 张 + 4条 剩 3（手里 1 张）
      final single = a.options
          .firstWhere((o) => o.discard == parseTile('4条'));
      expect(single.tenpai, isTrue);
      expect(single.ukeire.accepted.map((x) => x.tile), [parseTile('白')]);
      expect(single.totalRemain, 3); // 手里已有 1 张白
      // 单钓候选排在多面听之后
      expect(a.options.indexOf(single), greaterThan(0));
    });

    test('全部展示不裁决：候选数 = 不同牌种数，向听数单调不减', () {
      final a = adviceOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '1条', '2条', '5条', '5条', '白',
      ]);
      expect(a.options, hasLength(13));
      for (var i = 1; i < a.options.length; i++) {
        expect(a.options[i].shanten,
            greaterThanOrEqualTo(a.options[i - 1].shanten));
      }
    });
  });

  group('番型加权与损失提示', () {
    test('★打这张损失 ×N 番：听七对(×4) 较 听龙七对(×16) 损失 ×4', () {
      // 中中中 11筒 33筒 55筒 77条 99条 白（14 张）：
      //  打白 → 听中（龙七对 ×16，剩 1 张）；打中 → 听白（七对 ×4，剩 4 张）
      final a = adviceOf([
        '中', '中', '中', '1筒', '1筒', '3筒', '3筒', //
        '5筒', '5筒', '7条', '7条', '9条', '9条', '白',
      ]);
      final bai = a.options.firstWhere((o) => o.discard == parseTile('白'));
      expect(bai.tenpai, isTrue);
      expect(bai.ukeire.accepted.map((x) => x.tile), [parseTile('中')]);
      expect(bai.bestFanMultiplier, 16);
      expect(a.lossHints[parseTile('白')], isNull); // 最优番型无损失

      final zhong = a.options.firstWhere((o) => o.discard == parseTile('中'));
      expect(zhong.tenpai, isTrue);
      expect(zhong.ukeire.accepted.map((x) => x.tile), [parseTile('白')]);
      expect(zhong.bestFanMultiplier, 4);
      expect(a.lossHints[parseTile('中')], 4); // "打中 损失 ×4 番"
    });

    test('非听牌候选不计损失', () {
      final a = adviceOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '1条', '2条', '5条', '5条', '白',
      ]);
      for (final o in a.options.where((o) => !o.tenpai)) {
        expect(a.lossHints.containsKey(o.discard), isFalse);
      }
    });
  });

  group('省录副露下的建议', () {
    test('11 张（1 组副露）：最优候选可达听牌', () {
      final a = adviceOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '5条', '5条', '9条',
      ]);
      expect(a.options, isNotEmpty);
      expect(a.options.first.tenpai, isTrue); // 打 9条 → 听 3条
    });
  });
}
