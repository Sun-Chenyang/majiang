/// UI 阶段的演示计算引擎。
///
/// 正确性范围（当前）：
///  - 胡牌判定：精确（标准型"1 对将 + 面子" + 七对，七对按卡五星规则 4 张同牌算 2 对）；
///  - 听牌枚举：精确（对 21 种牌逐一张模拟加入后判胡）；
///  - 副露：省录模式，组数由张数推断（待摸 3n+1 / 待打 3n+2）；
///  - 向听/进张：未听牌时给出"差 1 张进听"的进张列表（加牌逼近估算，不做换打递归）；
///  - 番型：仅七对系列 / 卡五星 / 暗四归一 / 小三元 / 大三元 / 屁胡 的简化判定。
///
/// M1 阶段将按 docs/02-技术方案设计.md §4 替换为完整向听数算法与全番型判定。
library;

import 'dart:typed_data';

import 'tile.dart';

/// 一张可进/所听的牌。
class WaitInfo {
  final int tile;
  final int remain; // 剩余张数（按手牌估算，未含他家已见）
  final List<String> fanLabels;
  const WaitInfo(this.tile, this.remain, this.fanLabels);
}

/// 打牌建议的一个候选。
class DiscardOption {
  final int discard;
  final bool tenpai; // 打后是否听牌
  final List<WaitInfo> waits; // tenpai 时的听牌列表
  final List<WaitInfo> advances; // 非 tenpai 时的进张（差 1 张进听）
  final bool oneAway; // 打后是否差 1 张进听
  const DiscardOption({
    required this.discard,
    required this.tenpai,
    required this.waits,
    required this.advances,
    required this.oneAway,
  });

  int get score => tenpai
      ? waits.fold(0, (s, w) => s + w.remain)
      : (oneAway ? advances.fold(0, (s, w) => s + w.remain) : -1);
}

/// 对当前输入的整体分析结果。
class AnalysisResult {
  final int count;
  final bool validPhase; // 张数是 3n+1 / 3n+2 且 ≥ 2
  final bool drawPhase; // 3n+2：待打（打牌建议）
  final int meldCount; // 推断的碰/杠组数
  final bool isWin; // 待打且已构成胡牌
  final bool isTenpai; // 待摸且听牌
  final List<WaitInfo> waits; // 听牌列表（待摸）
  final bool oneAway; // 待摸未听但差 1 张进听
  final List<WaitInfo> advances; // 进张列表（待摸未听）
  final List<DiscardOption> options; // 打牌建议（待打）

  const AnalysisResult({
    required this.count,
    required this.validPhase,
    required this.drawPhase,
    required this.meldCount,
    required this.isWin,
    required this.isTenpai,
    required this.waits,
    required this.oneAway,
    required this.advances,
    required this.options,
  });
}

class Engine {
  /// 消面子回溯：从 [from] 起找第一个非零牌种，尝试刻子/顺子。
  /// 调用方保证传入时总数为 3 的倍数；字牌（18-20）不可组顺子。
  static bool _removeMelds(Uint8List c, int from) {
    var t = from;
    while (t < kTileKindCount && c[t] == 0) {
      t++;
    }
    if (t == kTileKindCount) return true;

    // 刻子
    if (c[t] >= 3) {
      c[t] -= 3;
      final ok = _removeMelds(c, t);
      c[t] += 3;
      if (ok) return true;
    }
    // 顺子：仅筒/条，且点数 ≤ 7（编码上同花色内 t%9 ≤ 6）
    if (t <= 17 && t % 9 <= 6 && c[t + 1] > 0 && c[t + 2] > 0) {
      c[t]--;
      c[t + 1]--;
      c[t + 2]--;
      final ok = _removeMelds(c, t);
      c[t]++;
      c[t + 1]++;
      c[t + 2]++;
      if (ok) return true;
    }
    return false;
  }

  /// 标准型胡牌：1 对将 + 若干组面子（总数 3n+2）。
  static bool canWinStandard(Uint8List c) {
    for (var t = 0; t < kTileKindCount; t++) {
      if (c[t] >= 2) {
        c[t] -= 2;
        final ok = _removeMelds(c, 0);
        c[t] += 2;
        if (ok) return true;
      }
    }
    return false;
  }

  /// 七对形态（卡五星规则：4 张同牌算 2 对；总数 14）。
  static bool isSevenPairs(Uint8List c) {
    for (var t = 0; t < kTileKindCount; t++) {
      if (c[t].isOdd) return false;
    }
    return true;
  }

  /// 胡牌判定（总数须为 3n+2；14 张时含七对）。
  static bool canWin(Uint8List c) {
    if (_total(c) == 14 && isSevenPairs(c)) return true;
    return canWinStandard(c);
  }

  static int _total(Uint8List c) {
    var s = 0;
    for (final v in c) {
      s += v;
    }
    return s;
  }

  /// 听牌枚举：[c] 为 3n+1 张，返回全部所听牌种。
  static List<int> waitsOf(Uint8List c) {
    final w = <int>[];
    for (var t = 0; t < kTileKindCount; t++) {
      if (c[t] >= 4) continue;
      c[t]++;
      if (canWin(c)) w.add(t);
      c[t]--;
    }
    return w;
  }

