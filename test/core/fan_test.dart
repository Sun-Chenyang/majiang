import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/fan.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/win.dart';

import 'test_util.dart';

/// 便捷入口：构造 14 张（含胡牌张）→ decompose 取指定形态 → evaluateFan。
FanScore fanOf(
  List<String> tiles14, {
  int winTile = -1,
  WinContext ctx = WinContext.defaults,
  Set<int> honorMelds = const {},
  bool sevenPairs = false,
}) {
  final c = hand(tiles14);
  final structs = decompose(c);
  final structure = sevenPairs
      ? structs.firstWhere((s) => s.isSevenPairs)
      : structs.first;
  return evaluateFan(
    c14: c,
    honorMelds: honorMelds,
    winTile: winTile,
    structure: structure,
    ctx: ctx,
  );
}

List<FanType> typesOf(FanScore s) => s.hits.map((h) => h.type).toList();

void main() {
  group('屁胡与自摸规则（固定：屁胡只能自摸）', () {
    final tiles = [
      '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
      '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '5条',
    ];

    test('自摸屁胡：×1 可胡', () {
      final s = fanOf(tiles, ctx: const WinContext(selfDraw: true));
      expect(typesOf(s), [FanType.pingHu]);
      expect(s.multiplier, 1);
      expect(s.canWin, isTrue);
    });

    test('★点炮屁胡被拒', () {
      final s = fanOf(tiles); // selfDraw = false
      expect(s.canWin, isFalse);
      expect(s.multiplier, 1);
    });

    test('点炮 + 其他番型 → 可胡（屁胡非唯一命中）', () {
      final s = fanOf(tiles, ctx: const WinContext(gangPao: true));
      expect(typesOf(s), containsAll([FanType.gangPao, FanType.pingHu]));
      expect(s.canWin, isTrue);
    });
  });

  group('卡五星（定义固定：4/6 卡张夹 5，筒条同计）', () {
    final tiles = [
      '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
      '4筒', '5筒', '6筒', '1条', '2条', '3条', '5条', '5条',
    ];

    test('筒：胡 5筒 且存在 456筒 顺子', () {
      final s = fanOf(tiles, winTile: parseTile('5筒'));
      expect(typesOf(s), contains(FanType.kaWuXing));
      expect(s.multiplier, 2);
    });

    test('★条子同计（固定）：4条 6条 卡 5条', () {
      final tiles2 = [
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '4条', '5条', '6条', '7条', '7条',
      ];
      final s = fanOf(tiles2, winTile: parseTile('5条'));
      expect(typesOf(s), contains(FanType.kaWuXing));
    });

    test('胡非 5 的牌（9条）→ 不中', () {
      final t2 = [
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '5筒', '5筒', '1条', '2条', '3条', '7条', '8条', '9条',
      ];
      final s = fanOf(t2, winTile: parseTile('9条'));
      expect(typesOf(s), isNot(contains(FanType.kaWuXing)));
    });

    test('胡 5筒 为 345 边张 + 55 雀头 → 不中（须为中间张）', () {
      final t2 = [
        '3筒', '4筒', '5筒', '5筒', '5筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '7条', '8条', '9条',
      ];
      final s = fanOf(t2, winTile: parseTile('5筒'));
      expect(typesOf(s), isNot(contains(FanType.kaWuXing)));
    });
  });

  group('情境番', () {
    final tiles = [
      '1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
      '7筒', '8筒', '9筒', '1条', '2条', '3条', '5条', '5条',
    ];

    test('杠上炮 ×2', () {
      final s = fanOf(tiles, ctx: const WinContext(gangPao: true));
      expect(s.multiplier, 2);
    });

    test('杠上开花需自摸：afterGang 且 selfDraw', () {
      final s = fanOf(tiles,
          ctx: const WinContext(afterGang: true, selfDraw: true));
      expect(typesOf(s), contains(FanType.gangHua));
      final s2 = fanOf(tiles, ctx: const WinContext(afterGang: true));
      expect(typesOf(s2), isNot(contains(FanType.gangHua)));
    });

    test('抢杠 ×2', () {
      final s = fanOf(tiles, ctx: const WinContext(robKong: true));
      expect(typesOf(s), contains(FanType.qiangGang));
      expect(s.multiplier, 2);
    });

    test('★杠上开花 × 七对 = 8（连乘）', () {
      final s = fanOf([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', //
        '7筒', '7筒', '9筒', '9筒', '中', '中', '发', '发',
      ], ctx: const WinContext(afterGang: true, selfDraw: true),
          sevenPairs: true);
      expect(typesOf(s), containsAll([FanType.gangHua, FanType.qiDui]));
      expect(s.multiplier, 8);
    });
  });

  group('三元系', () {
    test('小三元：2 刻 + 雀头为另一字牌', () {
      final s = fanOf([
        '中', '中', '发', '发', '发', '白', '白', '白', //
        '1筒', '2筒', '3筒', '4条', '5条', '6条',
      ]);
      expect(typesOf(s), contains(FanType.xiaoSanYuan));
      expect(s.multiplier, 4);
    });

    test('雀头非字牌的 2 刻 → 不中', () {
      final s = fanOf([
        '发', '发', '发', '白', '白', '白', //
        '1筒', '2筒', '3筒', '4条', '5条', '6条', '5筒', '5筒',
      ]);
      expect(typesOf(s), isNot(contains(FanType.xiaoSanYuan)));
    });

    test('大三元：3 刻 ×8', () {
      final s = fanOf([
        '中', '中', '中', '发', '发', '发', '白', '白', '白', //
        '1筒', '2筒', '3筒', '5条', '5条',
      ]);
      expect(typesOf(s), containsAll([FanType.daSanYuan]));
      expect(typesOf(s), isNot(contains(FanType.xiaoSanYuan)));
      expect(s.multiplier, 8);
    });

    test('★字牌副露标记：暗牌 2 刻 + 副露 1 刻 = 大三元', () {
      // 省录 8 张（2 组副露，其中 1 组为碰白）
      final s = fanOf([
        '中', '中', '中', '发', '发', '发', '1筒', '1筒',
      ], honorMelds: {parseTile('白')}, winTile: -1);
      expect(typesOf(s), contains(FanType.daSanYuan));
      // 未标记时按暗牌算：2 刻 + 非字雀头 → 两个三元番型都不中
      final s2 = fanOf([
        '中', '中', '中', '发', '发', '发', '1筒', '1筒',
      ]);
      expect(typesOf(s2), isNot(contains(FanType.daSanYuan)));
      expect(typesOf(s2), isNot(contains(FanType.xiaoSanYuan)));
    });

    test('★字牌副露标记：暗牌 1 刻 + 字雀头 + 副露 1 刻 = 小三元', () {
      // 省录 8 张（2 组副露，其中 1 组为碰白）
      final s = fanOf([
        '中', '中', '发', '发', '发', '1筒', '2筒', '3筒',
      ], honorMelds: {parseTile('白')}, winTile: -1);
      expect(typesOf(s), contains(FanType.xiaoSanYuan));
      final s2 = fanOf([
        '中', '中', '发', '发', '发', '1筒', '2筒', '3筒',
      ]);
      expect(typesOf(s2), isNot(contains(FanType.xiaoSanYuan)));
    });
  });

  group('暗四归一', () {
    final tiles = [
      '1筒', '1筒', '1筒', '1筒', '2筒', '3筒', //
      '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '5条', '5条',
    ];

    test('3 张在手 + 自摸第 4 张 ×4', () {
      final s = fanOf(tiles,
          winTile: parseTile('1筒'),
          ctx: const WinContext(selfDraw: true));
      expect(typesOf(s), contains(FanType.anSiGuiYi));
      expect(s.multiplier, 4);
    });

    test('点炮摸到第 4 张 → 不中（需自摸）', () {
      final s = fanOf(tiles, winTile: parseTile('1筒'));
      expect(typesOf(s), isNot(contains(FanType.anSiGuiYi)));
    });

    test('4 张在手但非胡牌张 → 不中', () {
      final s = fanOf(tiles,
          winTile: parseTile('5条'), ctx: const WinContext(selfDraw: true));
      expect(typesOf(s), isNot(contains(FanType.anSiGuiYi)));
    });
  });

  group('七对系与互斥', () {
    test('七对 ×4', () {
      final s = fanOf([
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', //
        '7筒', '7筒', '9筒', '9筒', '中', '中', '发', '发',
      ], sevenPairs: true);
      expect(typesOf(s), contains(FanType.qiDui));
      expect(s.multiplier, 4);
    });

    test('龙七对 ×16 不计七对', () {
      final s = fanOf([
        '1筒', '1筒', '1筒', '1筒', //
        '3条', '3条', '5条', '5条', '7条', '7条', '9条', '9条', '中', '中',
      ], sevenPairs: true);
      expect(typesOf(s), contains(FanType.longQiDui));
      expect(typesOf(s), isNot(contains(FanType.qiDui)));
      final hit = s.hits.firstWhere((h) => h.type == FanType.longQiDui);
      expect(hit.swallowed, contains(FanType.qiDui));
      expect(s.multiplier, 16);
    });

    test('双龙七对 ×32 不计七对/龙七对', () {
      final s = fanOf([
        '1筒', '1筒', '1筒', '1筒', '3筒', '3筒', '3筒', '3筒', //
        '5条', '5条', '7条', '7条', '9条', '9条',
      ], sevenPairs: true);
      expect(typesOf(s), contains(FanType.shuangLongQiDui));
      expect(typesOf(s), isNot(contains(FanType.longQiDui)));
      expect(typesOf(s), isNot(contains(FanType.qiDui)));
      expect(s.multiplier, 32);
    });

    test('三龙七对 ×64 不计七对/龙七对/双龙七对', () {
      final s = fanOf([
        '1筒', '1筒', '1筒', '1筒', '3筒', '3筒', '3筒', '3筒', //
        '5筒', '5筒', '5筒', '5筒', '9条', '9条',
      ], sevenPairs: true);
      expect(typesOf(s), [FanType.sanLongQiDui, FanType.pingHu]);
      expect(s.multiplier, 64);
    });

    test('三元七对 ×16 不计七对', () {
      final s = fanOf([
        '中', '中', '发', '发', '白', '白', //
        '1筒', '1筒', '3筒', '3筒', '5筒', '5筒', '7条', '7条',
      ], sevenPairs: true);
      expect(typesOf(s), contains(FanType.sanYuanQiDui));
      expect(typesOf(s), isNot(contains(FanType.qiDui)));
      expect(s.multiplier, 16);
    });

    test('三元七对与龙七对并存连乘（默认）', () {
      final s = fanOf([
        '中', '中', '发', '发', '白', '白', //
        '1筒', '1筒', '1筒', '1筒', '3筒', '3筒', '5条', '5条',
      ], sevenPairs: true);
      expect(typesOf(s),
          containsAll([FanType.sanYuanQiDui, FanType.longQiDui]));
      expect(s.multiplier, 256);
    });
  });

  group('碰碰胡（×2，截图复核补录）', () {
    test('★全副露单钓：对将 + 4 组碰/杠出的刻 → 碰碰胡', () {
      final s = fanOf(['5条', '5条'],
          winTile: parseTile('5条'),
          ctx: const WinContext(selfDraw: true));
      expect(typesOf(s), containsAll([FanType.pengPengHu, FanType.pingHu]));
      expect(s.multiplier, 2);
    });

    test('手中 4 组暗刻 + 将 → 碰碰胡', () {
      final s = fanOf([
        '1筒', '1筒', '1筒', '3筒', '3筒', '3筒', //
        '5筒', '5筒', '5筒', '7条', '7条', '7条', '9条', '9条',
      ]);
      expect(typesOf(s), contains(FanType.pengPengHu));
      expect(s.multiplier, 2);
    });

    test('含顺子 → 不中', () {
      final s = fanOf([
        '1筒', '1筒', '1筒', '2筒', '3筒', '4筒', //
        '5筒', '5筒', '5筒', '7条', '7条', '7条', '9条', '9条',
      ]);
      expect(typesOf(s), isNot(contains(FanType.pengPengHu)));
    });

    test('★杠上开花不计碰碰胡（不连乘）', () {
      final s = fanOf(['5条', '5条'],
          winTile: parseTile('5条'),
          ctx: const WinContext(selfDraw: true, afterGang: true));
      expect(typesOf(s), contains(FanType.gangHua));
      expect(typesOf(s), isNot(contains(FanType.pengPengHu)));
      expect(s.multiplier, 2);
    });

    test('碰碰胡与小三元并存连乘 ×8', () {
      // 中中作将，发/白/1筒/5条 四组刻
      final s = fanOf([
        '中', '中', '发', '发', '发', '白', '白', '白', //
        '1筒', '1筒', '1筒', '5条', '5条', '5条',
      ]);
      expect(typesOf(s), containsAll([FanType.pengPengHu, FanType.xiaoSanYuan]));
      expect(s.multiplier, 8);
    });
  });

  group('复合连乘', () {
    test('卡五星 ×2 × 杠上开花 ×2 = 4', () {
      final s = fanOf([
        '1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '4筒', '5筒', '6筒', '1条', '2条', '3条', '5条', '5条',
      ], winTile: parseTile('5筒'),
          ctx: const WinContext(afterGang: true, selfDraw: true));
      expect(typesOf(s), containsAll([FanType.kaWuXing, FanType.gangHua]));
      expect(s.multiplier, 4);
    });

    test('展示标签格式与 v0.1 一致', () {
      expect(FanType.kaWuXing.displayLabel, '卡五星 ×2');
      expect(FanType.sanLongQiDui.displayLabel, '三龙七对 ×64');
    });
  });
}
