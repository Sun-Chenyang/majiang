/// 全 13 番型判定 + "不计"互斥 + 情境 + 规则配置
/// （docs/02-技术方案设计.md §4.4，docs/卡五星规则.md §6）。
///
/// 互斥实现：命中集合按倍数降序排列后，每个命中的 `excludes` 逐个吞并
/// 低级番型（如命中三龙七对则移除七对/龙七对/双龙七对并记录"被不计"），
/// `multiplier = Π 剩余项倍数`。多分解取最优由调用方（ting/advice）对
/// 每个 WinStructure 分别调用 [evaluateFan] 后排序完成。
library;

import 'dart:typed_data';

import 'rules_config.dart';
import 'tile.dart';
import 'win.dart';

enum FanType {
  pingHu('屁胡', 1),
  kaWuXing('卡五星', 2),
  gangPao('杠上炮', 2),
  gangHua('杠上开花', 2),
  qiangGang('抢杠', 2),
  pengPengHu('碰碰胡', 2),
  xiaoSanYuan('小三元', 4),
  anSiGuiYi('暗四归一', 4),
  qiDui('七对', 4),
  daSanYuan('大三元', 8),
  longQiDui('龙七对', 16),
  sanYuanQiDui('三元七对', 16),
  shuangLongQiDui('双龙七对', 32),
  sanLongQiDui('三龙七对', 64);

  final String label;
  final int multiplier;

  const FanType(this.label, this.multiplier);

  /// "不计"互斥表：命中本番型后不再计的低级番型。
  /// 注意：enum 顺序即同倍数时的处理优先级（吞并方在前）。
  static const Map<FanType, List<FanType>> kExcludes = {
    FanType.gangHua: [FanType.pengPengHu], // 截图复核：杠上开花不计碰碰胡
    FanType.daSanYuan: [FanType.xiaoSanYuan],
    FanType.longQiDui: [FanType.qiDui],
    FanType.sanYuanQiDui: [FanType.qiDui],
    FanType.shuangLongQiDui: [FanType.qiDui, FanType.longQiDui],
    FanType.sanLongQiDui: [
      FanType.qiDui,
      FanType.longQiDui,
      FanType.shuangLongQiDui,
    ],
  };

  /// 展示标签：与 v0.1 引擎的 '卡五星 ×2' 格式保持一致。
  String get displayLabel => '$label ×$multiplier';
}

/// 一个命中的番型（含被本番型吞并的"不计"记录）。
class FanHit {
  final FanType type;
  final List<FanType> swallowed;

  const FanHit(this.type, [this.swallowed = const []]);
}

/// 一次胡牌分解的番型评估。
class FanScore {
  /// 命中番型（已按倍数降序、互斥吞并后；末尾恒有屁胡基准）。
  final List<FanHit> hits;

  /// 总倍数 = Π 命中番型倍数。
  final int multiplier;

  /// 该分解在当前情境下是否可胡。
  /// false 的唯一来源：屁胡为唯一命中 + 配置"屁胡只能自摸" + 点炮。
  final bool canWin;

  const FanScore({
    required this.hits,
    required this.multiplier,
    required this.canWin,
  });

  String get describe =>
      hits.map((h) => h.type.displayLabel).join(' · ');
}

