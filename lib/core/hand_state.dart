/// 手牌状态（副露省录模式）。
///
/// 卡五星行牌结构固定为"4 面子 + 1 雀头"：待摸暗牌恒为 13 − 3×副露数，
/// 待打恒为 14 − 3×副露数，因此副露组数由张数推断即可（暗杠/补杠的
/// 补摸不破坏 mod 3 循环）。已碰/杠出的牌不录入 [concealed]。
library;

import 'dart:typed_data';

import 'tile.dart';

class HandState {
  /// 长度 21 的暗牌计数（不含已碰/杠出的牌）。
  final Uint8List concealed;

  /// 已碰/杠的字牌牌种 ⊆ {中(18), 发(19), 白(20)}，默认空。
  /// 用于三元番型补全（小三元/大三元含副露刻）与剩余张数扣减。
  final Set<int> honorMelds;

  /// 他家已见张数（长 21）：他家弃牌 +1 / 他家碰 +3 / 他家杠 +4 的
  /// 累计标记（M8.4）。缺省 null = 无标记。与撤销栈无关（标记独立于
  /// 手牌编辑）；调用方负责保证单种累计 ≤ 4 − 自家已见。
  final Uint8List? externalSeen;

  const HandState(this.concealed, this.honorMelds, {this.externalSeen});

  HandState.empty()
      : concealed = Uint8List(kTileKindCount),
        honorMelds = const {},
        externalSeen = null;

  /// 暗牌总数。
  int get count {
    var s = 0;
    for (final v in concealed) {
      s += v;
    }
    return s;
  }

  /// 待打（3n+2：14/11/8/5/2 张，打牌建议态）。
  bool get isDrawPhase => count >= 2 && (count - 2) % 3 == 0;

  /// 张数合法（待摸 3n+1：13/10/7/4/1；待打 3n+2：14/11/8/5/2）。
  /// 1 张也合法（3n+1 的 n=0）：碰/杠满 4 组后单钓听牌。
  bool get validPhase =>
      count >= 1 && ((count - 1) % 3 == 0 || (count - 2) % 3 == 0);

  /// 推断的碰/杠副露组数。
  int get meldCount =>
      validPhase ? (((isDrawPhase ? 14 : 13) - count) ~/ 3) : 0;

  /// 他家已见张数（0~4）。
  int seenExternal(int t) => externalSeen?[t] ?? 0;

  /// 已见张数（自家视角）：暗牌 + 字牌副露（碰/杠一次性露出 3 张）
  /// + 他家已见标记。
  int seenCount(int t) =>
      concealed[t] + (honorMelds.contains(t) ? 3 : 0) + seenExternal(t);

  /// 剩余可摸张数（下限 0：标记超界的病态输入按 0 展示）。
  int remainCount(int t) => 4 - seenCount(t) < 0 ? 0 : 4 - seenCount(t);
}
