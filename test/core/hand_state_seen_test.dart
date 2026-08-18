/// M8.4 已见牌标记：剩余张数精确化（PRD FR1.6）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/ting.dart';

import 'test_util.dart';

void main() {
  group('HandState 剩余张数扣减', () {
    test('未标记：剩余 = 4 − 手牌 − 字牌副露', () {
      final h = HandState(hand(['5筒', '5筒']), {});
      expect(h.remainCount(parseTile('5筒')), 2);
      expect(h.seenCount(parseTile('5筒')), 2);
    });

    test('标记 2 张后剩余正确扣减（验收标准：标记 2 张）', () {
      final seen = handKinds([4, 4]); // 5筒 ×2 他家弃牌
      final h = HandState(hand(['5筒']), {}, externalSeen: seen);
      expect(h.seenCount(parseTile('5筒')), 3);
      expect(h.remainCount(parseTile('5筒')), 1);
    });

    test('他家碰 +3：与自家持有合并扣减', () {
      final seen = handKinds([18, 18, 18]); // 中 他家碰
      final h = HandState(hand(['中']), {}, externalSeen: seen);
      expect(h.remainCount(parseTile('中')), 0);
    });

    test('他家杠 +4：满见；超出物理上限按 0 展示（钳制）', () {
      final seen = handKinds([19, 19, 19, 19]);
      final h = HandState(hand([]), {}, externalSeen: seen);
      expect(h.remainCount(parseTile('发')), 0);
      // 病态标记（自家 2 + 他家 4 = 6 见）：钳制为 0，不为负
      final bad = HandState(hand(['白', '白']), {}, externalSeen: handKinds([20, 20, 20, 20]));
      expect(bad.remainCount(parseTile('白')), 0);
    });

    test('honorMelds 与 externalSeen 同时计入', () {
      // 自家碰白（+3）+ 他家又弃白（+1）→ 见 4
      final h = HandState(
        hand([]),
        {parseTile('白')},
        externalSeen: handKinds([20]),
      );
      expect(h.seenCount(parseTile('白')), 4);
      expect(h.remainCount(parseTile('白')), 0);
    });
  });

  group('进张剩余张数精确化（computeUkeire 流入）', () {
    test('听牌卡剩余张数随标记下降，标记满 4 仍列出（灰化交给 UI）', () {
      // 123筒 789筒 4筒 6筒 123条 55条（13 张）：听 5筒
      final base = hand([
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '4筒', '6筒', '1条', '2条', '3条', '5条', '5条',
      ]);

      final plain = computeUkeire(HandState(base, {}), WinContext.defaults);
      final wait = plain.accepted.single;
      expect(wait.tile, parseTile('5筒'));
      expect(wait.remain, 4); // 5筒 一张未见于自家

      final seen2 = computeUkeire(
        HandState(base, {}, externalSeen: handKinds([4, 4])),
        WinContext.defaults,
      );
      expect(seen2.accepted.single.remain, 2); // 他家弃过 2 张

      final seen4 = computeUkeire(
        HandState(base, {}, externalSeen: handKinds([4, 4, 4, 4])),
        WinContext.defaults,
      );
      expect(seen4.accepted.single.remain, 0); // 已见 4 张仍列出
      expect(seen4.totalRemain, 0);
    });
  });
}