/// 番型判定入口。
///
/// [c14] 含胡牌张的暗牌计数；[winTile] 所胡牌种（已胡展示态传 -1，
/// 跳过依赖胡牌张的番型）；[structure] 为 [decompose] 产出的一个分解；
/// [honorMelds] 已碰/杠的字牌种（小三元/大三元的刻子含这些碰/杠出的刻）。
FanScore evaluateFan({
  required Uint8List c14,
  required Set<int> honorMelds,
  required int winTile,
  required WinStructure structure,
  required WinContext ctx,
}) {
  final hits = <FanHit>[];

  // ---- 情境番（与分解结构无关，纯情境） ----
  if (ctx.gangPao) hits.add(const FanHit(FanType.gangPao));
  if (ctx.afterGang && ctx.selfDraw) {
    hits.add(const FanHit(FanType.gangHua));
  }
  if (ctx.robKong) hits.add(const FanHit(FanType.qiangGang));

  // ---- 卡五星（定义固定：4/6 卡张夹 5，筒条同计） ----
  if (_isKaZhang(winTile, structure, kWuXing) ||
      _isKaZhang(winTile, structure, kWuXing + 9)) {
    hits.add(const FanHit(FanType.kaWuXing));
  }

  if (structure.isSevenPairs) {
    // ---- 七对系：全部命中，由互斥吞并取最高（规格 §4.4 的"不计"模型） ----
    hits.add(const FanHit(FanType.qiDui));
    var quads = 0;
    for (final v in c14) {
      if (v == 4) quads++;
    }
    if (quads >= 1) {
      hits.add(const FanHit(FanType.longQiDui, [FanType.qiDui]));
    }
    if (quads >= 2) {
      hits.add(const FanHit(
        FanType.shuangLongQiDui,
        [FanType.qiDui, FanType.longQiDui],
      ));
    }
    if (quads == 3) {
      hits.add(const FanHit(
        FanType.sanLongQiDui,
        [FanType.qiDui, FanType.longQiDui, FanType.shuangLongQiDui],
      ));
    }
    var dragonPairs = 0;
    for (final t in kHonorTiles) {
      if (c14[t] == 2) dragonPairs++;
    }
    if (dragonPairs == 3) {
      hits.add(const FanHit(FanType.sanYuanQiDui, [FanType.qiDui]));
    }
  } else {
    // ---- 碰碰胡：4 组面子全为刻子（手中的暗刻 + 碰/杠出的刻） ----
    // 副露必然是碰/杠出的刻子，故只需暗面子全为刻子（空也成立——全副露）
    if (structure.melds.every((m) => m.kind == MeldKind.triplet)) {
      hits.add(const FanHit(FanType.pengPengHu));
    }

    // ---- 三元系：刻子 = 暗牌刻 + 碰/杠标记刻 ----
    var honorTriplets = 0;
    for (final m in structure.melds) {
      if (m.kind == MeldKind.triplet && m.tile >= 18) honorTriplets++;
    }
    honorTriplets += honorMelds.length;
    final pairIsHonor = structure.pair >= 18;
    if (honorTriplets == 3) {
      hits.add(const FanHit(FanType.daSanYuan, [FanType.xiaoSanYuan]));
    } else if (honorTriplets == 2 && pairIsHonor) {
      hits.add(const FanHit(FanType.xiaoSanYuan));
    }

    // ---- 暗四归一：3 张暗牌在手 + 自摸第 4 张成胡 ----
    if (winTile >= 0 && ctx.selfDraw && c14[winTile] == 4) {
      hits.add(const FanHit(FanType.anSiGuiYi));
    }
  }

  // ---- 互斥吞并：倍数降序，同倍数按 enum 序（吞并方在前） ----
  hits.sort((a, b) {
    final byMultiplier = b.type.multiplier.compareTo(a.type.multiplier);
    if (byMultiplier != 0) return byMultiplier;
    return a.type.index.compareTo(b.type.index);
  });
  final swallowedAll = <FanType>{};
  final kept = <FanHit>[];
  for (final h in hits) {
    if (swallowedAll.contains(h.type)) continue;
    final swallowed = <FanType>[];
    for (final ex in FanType.kExcludes[h.type] ?? const <FanType>[]) {
      if (hits.any((x) => x.type == ex) && swallowedAll.add(ex)) {
        swallowed.add(ex);
      }
    }
    kept.add(FanHit(h.type, swallowed));
  }

  // ---- 屁胡基准（×1 乘法无害；唯一命中且点炮时不可胡——屁胡只能自摸） ----
  kept.add(const FanHit(FanType.pingHu));

  var multiplier = 1;
  for (final h in kept) {
    multiplier *= h.type.multiplier;
  }
  final onlyPingHu =
      kept.length == 1 && kept.first.type == FanType.pingHu;
  final canWin = !(onlyPingHu && !ctx.selfDraw);

  return FanScore(hits: kept, multiplier: multiplier, canWin: canWin);
}

/// 卡五星卡张判定：胡牌张为 [five]（5筒 或 5条）且分解中存在以该牌为
/// 中间张的顺子（手中持有 4/6 夹 5）。
bool _isKaZhang(int winTile, WinStructure structure, int five) =>
    winTile == five &&
    structure.melds.any(
      (m) => m.kind == MeldKind.sequence && m.tile == five - 1,
    );
