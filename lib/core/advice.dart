/// 打牌建议（docs/02-技术方案设计.md §4.5）。
///
/// 对暗牌中每个不同牌种模拟打出 → 计算进张 → 排序。
/// 排序键 (shanten ↑, totalRemain ↓, fanWeighted ↓, discard ↑ 稳定)，
/// 全部展示、并列不裁决（PRD FR3.4"把决策留给用户"）。
library;

import 'dart:typed_data';

import 'hand_state.dart';
import 'rules_config.dart';
import 'ting.dart';
import 'tile.dart';

class DiscardOptionV2 {
  final int discard;

  /// 打后向听数。
  final UkeireResult ukeire;

  const DiscardOptionV2(this.discard, this.ukeire);

  int get shanten => ukeire.shanten;

  /// Σ 进张剩余张数。
  int get totalRemain => ukeire.totalRemain;

  /// 番型加权分 = Σ(进张剩余 × 该进张最优可胡倍数)，仅听牌候选非 0。
  int get fanWeighted {
    var s = 0;
    for (final a in ukeire.accepted) {
      final wins = a.wins;
      if (wins == null) continue;
      var best = 0;
      for (final w in wins) {
        if (w.score.canWin && w.score.multiplier > best) {
          best = w.score.multiplier;
        }
      }
      s += a.remain * best;
    }
    return s;
  }

  /// 本候选最优可胡倍数（非听牌为 0）。
  int get bestFanMultiplier {
    var best = 0;
    for (final a in ukeire.accepted) {
      final wins = a.wins;
      if (wins == null) continue;
      for (final w in wins) {
        if (w.score.canWin && w.score.multiplier > best) {
          best = w.score.multiplier;
        }
      }
    }
    return best;
  }

  bool get tenpai => shanten == 0;
}

/// 建议列表（已排序）。附带 [lossHints]：与最优听牌候选相比的番型损失
/// 倍数（"打这张损失 ×N 番"，PRD FR3.5），无损失/非听牌候选不记录。
class DiscardAdvice {
  final List<DiscardOptionV2> options;
  final Map<int, int> lossHints;

  const DiscardAdvice(this.options, this.lossHints);
}

DiscardAdvice rankDiscards(HandState hand, WinContext ctx) {
  final c = Uint8List.fromList(hand.concealed);
  final options = <DiscardOptionV2>[];
  for (var t = 0; t < kTileKindCount; t++) {
    if (c[t] == 0) continue;
    c[t]--;
    options.add(DiscardOptionV2(
      t,
      computeUkeire(HandState(c, hand.honorMelds), ctx),
    ));
    c[t]++;
  }

  options.sort((a, b) {
    final byShanten = a.shanten.compareTo(b.shanten);
    if (byShanten != 0) return byShanten;
    final byRemain = b.totalRemain.compareTo(a.totalRemain);
    if (byRemain != 0) return byRemain;
    final byFan = b.fanWeighted.compareTo(a.fanWeighted);
    if (byFan != 0) return byFan;
    return a.discard.compareTo(b.discard);
  });

  // 损失提示：同为听牌的候选中，较最优可胡倍数折损的倍数
  var bestFan = 0;
  for (final o in options) {
    if (o.tenpai) {
      final f = o.bestFanMultiplier;
      if (f > bestFan) bestFan = f;
    }
  }
  final lossHints = <int, int>{};
  if (bestFan > 0) {
    for (final o in options) {
      final f = o.bestFanMultiplier;
      if (o.tenpai && f > 0 && f < bestFan) {
        lossHints[o.discard] = bestFan ~/ f;
      }
    }
  }
  return DiscardAdvice(options, lossHints);
}
