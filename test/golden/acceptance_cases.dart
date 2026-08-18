/// PRD §7 验收用例固化（开发计划 M9.1 · 技术方案 §8.3）。
///
/// 30 组人工推演的定型手牌：向听数 / 听牌 / 进张剩余 / 番型 / 互斥 /
/// 情境 / 副露省录 / 已见牌 / 碰杠时机。期望值全部手工推导（非算法
/// 回放），发布前作为回归清单全量跑一遍。
library;

import 'package:kawuxing/core/rules_config.dart';

class AcceptanceCase {
  final String id;
  final String name;

  /// 暗牌（牌名字符串，如 '5筒'、'中'）。
  final List<String> tiles;

  /// 字牌碰/杠标记（牌名）。
  final Set<String> honorMelds;

  /// 他家已见标记（牌名 → 张数）。
  final Map<String, int> seen;

  final WinContext ctx;

  // ---- 期望（null = 本用例不检查该项） ----
  final int? shanten;
  final bool? tenpai;
  final bool? win; // 14 张已胡
  final Map<String, int>? waits; // 进张牌名 → 剩余张数（全量集合）
  final String? bestFan; // 最优可胡分解 describe（'卡五星 ×2 · 屁胡 ×1'）
  final int? bestMultiplier;
  final String? bestDiscard; // 14 张排序第一的切牌
  final Map<String, int>? lossHints; // 牌名 → 损失倍数
  final Map<String, int>? pengImprovements; // 碰牌名 → 碰后向听数
  final bool? hasNotice; // 结果区提示（三元按暗牌计算）
  final int? minWinStructures; // 已胡时可胡分解数下限（多分解全展示）

  /// true = 点炮情境下全部分解不可胡（bestFan 因此为 null）。
  final bool allBlocked;

  const AcceptanceCase({
    required this.id,
    required this.name,
    required this.tiles,
    this.honorMelds = const {},
    this.seen = const {},
    this.ctx = WinContext.defaults,
    this.shanten,
    this.tenpai,
    this.win,
    this.waits,
    this.bestFan,
    this.bestMultiplier,
    this.bestDiscard,
    this.lossHints,
    this.pengImprovements,
    this.hasNotice,
    this.minWinStructures,
    this.allBlocked = false,
  });
}

/// 自摸情境（主页默认态，展示完整番型潜力）。
const WinContext _selfDraw = WinContext(selfDraw: true);

