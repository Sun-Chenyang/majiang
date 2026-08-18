/// 向听数引擎（docs/02-技术方案设计.md §4.2，开发计划 M6.1/M6.2）。
///
/// 向听数定义：-1 已胡 / 0 听牌 / n 差 n 张有效牌。
/// 兼容任意 3n+1（待摸）与 3n+2（待打）暗牌张数；副露折算为已完成面子。
///
/// 返回 min(标准型向听数, 七对向听数)；有副露（张数 < 13/14）时七对
/// 分支返回 [kNoSevenPairs]（不参与取小）。
library;

import 'dart:typed_data';

import 'tile.dart';

/// 七对分支不可行时的哨兵值（副露存在 → 七对系全灭）。
const int kNoSevenPairs = 99;

/// 计算暗牌 [concealed]（长 21 计数）在 [meldCount] 组副露下的向听数。
int calculateShanten(Uint8List concealed, int meldCount) {
  final standard = _standardShanten(concealed, meldCount);
  if (meldCount > 0) return standard;
  final pairs = _sevenPairsShanten(concealed);
  return pairs < standard ? pairs : standard;
}

/// 标准型分支向听数（公开给鸣牌建议比较"碰后七对作废"分支）。
int standardShanten(Uint8List concealed, int meldCount) =>
    _standardShanten(concealed, meldCount);

/// 七对分支向听数（无副露前提；有副露时调用方须自行排除）。
int sevenPairsShanten(Uint8List concealed) => _sevenPairsShanten(concealed);

/// 标准型向听数（回溯枚举"面子 + 搭子 + 雀头"最优组合）：
///
/// ```plain
/// shanten = 8 − 2·M − P − H + max(0, M + P − 4)
///   M = meldCount + 暗牌面子数（顺子/刻子）
///   P = 搭子数（两面/嵌张/对子搭；字牌搭子仅对子）
///   H ∈ {0,1} 专用雀头（不计入 P）
///   M + P ≤ 5（4 面子槽 + 1 雀头槽；溢出的搭子由修正项罚 1）
/// ```
///
/// 修正项 max(0, M+P−4) 是经典的"满块无雀头"罚：四搭子无将时须拆一搭。
/// 对同一组牌，回溯会同时枚举"对子作雀头"与"对子作搭子"两种分支，
/// 取最小值自动消化歧义。
int _standardShanten(Uint8List c, int meldCount) {
  var total = 0;
  for (final v in c) {
    total += v;
  }
  // 理论下限：3n+2 可为 -1（已胡），3n+1 最小 0（听牌）
  final floor = total % 3 == 2 ? -1 : 0;
  var best = 8;

  void walk(int t, int melds, int partials, bool hasHead, int left) {
    final m = melds + meldCount;
    final penalty = m + partials > 4 ? m + partials - 4 : 0;
    final value = 8 - 2 * m - partials - (hasHead ? 1 : 0) + penalty;
    if (value < best) {
      best = value;
      if (best == floor) return; // 已达理论最优，提前终止
    }
    // 剩余牌收益上界：每张最多 2/3 分（面子 3 张 2 分）
    final maxGain = (2 * left) ~/ 3;
    if (value - maxGain >= best) return; // 怎么走都无法更优，剪枝

    while (t < kTileKindCount && c[t] == 0) {
      t++;
    }
    if (t == kTileKindCount) return;
    final inSuit = t <= 17;
    final rank = t % 9;
    final blockable = melds + partials + meldCount < 5;

    // 孤张跳过：本牌种不作任何组合（后续牌种继续）
    walk(t + 1, melds, partials, hasHead, left - c[t]);

    if (c[t] >= 3) {
      c[t] -= 3;
      walk(t, melds + 1, partials, hasHead, left - 3);
      c[t] += 3;
    }
    if (inSuit && rank <= 6 && c[t + 1] > 0 && c[t + 2] > 0) {
      c[t]--;
      c[t + 1]--;
      c[t + 2]--;
      walk(t, melds + 1, partials, hasHead, left - 3);
      c[t]++;
      c[t + 1]++;
      c[t + 2]++;
    }
    if (c[t] >= 2) {
      // 对子作雀头
      if (!hasHead) {
        c[t] -= 2;
        walk(t, melds, partials, true, left - 2);
        c[t] += 2;
      }
      // 对子作搭子（刻子搭）
      if (blockable) {
        c[t] -= 2;
        walk(t, melds, partials + 1, hasHead, left - 2);
        c[t] += 2;
      }
    }
    // 两面/边张搭（t, t+1）
    if (inSuit && rank <= 7 && c[t + 1] > 0 && blockable) {
      c[t]--;
      c[t + 1]--;
      walk(t, melds, partials + 1, hasHead, left - 2);
      c[t]++;
      c[t + 1]++;
    }
    // 嵌张搭（t, t+2）
    if (inSuit && rank <= 6 && c[t + 2] > 0 && blockable) {
      c[t]--;
      c[t + 2]--;
      walk(t, melds, partials + 1, hasHead, left - 2);
      c[t]++;
      c[t + 2]++;
    }
  }

  walk(0, 0, 0, false, total);
  return best;
}

/// 七对向听数（卡五星定制：4 张同牌 = 2 对）：
///
/// ```plain
/// shanten = 6 − pairs，pairs = Σ min(count ÷ 2, 2)
/// ```
///
/// ⚠️ 日麻公式带有 `max(0, 7 − 种类数)` 惩罚项，此处**不可移植**：
/// 日麻 4 张同牌只算 1 对，才需要"至少 7 种"；卡五星 4 张 = 2 对后，
/// 缺的对可以由升级获得（单张配对、刻子补成 4 张），而 13/14 张下
/// 可升级槽位（count 为奇数的牌种数）恒 ≥ 缺口，种类约束消失。
/// 例：`中中中 + 5 对` 听牌（摸第 4 张中 → 龙七对胡），日麻公式给 1。
/// 此差异由 cross_check 对拍测试锁死。
int _sevenPairsShanten(Uint8List c) {
  var pairs = 0;
  for (final v in c) {
    final p = v >> 1;
    pairs += p > 2 ? 2 : p;
  }
  return 6 - pairs;
}
