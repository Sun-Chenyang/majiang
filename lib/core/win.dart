/// 胡牌全分解枚举（docs/02-技术方案设计.md §4.1）。
///
/// 番型判定依赖具体分解——例如小三元要求中发白"2 刻 + 1 对"，同一手牌
/// 可能同时存在"小三元分解"与"非小三元分解"，听牌结果必须按分解分别
/// 算番，全部展示、标注最优。14 张牌的分解总数上限很小（几十个量级），
/// 性能无忧。空列表 = 未胡。
library;

import 'dart:typed_data';

import 'tile.dart';

enum MeldKind { triplet, sequence }

/// 一组面子。
class Meld3 {
  final MeldKind kind;

  /// triplet：该牌种；sequence：顺子最低张牌种。
  final int tile;

  const Meld3(this.kind, this.tile);

  @override
  bool operator ==(Object other) =>
      other is Meld3 && other.kind == kind && other.tile == tile;

  @override
  int get hashCode => Object.hash(kind, tile);

  @override
  String toString() => kind == MeldKind.triplet
      ? '${tileName(tile)}${tileName(tile)}${tileName(tile)}'
      : '${tileName(tile)}${tileName(tile + 1)}${tileName(tile + 2)}';
}

/// 一次胡牌分解：雀头 + 暗牌面子（副露在 HandState，不在此列）。
class WinStructure {
  /// 雀头牌种；七对形态无雀头，为 −1。
  final int pair;
  final List<Meld3> melds;

  /// 七对形态（14 张全偶数，含"4 张同牌 = 2 对"的龙）。
  final bool isSevenPairs;

  const WinStructure({
    required this.pair,
    required this.melds,
    this.isSevenPairs = false,
  });

  @override
  String toString() => isSevenPairs
      ? '七对'
      : '雀头${tileName(pair)} + $melds';
}

/// 枚举 [c]（3n+2 张计数）的全部胡牌分解；未胡返回空列表。
///
/// 七对形态仅在暗牌恰 14 张（无副露）且全部计数为偶数时产出，可能与
/// 标准型分解并存（如 1122334455667 型手牌两种形态都成立）。
List<WinStructure> decompose(Uint8List c) {
  final results = <WinStructure>[];
  var total = 0;
  for (final v in c) {
    total += v;
  }
  if (total < 2 || (total - 2) % 3 != 0) return results;

  // 七对形态
  if (total == 14) {
    var allEven = true;
    for (final v in c) {
      if (v.isOdd) {
        allEven = false;
        break;
      }
    }
    if (allEven) {
      results.add(const WinStructure(pair: -1, melds: [], isSevenPairs: true));
    }
  }

  // 标准型：枚举雀头 → 回溯收集全部面子组合。
  // 回溯始终处理"最小非零牌种"，每种面子组合只产出一次。
  for (var pair = 0; pair < kTileKindCount; pair++) {
    if (c[pair] < 2) continue;
    c[pair] -= 2;
    final melds = <Meld3>[];
    _collectMelds(c, 0, melds, pair, results);
    c[pair] += 2;
  }
  return results;
}

void _collectMelds(
  Uint8List c,
  int from,
  List<Meld3> melds,
  int pair,
  List<WinStructure> out,
) {
  var t = from;
  while (t < kTileKindCount && c[t] == 0) {
    t++;
  }
  if (t == kTileKindCount) {
    out.add(WinStructure(pair: pair, melds: List.of(melds)));
    return;
  }

  // 刻子
  if (c[t] >= 3) {
    c[t] -= 3;
    melds.add(Meld3(MeldKind.triplet, t));
    _collectMelds(c, t, melds, pair, out);
    melds.removeLast();
    c[t] += 3;
  }
  // 顺子：仅筒/条且点数 ≤ 7（字牌 18-20 无 t+1/t+2 同花色意义，天然剪枝）
  if (t <= 17 && t % 9 <= 6 && c[t + 1] > 0 && c[t + 2] > 0) {
    c[t]--;
    c[t + 1]--;
    c[t + 2]--;
    melds.add(Meld3(MeldKind.sequence, t));
    _collectMelds(c, t, melds, pair, out);
    melds.removeLast();
    c[t]++;
    c[t + 1]++;
    c[t + 2]++;
  }
  // 两分支都尝试完毕才返回：收集全部解而非找到即停。
}
