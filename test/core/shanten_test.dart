import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/engine.dart';
import 'package:kawuxing/core/shanten.dart';

import 'test_util.dart';

void main() {
  group('定义性用例：已胡（−1）', () {
    test('标准型 4 面子 + 雀头', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '5条', '5条',
      ]);
      expect(calculateShanten(c, 0), -1);
    });

    test('刻子型：111 + 234 + 567筒 + 88条 + 999条', () {
      final c = hand([
        '1筒', '1筒', '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', //
        '8条', '8条', '9条', '9条', '9条',
      ]);
      expect(calculateShanten(c, 0), -1);
    });

    test('七对', () {
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', '7筒', '7筒', //
        '9筒', '9筒', '中', '中', '发', '发',
      ]);
      expect(calculateShanten(c, 0), -1);
    });

    test('龙七对：1筒×4 + 4 对', () {
      final c = hand([
        '1筒', '1筒', '1筒', '1筒', //
        '3条', '3条', '5条', '5条', '7条', '7条', '9条', '9条', '中', '中',
      ]);
      expect(calculateShanten(c, 0), -1);
    });

    test('省录：2 张对子 + 4 组副露 = 已胡', () {
      final c = hand(['5筒', '5筒']);
      expect(calculateShanten(c, 4), -1);
    });

    test('★省录：1 张孤牌 + 4 组副露 = 单钓听牌（3n+1 的 n=0）', () {
      final c = hand(['5条']);
      expect(calculateShanten(c, 4), 0);
    });
  });

  group('定义性用例：听牌（0）', () {
    test('单钓将', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '5条',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('面子 + 两面搭 + 雀头', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '5条', '5条',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('卡五星形态：4筒 6筒 夹 5筒', () {
      final c = hand([
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', '4筒', '6筒', //
        '1条', '2条', '3条', '5条', '5条',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('七对听牌：6 对 + 1 孤张', () {
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', '7筒', '7筒', //
        '9筒', '9筒', '中', '中', '发',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('★龙七对定制：1筒×4 + 4 对 + 1 孤张 = 听牌（日麻公式给 2）', () {
      // pairs = 2(1筒龙) + 4 = 6 → 6 − 6 = 0（听中成对 → 龙七对）
      final c = hand([
        '1筒', '1筒', '1筒', '1筒', //
        '3条', '3条', '5条', '5条', '7条', '7条', '9条', '9条', '中',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('★刻子升级定制：中中中 + 5 对 = 听牌（对拍抓出的日麻公式反例）', () {
      // 摸第 4 张中 → 中×4 = 2 对，凑 7 对成胡 → 0
      // （日麻 4 张=1 对，此手只能给 1）
      final c = hand([
        '6筒', '6筒', '9筒', '9筒', '9条', '9条', //
        '中', '中', '中', '发', '发', '白', '白',
      ]);
      expect(calculateShanten(c, 0), 0);
    });

    test('副露：11 张（1 组副露）听牌', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '5条', '5条',
      ]);
      expect(calculateShanten(c, 1), 0);
    });
  });

  group('定义性用例：一向听（1）', () {
    test('3 面子 + 两面搭，无雀头', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '5条', '白',
      ]);
      expect(calculateShanten(c, 0), 1);
    });

    test('字牌对搭：中中 作刻子搭', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '中', '中', '5条', '白',
      ]);
      expect(calculateShanten(c, 0), 1);
    });

    test('七对一向：5 对 + 3 种孤张', () {
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', //
        '7条', '7条', '9条', '9条', '2条', '中', '白',
      ]);
      expect(calculateShanten(c, 0), 1);
    });

    test('★龙一向：1筒×4 + 3 对 + 3 种孤张（日麻会给 2）', () {
      // pairs = 2 + 3 = 5 → 6 − 5 = 1
      final c = hand([
        '1筒', '1筒', '1筒', '1筒', //
        '3条', '3条', '5条', '5条', '7条', '7条', '9条', '中', '白',
      ]);
      expect(calculateShanten(c, 0), 1);
    });

    test('副露：10 张（1 组副露）一向听', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '5条', '中',
      ]);
      expect(calculateShanten(c, 1), 1);
    });
  });

  group('定义性用例：二向听（2）', () {
    test('2 面子 + 2 搭子', () {
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '4条', '5条', '7条', '中', '白',
      ]);
      expect(calculateShanten(c, 0), 2);
    });

    test('★四搭子无雀头修正项：2 面子 + 3 搭子', () {
      // M=2, P=3 → M+P=5 溢出：8 − 4 − 3 + 1 = 2（若无修正项会错算成 1）
      final c = hand([
        '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '4条', '5条', '7条', '8条', '中',
      ]);
      expect(calculateShanten(c, 0), 2);
    });

    test('七对二向：4 对 + 5 种孤张', () {
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', '7筒', '7筒', //
        '9条', '中', '白', '发', '2条',
      ]);
      expect(calculateShanten(c, 0), 2);
    });

    test('副露：7 张（2 组副露）二向听', () {
      final c = hand(['1筒', '2筒', '4条', '5条', '7条', '中', '白']);
      expect(calculateShanten(c, 2), 2);
    });
  });

  group('定义性用例：三向听及以上', () {
    test('2 面子 + 1 字牌对搭 + 全隔离孤张 = 三向听', () {
      // 散张 4筒/7筒/1条/4条 间隔 ≥3 且不同花色，不构成任何搭子；
      // 仅白白一个对搭：M=2, P=1 → 8 − 4 − 1 = 3
      final c = hand([
        '1筒', '2筒', '3筒', '7条', '8条', '9条', //
        '4筒', '7筒', '1条', '4条', '中', '白', '白',
      ]);
      expect(calculateShanten(c, 0), 3);
    });

    test('七对三向：3 对 + 7 种孤张', () {
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', //
        '7条', '9条', '中', '发', '白', '1条', '3条',
      ]);
      expect(calculateShanten(c, 0), 3);
    });

    test('间隔孤张 13 张 = 4 向听（21 种牌下无法全孤立）', () {
      // 1,3,5,7,9 交替排列中 (1,3)(7,9) 等互为嵌张搭：筒/条各 2 搭 → P=4
      // 8 − 0 − 4 = 4（34 种的日麻才有真正 8 向听手牌）
      final c = hand([
        '1筒', '3筒', '5筒', '7筒', '9筒', //
        '1条', '3条', '5条', '7条', '9条', '中', '发', '白',
      ]);
      expect(calculateShanten(c, 0), 4);
    });
  });

  group('副露时七对分支排除', () {
    test('1筒×4 + 3筒×4 + 5筒×2（10 张 + 1 副露）= 听牌', () {
      // 111/333 面子 + 副露 = 3 面子，1筒-3筒 嵌张搭 + 55 雀头 → 8−6−1−1 = 0
      // （摸 2筒 → 123+111+333+副露+55 成胡）
      final c = hand([
        '1筒', '1筒', '1筒', '1筒', //
        '3筒', '3筒', '3筒', '3筒', '5筒', '5筒',
      ]);
      expect(calculateShanten(c, 1), 0);
    });

    test('5 对（10 张 + 1 副露）= 二向听（七对路线已死）', () {
      // 1 组雀头 + 3 对搭（另 1 对升级刻子搭）：8 − 2 − 3 − 1 = 2
      final c = hand([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', //
        '7筒', '7筒', '9筒', '9筒',
      ]);
      expect(calculateShanten(c, 1), 2);
    });
  });

  group('与旧引擎交叉一致性（随机）', () {
    test('14 张：shanten == −1 ⟺ Engine.canWin', () {
      final rng = Random(7);
      for (var i = 0; i < 2000; i++) {
        final c = randomHand(rng, 14);
        final win = calculateShanten(c, 0) == -1;
        expect(win, Engine.canWin(c), reason: 'hand=${describeHand(c)}');
      }
    });

    test('13 张：shanten == 0 ⟺ Engine.hasWait', () {
      final rng = Random(8);
      for (var i = 0; i < 2000; i++) {
        final c = randomHand(rng, 13);
        final tenpai = calculateShanten(c, 0) == 0;
        expect(tenpai, Engine.hasWait(c), reason: 'hand=${describeHand(c)}');
      }
    });

    test('省录各张数：shanten == −1 ⟺ Engine.canWin', () {
      final rng = Random(9);
      for (final total in [2, 5, 8, 11]) {
        final melds = (14 - total) ~/ 3;
        for (var i = 0; i < 500; i++) {
          final c = randomHand(rng, total);
          final win = calculateShanten(c, melds) == -1;
          expect(win, Engine.canWin(c), reason: 'hand=${describeHand(c)}');
        }
      }
    });
  });
}
