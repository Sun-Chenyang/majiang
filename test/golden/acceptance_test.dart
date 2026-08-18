/// M9.1 验收用例回归清单：跑 test/golden/acceptance_cases.dart 全部 30 组。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/meld_advice.dart';
import 'package:kawuxing/core/result.dart';
import 'package:kawuxing/core/ting.dart';
import 'package:kawuxing/core/tile.dart';

import '../core/test_util.dart';
import 'acceptance_cases.dart';

HandState buildHand(AcceptanceCase c) {
  final concealed = hand(c.tiles);
  final honorMelds = c.honorMelds.map(parseTile).toSet();
  Uint8List? seen;
  if (c.seen.isNotEmpty) {
    seen = Uint8List(kTileKindCount);
    c.seen.forEach((name, n) => seen![parseTile(name)] = n);
  }
  return HandState(concealed, honorMelds, externalSeen: seen);
}

/// 全部可胡分解（已胡 = winStructures；听牌 = 各胡牌张的 wins）。
List<WinWithFan> allWins(HandAnalysis r) {
  if (r.drawPhase && r.isWin) return r.winStructures;
  return [
    for (final a in r.ukeire?.accepted ?? const <AcceptedTile>[])
      ...(a.wins ?? const <WinWithFan>[])
  ];
}

void main() {
  test('用例规模：PRD §7 要求 ≥ 30 组', () {
    expect(kAcceptanceCases.length, greaterThanOrEqualTo(30));
  });

  for (final c in kAcceptanceCases) {
    test('${c.id} · ${c.name}', () {
      final result = analyzeHand(buildHand(c), c.ctx);
      expect(result.validPhase, isTrue, reason: '张数应合法');

      if (c.shanten != null) expect(result.shanten, c.shanten);
      if (c.tenpai != null) expect(result.isTenpai, c.tenpai);
      if (c.win != null) expect(result.isWin, c.win!);
      if (c.hasNotice != null) {
        expect(result.notices.isNotEmpty, c.hasNotice!);
      }

      // 进张全量集合 + 每张剩余
      final w = c.waits;
      if (w != null) {
        final ukeire = result.ukeire!;
        final actual = {
          for (final a in ukeire.accepted) tileName(a.tile): a.remain,
        };
        expect(actual, w, reason: '进张集合与剩余张数');
      }

      // 最优可胡番型（跨全部分解取最高倍数）
      final wins = allWins(result).where((x) => x.score.canWin).toList();
      if (c.allBlocked) {
        expect(wins, isEmpty, reason: '点炮下应无可胡分解');
      }
      if (c.bestFan != null) {
        expect(wins, isNotEmpty, reason: '应存在可胡分解');
        final bestMult = wins
            .map((x) => x.score.multiplier)
            .reduce((a, b) => a > b ? a : b);
        final best = wins.firstWhere(
            (x) => x.score.multiplier == bestMult);
        expect(best.score.describe, c.bestFan);
        if (c.bestMultiplier != null) expect(bestMult, c.bestMultiplier);
      }

      if (c.minWinStructures != null) {
        expect(result.winStructures.length,
            greaterThanOrEqualTo(c.minWinStructures!),
            reason: '多分解全展示');
      }

      // 打牌建议
      if (c.bestDiscard != null) {
        final options = result.advice!.options;
        expect(options, isNotEmpty);
        expect(tileName(options.first.discard), c.bestDiscard);
        expect(options.first.tenpai, isTrue, reason: '最优切牌应进听');
      }
      if (c.lossHints != null) {
        final actual = result.advice!.lossHints
            .map((k, v) => MapEntry(tileName(k), v));
        expect(actual, c.lossHints);
      }

      // 碰/杠时机（M8.3）
      final p = c.pengImprovements;
      if (p != null) {
        final meld = result.meldAdvice!;
        for (final entry in p.entries) {
          final t = parseTile(entry.key);
          final opt = meld.options
              .singleWhere((o) => !o.isGang && o.tile == t);
          expect(opt.shantenAfter, entry.value,
              reason: '碰${entry.key}后向听数');
          expect(isRecommendedOption(opt, meld), isTrue,
              reason: '碰${entry.key}应被推荐');
        }
      }
    });
  }
}
