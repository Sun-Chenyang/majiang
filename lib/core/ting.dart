/// 进张（ukeire）泛化计算（docs/02-技术方案设计.md §4.3）。
///
/// 进张定义：使向听数下降的牌；听牌（向听数 0）时进张 = 胡牌张，
/// 并对该张做全分解 + 番型评估。兼容任意 3n+1 张（13/10/7/4/1）：
/// 进张判定只要求"加入一张后向听数下降"，无需按张数分支。
library;

import 'dart:typed_data';

import 'fan.dart';
import 'hand_state.dart';
import 'rules_config.dart';
import 'shanten.dart';
import 'tile.dart';
import 'win.dart';

/// 一次可胡分解及其番型评估。
class WinWithFan {
  final WinStructure structure;
  final FanScore score;

  /// 是否最优分解（可胡分解中倍数最高者）。
  final bool isBest;

  const WinWithFan(this.structure, this.score, {this.isBest = false});
}

/// 一张进张/所听牌。
class AcceptedTile {
  final int tile;

  /// 剩余张数 = 4 − 已见（自家暗牌 + 字牌副露；他家已见 P1 接入）。
  /// 剩余 0 的进张仍列出（UI 灰化展示"已见 4 张"）。
  final int remain;

  /// 向听 0 时 = 胡牌张。
  final bool isWin;

  /// 仅胡牌张：全部可胡分解 + 番型（按倍数降序）。
  final List<WinWithFan>? wins;

  const AcceptedTile(this.tile, this.remain, {this.isWin = false, this.wins});
}

class UkeireResult {
  /// 当前向听数。
  final int shanten;

  /// 全部进张。
  final List<AcceptedTile> accepted;

  const UkeireResult(this.shanten, this.accepted);

  int get totalRemain =>
      accepted.fold(0, (s, a) => s + a.remain);
}

/// 计算进张。输入须为待摸态（3n+1 张，HandState.validPhase 且 !isDrawPhase）。
UkeireResult computeUkeire(HandState hand, WinContext ctx) {
  final c = Uint8List.fromList(hand.concealed);
  final meldCount = hand.meldCount;
  final base = calculateShanten(c, meldCount);
  final accepted = <AcceptedTile>[];

  for (var t = 0; t < kTileKindCount; t++) {
    if (c[t] >= 4) continue; // 同种 5 张硬排除；碰/杠导致的 remain 0 仍列出
    c[t]++;
    final after = calculateShanten(c, meldCount);
    if (after < base) {
      List<WinWithFan>? wins;
      if (base == 0) {
        wins = _evaluateWins(c, hand.honorMelds, t, ctx);
      }
      accepted.add(AcceptedTile(
        t,
        hand.remainCount(t),
        isWin: base == 0,
        wins: wins,
      ));
    }
    c[t]--;
  }
  return UkeireResult(base, accepted);
}

/// 已胡展示态（14 张直接判胡）的全分解评估（winTile 传 -1）。
List<WinWithFan> evaluateWinStructures(
  Uint8List c14,
  Set<int> honorMelds,
  WinContext ctx, {
  int winTile = -1,
}) =>
    _evaluateWins(c14, honorMelds, winTile, ctx);

List<WinWithFan> _evaluateWins(
  Uint8List c,
  Set<int> honorMelds,
  int winTile,
  WinContext ctx,
) {
  final structs = decompose(c);
  var best = 0;
  final wins = <WinWithFan>[];
  for (final s in structs) {
    final score = evaluateFan(
      c14: c,
      honorMelds: honorMelds,
      winTile: winTile,
      structure: s,
      ctx: ctx,
    );
    if (score.canWin && score.multiplier > best) best = score.multiplier;
    wins.add(WinWithFan(s, score));
  }
  wins.sort((a, b) {
    final byWin = (b.score.canWin ? 1 : 0) - (a.score.canWin ? 1 : 0);
    if (byWin != 0) return byWin;
    return b.score.multiplier.compareTo(a.score.multiplier);
  });
  return [
    for (final w in wins)
      WinWithFan(w.structure, w.score,
          isBest: w.score.canWin && w.score.multiplier == best),
  ];
}