const List<AcceptanceCase> kAcceptanceCases = [
  // ============ A. 听牌与番型（13 张） ============

  AcceptanceCase(
    id: 'A1',
    name: '卡五星·筒：4/6 筒夹 5',
    tiles: ['1筒', '2筒', '3筒', '7筒', '8筒', '9筒', '4筒', '6筒', //
        '1条', '2条', '3条', '5条', '5条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'5筒': 4},
    bestFan: '卡五星 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'A2',
    name: '卡五星·条同计：4/6 条夹 5',
    tiles: ['1条', '2条', '3条', '7条', '8条', '9条', '4条', '6条', //
        '1筒', '2筒', '3筒', '5筒', '5筒'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'5条': 4},
    bestFan: '卡五星 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'A3',
    name: '七对单钓（顺子共存路线仍只听单张）',
    tiles: ['1筒', '1筒', '2筒', '2筒', '3筒', '3筒', '4筒', '4筒', //
        '5筒', '5筒', '6筒', '6筒', '7条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'7条': 3},
    bestFan: '七对 ×4 · 屁胡 ×1',
    bestMultiplier: 4,
  ),
  AcceptanceCase(
    id: 'A4',
    name: '七对：孤立对子单钓',
    tiles: ['1筒', '1筒', '4筒', '4筒', '7筒', '7筒', //
        '2条', '2条', '5条', '5条', '8条', '8条', '9筒'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'9筒': 3},
    bestFan: '七对 ×4 · 屁胡 ×1',
    bestMultiplier: 4,
  ),
  AcceptanceCase(
    id: 'A5',
    name: '龙七对：摸第 4 张成龙（4 张 = 2 对）',
    tiles: ['1筒', '1筒', '4筒', '4筒', '7筒', '7筒', //
        '2条', '2条', '5条', '5条', '9条', '9条', '9条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'9条': 1},
    bestFan: '龙七对 ×16 · 屁胡 ×1',
    bestMultiplier: 16,
  ),
  AcceptanceCase(
    id: 'A6',
    name: '双龙七对：两种 4 张在手',
    tiles: ['1筒', '1筒', '1筒', '1筒', '4筒', '4筒', '4筒', '4筒', //
        '2筒', '2筒', '7条', '7条', '9条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'9条': 3},
    bestFan: '双龙七对 ×32 · 屁胡 ×1',
    bestMultiplier: 32,
  ),
  AcceptanceCase(
    id: 'A7',
    name: '三元七对：中发白各一对',
    tiles: ['中', '中', '发', '发', '白', '白', //
        '1筒', '1筒', '4筒', '4筒', '7条', '7条', '9筒'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'9筒': 3},
    bestFan: '三元七对 ×16 · 屁胡 ×1',
    bestMultiplier: 16,
  ),
  AcceptanceCase(
    id: 'A8',
    name: '碰碰胡听牌：对倒',
    tiles: ['1筒', '1筒', '1筒', '9筒', '9筒', '9筒', //
        '7条', '7条', '7条', '中', '中', '5条', '5条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'中': 2, '5条': 2},
    bestFan: '碰碰胡 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'A9',
    name: '小三元听牌（暗牌 2 刻 + 1 对）',
    tiles: ['中', '中', '中', '发', '发', '发', '白', '白', //
        '1筒', '2筒', '3筒', '7条', '8条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'6条': 4, '9条': 4},
    bestFan: '小三元 ×4 · 屁胡 ×1',
    bestMultiplier: 4,
  ),
  AcceptanceCase(
    id: 'A10',
    name: '大三元：字牌副露标记补全（7 张 + 2 组副露）',
    // 中刻在暗牌 + 发/白两组副露标记 = 3 组三元刻
    tiles: ['中', '中', '中', '5筒', '5筒', '7条', '8条'],
    honorMelds: {'发', '白'},
    ctx: WinContext.defaults, // 点炮：大三元非屁胡，仍可胡
    shanten: 0,
    tenpai: true,
    waits: {'6条': 4, '9条': 4},
    bestFan: '大三元 ×8 · 屁胡 ×1',
    bestMultiplier: 8,
  ),

  // ============ B. 情境开关 ============

  AcceptanceCase(
    id: 'B1',
    name: '屁胡点炮被拒（屁胡只能自摸）',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '9条', '9条'],
    ctx: WinContext.defaults, // 点炮
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4},
    allBlocked: true, // 屁胡只能自摸：点炮下全部分解 canWin=false
  ),
  AcceptanceCase(
    id: 'B2',
    name: '屁胡自摸可行（×1）',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '9条', '9条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4},
    bestFan: '屁胡 ×1',
    bestMultiplier: 1,
  ),
  AcceptanceCase(
    id: 'B3',
    name: '杠上开花 ×2（自摸联动）',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '9条', '9条'],
    ctx: WinContext(selfDraw: true, afterGang: true),
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4},
    bestFan: '杠上开花 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'B4',
    name: '抢杠 ×2',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '9条', '9条'],
    ctx: WinContext(robKong: true),
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4},
    bestFan: '抢杠 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'B5',
    name: '杠上炮 ×2（点炮情境）',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '1条', '2条', '9条', '9条'],
    ctx: WinContext(gangPao: true),
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4},
    bestFan: '杠上炮 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'B6',
    name: '暗四归一：手 3 张自摸第 4 张（×4），五面听',
    // 456/789/999 筒 + 666/78 条：666+78 可拆 678+66，
    // 故 3/6/9 筒与 6/9 条五面听，6 条为暗四归一（×4 最优）
    tiles: ['4筒', '5筒', '6筒', '7筒', '8筒', '9筒', '9筒', '9筒', //
        '6条', '6条', '6条', '7条', '8条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'3筒': 4, '6筒': 3, '9筒': 1, '6条': 1, '9条': 4},
    bestFan: '暗四归一 ×4 · 屁胡 ×1',
    bestMultiplier: 4,
  ),

  // ============ C. 向听数量化（13 张） ============

  AcceptanceCase(
    id: 'C1',
    name: '一向听：3 面子 + 对将 + 双孤张',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7条', '8条', '9条', '中', '中', '1条', '4条'],
    ctx: _selfDraw,
    shanten: 1,
    tenpai: false,
  ),
  AcceptanceCase(
    id: 'C2',
    name: '两向听：2 面子 + 2 搭子无将',
    tiles: ['1筒', '2筒', '3筒', '7筒', '8筒', '9筒', //
        '4条', '5条', '7条', '8条', '中', '白', '发'],
    ctx: _selfDraw,
    shanten: 2,
  ),
  AcceptanceCase(
    id: 'C3',
    name: '三向听：2 面子 + 将 + 4 孤张',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '中', '中', '1条', '5条', '9条', '发', '白'],
    ctx: _selfDraw,
    shanten: 3,
  ),
  AcceptanceCase(
    id: 'C4',
    name: '七对一向听：5 对 + 2 单',
    tiles: ['1筒', '1筒', '4筒', '4筒', '7筒', '7筒', //
        '2条', '2条', '5条', '5条', '3筒', '6筒', '9条'],
    ctx: _selfDraw,
    shanten: 1,
  ),

  // ============ D. 已胡与打牌建议（14 张 / 副露待打） ============

  AcceptanceCase(
    id: 'D1',
    name: '已胡多分解：碰碰胡 vs 顺子分解（全展示标最优）',
    tiles: ['2筒', '2筒', '2筒', '3筒', '3筒', '3筒', '4筒', '4筒', //
        '4筒', '5筒', '5筒', '5筒', '6筒', '6筒'],
    ctx: _selfDraw,
    win: true,
    shanten: -1,
    bestFan: '碰碰胡 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
    minWinStructures: 2, // 222/333/444/555 与 234×3/555 两种分解并存
  ),
  AcceptanceCase(
    id: 'D2',
    name: '11 张（1 组副露）：打孤张进听',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '1条', '2条', '5条', '5条', '9条'],
    ctx: _selfDraw,
    bestDiscard: '9条',
  ),
  AcceptanceCase(
    id: 'D3',
    name: '14 张经典决策：打白听三面（12 张进张）',
    tiles: ['1筒', '2筒', '3筒', '4筒', '5筒', '6筒', //
        '7筒', '8筒', '9筒', '4条', '5条', '5条', '5条', '白'],
    ctx: _selfDraw,
    bestDiscard: '白',
  ),
  AcceptanceCase(
    id: 'D4',
    name: '损失提示：打中损失 ×4 番（龙七对 → 七对）',
    tiles: ['中', '中', '中', '1筒', '1筒', '3筒', '3筒', //
        '5筒', '5筒', '7条', '7条', '9条', '9条', '白'],
    ctx: _selfDraw,
    bestDiscard: '中', // 进张排序第一（4 张 > 1 张）
    lossHints: {'中': 4},
  ),
  AcceptanceCase(
    id: 'D5',
    name: '8 张（2 组副露）已胡：屁胡 + 三元提示',
    tiles: ['中', '中', '5筒', '6筒', '7筒', '7条', '8条', '9条'],
    ctx: _selfDraw,
    win: true,
    shanten: -1,
    bestFan: '屁胡 ×1',
    bestMultiplier: 1,
    hasNotice: true,
  ),

  // ============ E. 副露省录与单钓 ============

  AcceptanceCase(
    id: 'E1',
    name: '10 张（1 组副露）听牌：搭子进张',
    tiles: ['1筒', '2筒', '3筒', '7条', '8条', '9条', //
        '中', '中', '4条', '5条'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'3条': 4, '6条': 4},
    bestFan: '屁胡 ×1',
    bestMultiplier: 1,
  ),
  AcceptanceCase(
    id: 'E2',
    name: '1 张（4 组副露满）单钓听牌：无吃规则下副露必为刻 → 碰碰胡',
    tiles: ['白'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'白': 3},
    bestFan: '碰碰胡 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),

  // ============ F. 互斥"不计" ============

  AcceptanceCase(
    id: 'F1',
    name: '杠上开花不计碰碰胡',
    tiles: ['1筒', '1筒', '1筒', '9筒', '9筒', '9筒', //
        '7条', '7条', '7条', '5条', '5条', '5条', '中', '中'],
    ctx: WinContext(selfDraw: true, afterGang: true),
    win: true,
    shanten: -1,
    bestFan: '杠上开花 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'F2',
    name: '三龙七对吞并七对/龙七对/双龙（×64）',
    tiles: ['1筒', '1筒', '1筒', '1筒', '2筒', '2筒', '2筒', '2筒', //
        '3筒', '3筒', '3筒', '3筒', '4筒', '4筒'],
    ctx: _selfDraw,
    win: true,
    shanten: -1,
    bestFan: '三龙七对 ×64 · 屁胡 ×1',
    bestMultiplier: 64,
  ),
  AcceptanceCase(
    id: 'F3',
    name: '大三元不计小三元',
    tiles: ['中', '中', '中', '发', '发', '发', '白', '白', '白', //
        '1条', '2条', '3条', '5条', '5条'],
    ctx: _selfDraw,
    win: true,
    shanten: -1,
    bestFan: '大三元 ×8 · 屁胡 ×1',
    bestMultiplier: 8,
  ),

  // ============ G. 已见牌与碰杠时机（M8.3/M8.4 联动） ============

  AcceptanceCase(
    id: 'G1',
    name: '已见 2 张：听牌剩余张数精确扣减',
    tiles: ['1筒', '2筒', '3筒', '7筒', '8筒', '9筒', '4筒', '6筒', //
        '1条', '2条', '3条', '5条', '5条'],
    seen: {'5筒': 2},
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'5筒': 2},
    bestFan: '卡五星 ×2 · 屁胡 ×1',
    bestMultiplier: 2,
  ),
  AcceptanceCase(
    id: 'G2',
    name: '已见 4 张：剩余 0 仍列出（灰化交给 UI）',
    tiles: ['1筒', '2筒', '3筒', '7筒', '8筒', '9筒', '4筒', '6筒', //
        '1条', '2条', '3条', '5条', '5条'],
    seen: {'5筒': 4},
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'5筒': 0},
  ),
  AcceptanceCase(
    id: 'G3',
    name: '碰杠时机：碰孤对补面子，1 向听 → 听牌',
    tiles: ['中', '中', '4筒', '5筒', '6筒', '7筒', '8筒', '9筒', //
        '1条', '2条', '3条', '4条', '9条'],
    ctx: _selfDraw,
    shanten: 1,
    pengImprovements: {'中': 0},
  ),
  AcceptanceCase(
    id: 'G4',
    name: '七对听牌：碰后破坏听牌前提',
    tiles: ['1筒', '1筒', '4筒', '4筒', '7筒', '7筒', //
        '1条', '1条', '4条', '4条', '7条', '7条', '9筒'],
    ctx: _selfDraw,
    shanten: 0,
    tenpai: true,
    waits: {'9筒': 3},
  ),
];
