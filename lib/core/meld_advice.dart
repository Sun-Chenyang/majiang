/// 鸣牌（碰/杠）时机建议（PRD §3.7 F7 · 技术方案 §4.6 · 开发计划 M8.3）。
///
/// 卡五星无吃，仅评估两种鸣牌（均为他家打出该牌时触发）：
///  - 碰：手中 ≥2 张 → 暗牌 −2、副露 +1，进入待打态后跑最优切牌，
///    产出"碰 X → 打 Y（向听 n，进张 m 张）"；
///  - 明杠：手中恰 3 张 → 暗牌 −3、副露 +1，补摸一张后回到待摸态，
///    重算进张（杠的即时得分与杠上开花机会不在本模型内，杠上开花
///    由情境开关在胡牌时体现）。
///
/// 建议条件（FR7.1）：鸣后向听数 < 当前，或持平且进张剩余张数更多。
/// 当前已听牌而鸣后掉出听牌 → 标注破坏听牌（FR7.3）；无副露且当前
/// 七对分支不劣于标准型 → 标注七对作废（碰/杠产生副露即七对系全灭）。
/// 碰/杠字牌自动并入 honorMelds，三元番型补全与剩余张数扣减同步生效。
library;

import 'dart:typed_data';

import 'advice.dart';
import 'hand_state.dart';
import 'rules_config.dart';
import 'shanten.dart';
import 'ting.dart';
import 'tile.dart';

/// 一次鸣牌模拟结果。
class MeldOption {
  final int tile;

  /// true = 明杠（他家打出第 4 张）；false = 碰。
  final bool isGang;

  /// 碰后最优切牌；杠后补摸一张，无切牌（null）。
  final int? discard;

  /// 鸣后向听数（碰 = 打出最优切牌后的向听数；杠 = 补摸态向听数）。
  final int shantenAfter;

  /// 鸣后进张种数。
  final int ukeireKinds;

  /// 鸣后进张剩余总张数。
  final int totalRemain;

  /// 当前听牌但鸣后掉出听牌（FR7.3 破坏听牌前提）。
  final bool breaksTenpai;

  /// 无副露且当前七对分支不劣于标准型：鸣后七对系全灭。
  final bool killsSevenPairs;

  const MeldOption({
    required this.tile,
    required this.isGang,
    required this.discard,
    required this.shantenAfter,
    required this.ukeireKinds,
    required this.totalRemain,
    required this.breaksTenpai,
    required this.killsSevenPairs,
  });
}

/// 鸣牌建议汇总：[options] 含全部可模拟鸣牌（含不利项，由调用方筛选），
/// 按 (shantenAfter ↑, totalRemain ↓, 碰先于杠, tile ↑) 排序。
class MeldAdvice {
  /// 当前（不鸣）基线，来自待摸态的进张计算。
  final int currentShanten;
  final int currentUkeireKinds;
  final int currentTotalRemain;

  final List<MeldOption> options;

  const MeldAdvice({
    required this.currentShanten,
    required this.currentUkeireKinds,
    required this.currentTotalRemain,
    required this.options,
  });
}

/// 是否值得鸣（FR7.1）：向听数下降，或持平且进张更多。
bool isRecommendedOption(MeldOption o, MeldAdvice a) =>
    o.shantenAfter < a.currentShanten ||
    (o.shantenAfter == a.currentShanten &&
        o.totalRemain > a.currentTotalRemain);

/// UI 展示筛选：
///  - 推荐项（向听下降 / 持平且进张更多）；
///  - 明杠向听持平项（杠的即时收益与杠上开花机会在牌外，保留参考）；
///  - 当前听牌时的破坏警告项（掉出听牌，提醒用户勿鸣）。
/// 其余（变差或持平无增益的碰）为噪声，不展示。
bool isWorthShowing(MeldOption o, MeldAdvice a) {
  if (o.breaksTenpai) return a.currentShanten == 0;
  if (isRecommendedOption(o, a)) return true;
  return o.isGang && o.shantenAfter <= a.currentShanten;
}

/// 计算鸣牌建议。输入须为待摸态（3n+1 张），[current] 为该手牌的
/// 进张结果（调用方 analyzeHand 已算过，直接复用避免重复计算）。
MeldAdvice computeMeldAdvice(
  HandState hand,
  UkeireResult current,
  WinContext ctx,
) {
  final c = Uint8List.fromList(hand.concealed);
  final currentShanten = current.shanten;
  final currentTotalRemain = current.totalRemain;

  // 七对作废判定：无副露且七对分支不劣于标准型（含并列——此时碰掉
  // 的是七对路线的搭子，同样值得提醒）。
  final sevenPairsActive = hand.meldCount == 0 &&
      sevenPairsShanten(c) <= standardShanten(c, hand.meldCount);

  final options = <MeldOption>[];
  for (var t = 0; t < kTileKindCount; t++) {
    if (c[t] < 2) continue;
    final meldsAfter = {...hand.honorMelds, if (isHonor(t)) t};

    // 碰：−2 → 待打态，跑最优切牌
    c[t] -= 2;
    final pengBest = rankDiscards(HandState(c, meldsAfter), ctx).options.first;
    options.add(MeldOption(
      tile: t,
      isGang: false,
      discard: pengBest.discard,
      shantenAfter: pengBest.shanten,
      ukeireKinds: pengBest.ukeire.accepted.length,
      totalRemain: pengBest.totalRemain,
      breaksTenpai: currentShanten == 0 && pengBest.shanten > 0,
      killsSevenPairs: sevenPairsActive,
    ));
    c[t] += 2;

    // 明杠：−3 → 补摸后回待摸态，重算进张
    if (c[t] == 3) {
      c[t] -= 3;
      final uk = computeUkeire(HandState(c, meldsAfter), ctx);
      options.add(MeldOption(
        tile: t,
        isGang: true,
        discard: null,
        shantenAfter: uk.shanten,
        ukeireKinds: uk.accepted.length,
        totalRemain: uk.totalRemain,
        breaksTenpai: currentShanten == 0 && uk.shanten > 0,
        killsSevenPairs: sevenPairsActive,
      ));
      c[t] += 3;
    }
  }

  options.sort((a, b) {
    final byShanten = a.shantenAfter.compareTo(b.shantenAfter);
    if (byShanten != 0) return byShanten;
    final byRemain = b.totalRemain.compareTo(a.totalRemain);
    if (byRemain != 0) return byRemain;
    final byKind = (a.isGang ? 1 : 0) - (b.isGang ? 1 : 0);
    if (byKind != 0) return byKind;
    return a.tile.compareTo(b.tile);
  });

  return MeldAdvice(
    currentShanten: currentShanten,
    currentUkeireKinds: current.accepted.length,
    currentTotalRemain: currentTotalRemain,
    options: options,
  );
}
