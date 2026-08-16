/// 分析总入口（docs/02-技术方案设计.md §5.2 的接口契约）。
///
/// 结果区是 (手牌, 副露, 情境, 规则配置) 的纯函数渲染：UI 只消费
/// [HandAnalysis] 模型。每次输入全量重算 < 40ms，主线程同步即可。
library;

import 'advice.dart';
import 'hand_state.dart';
import 'rules_config.dart';
import 'shanten.dart';
import 'ting.dart';

/// 对当前输入的整体分析结果。
class HandAnalysis {
  final int count;
  final bool validPhase; // 3n+1 / 3n+2 且 ≥ 2
  final bool drawPhase; // 3n+2：待打（打牌建议态）
  final int meldCount; // 推断的碰/杠组数

  /// 当前向听数（-1 已胡 / 0 听牌 / n 差 n 张）。
  final int shanten;

  /// 待打态已胡（shanten == -1）。
  final bool isWin;

  /// 待打已胡时的全分解番型评估（按倍数降序、标最优）。
  final List<WinWithFan> winStructures;

  /// 待摸态：进张/听牌 + 番型。
  final UkeireResult? ukeire;

  /// 待打态：打牌建议（已排序）+ 损失提示。
  final DiscardAdvice? advice;

  /// 提示文案（如"三元番型按暗牌计算"）。
  final List<String> notices;

  const HandAnalysis({
    required this.count,
    required this.validPhase,
    required this.drawPhase,
    required this.meldCount,
    required this.shanten,
    required this.isWin,
    required this.winStructures,
    required this.ukeire,
    required this.advice,
    required this.notices,
  });

  /// 待摸态听牌（向听数 0）。
  bool get isTenpai => !drawPhase && validPhase && shanten == 0;
}

HandAnalysis analyzeHand(
  HandState hand,
  WinContext ctx,
) {
  final count = hand.count;
  final validPhase = hand.validPhase;
  final drawPhase = hand.isDrawPhase;
  final meldCount = hand.meldCount;

  if (!validPhase) {
    return HandAnalysis(
      count: count,
      validPhase: false,
      drawPhase: drawPhase,
      meldCount: meldCount,
      shanten: 0,
      isWin: false,
      winStructures: const [],
      ukeire: null,
      advice: null,
      notices: const [],
    );
  }

  final notices = <String>[];
  if (meldCount > 0 && hand.honorMelds.isEmpty) {
    notices.add('三元番型按手牌计算，可标记碰/杠的中发白补全');
  }

  if (drawPhase) {
    final shanten = calculateShanten(hand.concealed, meldCount);
    if (shanten == -1) {
      final wins = evaluateWinStructures(
        hand.concealed,
        hand.honorMelds,
        ctx,
      );
      return HandAnalysis(
        count: count,
        validPhase: true,
        drawPhase: true,
        meldCount: meldCount,
        shanten: -1,
        isWin: true,
        winStructures: wins,
        ukeire: null,
        advice: null,
        notices: notices,
      );
    }
    final advice = rankDiscards(hand, ctx);
    return HandAnalysis(
      count: count,
      validPhase: true,
      drawPhase: true,
      meldCount: meldCount,
      shanten: shanten,
      isWin: false,
      winStructures: const [],
      ukeire: null,
      advice: advice,
      notices: notices,
    );
  }

  // 待摸（3n+1）：听牌判断
  final ukeire = computeUkeire(hand, ctx);
  return HandAnalysis(
    count: count,
    validPhase: true,
    drawPhase: false,
    meldCount: meldCount,
    shanten: ukeire.shanten,
    isWin: false,
    winStructures: const [],
    ukeire: ukeire,
    advice: null,
    notices: notices,
  );
}
