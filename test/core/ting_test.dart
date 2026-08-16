import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/fan.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/result.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/ting.dart';

import 'test_util.dart';

UkeireResult ukeireOf(
  List<String> tiles, {
  Set<int> honorMelds = const {},
  WinContext ctx = WinContext.defaults,
}) =>
    computeUkeire(HandState(hand(tiles), honorMelds), ctx);

void main() {
  group('听牌 golden 用例', () {
    test('卡五星：4筒 6筒 夹 5筒，番型含卡五星', () {
      final r = ukeireOf([
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '4筒', '6筒', '1条', '2条', '3条', '5条', '5条',
      ]);
      expect(r.shanten, 0);
      expect(r.accepted.map((a) => a.tile), [parseTile('5筒')]);
      final win = r.accepted.single;
      expect(win.isWin, isTrue);
      expect(win.remain, 4); // 手牌无 5筒，全 4 张未见过
      final hits = win.wins!.first.score.hits.map((h) => h.type);
      expect(hits, contains(FanType.kaWuXing));
    });

    test('两面听：3条/6条', () {
      // 123456789筒 + 45条搭 + 99条雀头：两面等 3/6条
      final r = ukeireOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '4条', '5条', '9条', '9条',
      ]);
      expect(r.shanten, 0);
      expect(r.accepted.map((a) => a.tile).toSet(),
          {parseTile('3条'), parseTile('6条')});
    });

    test('七对听牌：刻子升级定制（中中中 + 5 对 听中）', () {
      final r = ukeireOf([
        '6筒', '6筒', '9筒', '9筒', '9条', '9条', //
        '中', '中', '中', '发', '发', '白', '白',
      ]);
      expect(r.shanten, 0);
      expect(r.accepted.map((a) => a.tile), [parseTile('中')]);
      // 摸第 4 张中 → 龙七对
      final hits = r.accepted.single.wins!.first.score.hits
          .map((h) => h.type);
      expect(hits, contains(FanType.longQiDui));
    });

    test('多分解：22233344 55筒 678条 听 4筒 → 3 种可胡分解', () {
      final r = ukeireOf([
        '2筒', '2筒', '2筒', '3筒', '3筒', '3筒', //
        '4筒', '4筒', '5筒', '5筒', '6条', '7条', '8条',
      ], ctx: const WinContext(selfDraw: true));
      expect(r.shanten, 0);
      final win = r.accepted.firstWhere((a) => a.tile == parseTile('4筒'));
      expect(win.wins, hasLength(3));
      // 自摸下全部可胡（同为屁胡 ×1），并列最优
      expect(win.wins!.first.isBest, isTrue);
    });

    test('屁胡点炮不可胡：胡牌张存在但最优标记只落在可胡分解', () {
      // 纯屁胡手牌点炮（默认 selfDraw=false）→ wins 全部 canWin=false
      final r = ukeireOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条',
      ]);
      expect(r.shanten, 0);
      final win = r.accepted.single;
      expect(win.wins!.every((w) => !w.score.canWin), isTrue);
      expect(win.wins!.every((w) => !w.isBest), isTrue);
    });
  });

  group('进张泛化（n 向听）', () {
    test('一向听：进张 = 使向听数下降的牌', () {
      // M=3 + 12条搭 + 5条/白孤张：进 3条/5条/白 均可到听牌
      final r = ukeireOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '5条', '白',
      ]);
      expect(r.shanten, 1);
      expect(r.accepted.map((a) => a.tile).toSet(),
          {parseTile('3条'), parseTile('5条'), parseTile('白')});
      expect(r.accepted.every((a) => !a.isWin), isTrue);
    });

    test('二向听：进张列表非空且全部使向听数降 1', () {
      final r = ukeireOf([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '4条', '5条', '7条', '中', '白',
      ]);
      expect(r.shanten, 2);
      expect(r.accepted, isNotEmpty);
    });

    test('副露剩余张数扣减：碰出 3 张 + 手 1 张 → remain 0 仍列出', () {
      // 10 张（1 组副露，碰了白）；手里第 4 张白单钓 → 已见 4 张，剩 0
      final r = computeUkeire(
        HandState(
          hand(['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '白']),
          {parseTile('白')},
        ),
        WinContext.defaults,
      );
      expect(r.shanten, 0);
      expect(r.accepted.map((a) => a.tile), [parseTile('白')]);
      expect(r.accepted.single.remain, 0); // 灰化展示，不剔除
    });
  });

  group('analyzeHand 集成', () {
    test('待摸 13 张听牌', () {
      final a = analyzeHand(
        HandState(hand([
          '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
          '4筒', '6筒', '1条', '2条', '3条', '5条', '5条',
        ]), const {}),
        WinContext.defaults,
      );
      expect(a.isTenpai, isTrue);
      expect(a.shanten, 0);
      expect(a.ukeire!.accepted, hasLength(1));
    });

    test('待打 14 张已胡：全分解番型', () {
      final a = analyzeHand(
        HandState(hand([
          '中', '中', '发', '发', '发', '白', '白', '白', //
          '1筒', '2筒', '3筒', '4条', '5条', '6条',
        ]), const {}),
        WinContext.defaults,
      );
      expect(a.isWin, isTrue);
      expect(a.shanten, -1);
      expect(
        a.winStructures.first.score.hits.map((h) => h.type),
        contains(FanType.xiaoSanYuan),
      );
    });

    test('待打 11 张（1 副露）建议 + 三元提示', () {
      final a = analyzeHand(
        HandState(hand([
          '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
          '1条', '2条', '5条', '5条', '9条',
        ]), const {}),
        WinContext.defaults,
      );
      expect(a.drawPhase, isTrue);
      expect(a.meldCount, 1);
      expect(a.advice!.options, isNotEmpty);
      expect(a.notices, contains('三元番型按手牌计算，可标记碰/杠的中发白补全'));
    });

    test('★1 张牌（4 组副露）单钓听牌', () {
      final a = analyzeHand(
        HandState(hand(['5条']), const {}),
        WinContext.defaults,
      );
      expect(a.validPhase, isTrue);
      expect(a.meldCount, 4);
      expect(a.isTenpai, isTrue);
      expect(a.ukeire!.accepted.map((x) => x.tile), [parseTile('5条')]);
      expect(a.ukeire!.accepted.single.wins, isNotNull); // 番型可评估
    });

    test('非法张数', () {
      final a = analyzeHand(
        HandState(hand(['1筒', '2筒', '3筒']), const {}),
        WinContext.defaults,
      );
      expect(a.validPhase, isFalse);
      expect(a.count, 3);
    });
  });
}
