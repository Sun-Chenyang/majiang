import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/meld_advice.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/ting.dart';

import 'test_util.dart';

MeldAdvice meldOf(List<String> tiles,
        {Set<int> honorMelds = const {}, WinContext ctx = WinContext.defaults}) =>
    computeMeldAdvice(
        HandState(hand(tiles), honorMelds),
        computeUkeire(HandState(hand(tiles), honorMelds), ctx),
        ctx);

void main() {
  group('碰：向听数下降 → 推荐', () {
    test('孤对碰出后补齐面子，1 向听 → 听牌', () {
      // 中中 456筒 789筒 123条 4条 9条（13 张）：
      //  当前 1 向听；碰中 → 打浮张 4条/9条 → 单钓听牌（0 向听）
      final a = meldOf([
        '中', '中', //
        '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '4条', '9条',
      ]);
      expect(a.currentShanten, 1);
      final peng = a.options
          .singleWhere((o) => !o.isGang && o.tile == parseTile('中'));
      expect(peng.shantenAfter, 0);
      expect(peng.discard, isIn([parseTile('4条'), parseTile('9条')]));
      expect(isRecommendedOption(peng, a), isTrue);
      expect(isWorthShowing(peng, a), isTrue);
    });

    test('碰字牌并入 honorMelds：第 4 张剩余张数按 4 见扣减', () {
      // 中中中 123筒 456筒 789条 白（13 张）：
      //  当前听牌单钓白（剩 3）；碰中 → 打中 → 仍听白（剩 3）。
      //  若打白改钓中，则中已见 4 张（碰 3 + 手 1）→ 剩 0，排序必选前者。
      final a = meldOf([
        '中', '中', '中', //
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '白',
      ]);
      expect(a.currentShanten, 0);
      expect(a.currentUkeireKinds, 1); // 单钓白
      final peng = a.options
          .singleWhere((o) => !o.isGang && o.tile == parseTile('中'));
      expect(peng.shantenAfter, 0);
      // 打中听白（剩 3）优于打白钓中（已见 4，剩 0）
      expect(peng.discard, parseTile('中'));
      expect(peng.totalRemain, 3);
      expect(isRecommendedOption(peng, a), isFalse); // 持平且进张不多
    });
  });

  group('破坏前提标注（FR7.3）', () {
    test('七对听牌：碰后七对作废且掉向听 → 破坏听牌', () {
      // 11筒44筒77筒11条44条77条9筒（13 张）：纯对子手牌，
      // 七对 0 向听（听 9筒）；标准型 3 向听。碰任意对子 →
      // 七对系全灭，标准型约 2 向听。
      final a = meldOf([
        '1筒', '1筒', '4筒', '4筒', '7筒', '7筒', //
        '1条', '1条', '4条', '4条', '7条', '7条', '9筒',
      ]);
      expect(a.currentShanten, 0);
      expect(a.currentUkeireKinds, 1); // 听 9筒
      final peng = a.options
          .singleWhere((o) => !o.isGang && o.tile == parseTile('1筒'));
      expect(peng.shantenAfter, greaterThan(0));
      expect(peng.breaksTenpai, isTrue);
      expect(peng.killsSevenPairs, isTrue);
      expect(isRecommendedOption(peng, a), isFalse);
      expect(isWorthShowing(peng, a), isTrue); // 听牌态警告必须展示
    });

    test('有副露时不存在七对路线，不作废标注', () {
      // 10 张（1 组副露）：碰不改变"无七对"事实
      final a = meldOf([
        '中', '中', '5筒', '5筒', //
        '1筒', '2筒', '3筒', '7条', '8条', '9条',
      ]);
      for (final o in a.options) {
        expect(o.killsSevenPairs, isFalse);
      }
    });
  });

  group('明杠：补摸后回待摸态', () {
    test('杠中 → 补摸态仍听牌，无切牌建议', () {
      // 中中中 123筒 456筒 789条 白：杠中 → 10 张待摸，仍单钓白
      final a = meldOf([
        '中', '中', '中', //
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '白',
      ]);
      final gang = a.options
          .singleWhere((o) => o.isGang && o.tile == parseTile('中'));
      expect(gang.discard, isNull);
      expect(gang.shantenAfter, 0);
      expect(gang.ukeireKinds, 1);
      expect(gang.totalRemain, 3);
      // 向听持平：明杠作为参考项展示（杠上开花机会在牌外）
      expect(isWorthShowing(gang, a), isTrue);
      expect(isRecommendedOption(gang, a), isFalse);
    });

    test('手中 2 张只模拟碰、3 张同时模拟碰与杠', () {
      final withPair = meldOf(['中', '中', '1筒', '2筒', '3筒']);
      expect(
          withPair.options.where((o) => o.tile == parseTile('中')).map((o) => o.isGang),
          [false]);

      final withTriplet = meldOf([
        '中', '中', '中', //
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '白',
      ]);
      expect(
          withTriplet.options
              .where((o) => o.tile == parseTile('中'))
              .map((o) => o.isGang)
              .toSet(),
          {false, true});
    });
  });

  group('边界', () {
    test('无对子无可鸣牌 → options 为空', () {
      // 1 张（4 组副露满）单钓：无碰杠可模拟
      final a = meldOf(['白']);
      expect(a.options, isEmpty);
      expect(a.currentShanten, 0); // 单钓听牌
    });

    test('排序：向听数升序 → 进张降序 → 碰先于杠', () {
      final a = meldOf([
        '中', '中', '中', //
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '白',
      ]);
      for (var i = 1; i < a.options.length; i++) {
        final p = a.options[i - 1], q = a.options[i];
        expect(p.shantenAfter, lessThanOrEqualTo(q.shantenAfter));
        if (p.shantenAfter == q.shantenAfter && p.tile == q.tile) {
          expect(p.isGang, isFalse);
        }
      }
    });
  });
}