  /// 快速判断是否听牌。
  static bool hasWait(Uint8List c) {
    for (var t = 0; t < kTileKindCount; t++) {
      if (c[t] >= 4) continue;
      c[t]++;
      final ok = canWin(c);
      c[t]--;
      if (ok) return true;
    }
    return false;
  }

  /// 差 1 张进听的进张：摸到该牌后，存在一种打法使手牌进入听牌（[c] 为 3n+1 张）。
  /// 注意：加牌后是 3n+2 张，需再模拟打出一张才是听牌判定态。
  static List<int> advancesOf(Uint8List c) {
    final a = <int>[];
    for (var t = 0; t < kTileKindCount; t++) {
      if (c[t] >= 4) continue;
      c[t]++;
      var ok = false;
      for (var s = 0; s < kTileKindCount && !ok; s++) {
        if (c[s] == 0) continue;
        c[s]--;
        if (hasWait(c)) ok = true;
        c[s]++;
      }
      c[t]--;
      if (ok) a.add(t);
    }
    return a;
  }

  /// 简化番型标注（[c14] 为含胡牌张的 14 张；[winTile] 为所听/所胡牌，-1 表示未知）。
  static List<String> fanLabels(Uint8List c14, int winTile) {
    if (isSevenPairs(c14)) {
      var quads = 0;
      for (final v in c14) {
        if (v == 4) quads++;
      }
      return [
        switch (quads) {
          3 => '三龙七对 ×64',
          2 => '双龙七对 ×32',
          1 => '龙七对 ×16',
          _ => '七对 ×4',
        },
      ];
    }
    final labels = <String>[];
    var honorTriplets = 0;
    var honorPairs = 0;
    for (var t = 18; t < 21; t++) {
      if (c14[t] >= 3) {
        honorTriplets++;
      } else if (c14[t] == 2) {
        honorPairs++;
      }
    }
    if (honorTriplets == 3) {
      labels.add('大三元 ×8');
    } else if (honorTriplets == 2 && honorPairs >= 1) {
      labels.add('小三元 ×4');
    }
    if (winTile == kWuXing && c14[3] > 0 && c14[5] > 0) {
      labels.add('卡五星 ×2');
    }
    if (winTile >= 0 && c14[winTile] == 4) {
      labels.add('暗四归一 ×4');
    }
    labels.add('屁胡 ×1');
    return labels;
  }

  static List<WaitInfo> _waitInfos(Uint8List c, Iterable<int> tiles) {
    return tiles
        .map((t) {
          c[t]++;
          final labels = fanLabels(c, t);
          c[t]--;
          return WaitInfo(t, 4 - c[t], labels);
        })
        .toList();
  }

  /// 分析入口：[counts] 为长度 21 的暗牌计数（不含已碰/杠出的牌）。
  static AnalysisResult analyze(Uint8List counts) {
    final count = _total(counts);
    final validPhase =
        count >= 2 && ((count - 1) % 3 == 0 || (count - 2) % 3 == 0);
    final drawPhase = count >= 2 && (count - 2) % 3 == 0;
    final meldCount =
        count >= 2 ? ((drawPhase ? 14 : 13) - count) ~/ 3 : 0;

    if (!validPhase) {
      return AnalysisResult(
        count: count,
        validPhase: false,
        drawPhase: drawPhase,
        meldCount: meldCount,
        isWin: false,
        isTenpai: false,
        waits: const [],
        oneAway: false,
        advances: const [],
        options: const [],
      );
    }

    if (drawPhase) {
      final isWin = canWin(counts);
      final options = <DiscardOption>[];
      if (!isWin) {
        for (var t = 0; t < kTileKindCount; t++) {
          if (counts[t] == 0) continue;
          counts[t]--;
          final waits = waitsOf(counts);
          if (waits.isNotEmpty) {
            options.add(DiscardOption(
              discard: t,
              tenpai: true,
              waits: _waitInfos(counts, waits),
              advances: const [],
              oneAway: true,
            ));
          } else {
            final adv = advancesOf(counts);
            if (adv.isNotEmpty) {
              options.add(DiscardOption(
                discard: t,
                tenpai: false,
                waits: const [],
                advances: _waitInfos(counts, adv),
                oneAway: true,
              ));
            } else {
              options.add(DiscardOption(
                discard: t,
                tenpai: false,
                waits: const [],
                advances: const [],
                oneAway: false,
              ));
            }
          }
          counts[t]++;
        }
        options.sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) return byScore;
          return a.discard.compareTo(b.discard);
        });
      }
      return AnalysisResult(
        count: count,
        validPhase: true,
        drawPhase: true,
        meldCount: meldCount,
        isWin: isWin,
        isTenpai: false,
        waits: const [],
        oneAway: false,
        advances: const [],
        options: options,
      );
    }

    // 待摸（3n+1）：听牌判断
    final waits = waitsOf(counts);
    final isTenpai = waits.isNotEmpty;
    var oneAway = false;
    var advances = const <WaitInfo>[];
    if (!isTenpai) {
      final adv = advancesOf(counts);
      oneAway = adv.isNotEmpty;
      advances = _waitInfos(counts, adv);
    }
    return AnalysisResult(
      count: count,
      validPhase: true,
      drawPhase: false,
      meldCount: meldCount,
      isWin: false,
      isTenpai: isTenpai,
      waits: _waitInfos(counts, waits),
      oneAway: oneAway,
      advances: advances,
      options: const [],
    );
  }
}
