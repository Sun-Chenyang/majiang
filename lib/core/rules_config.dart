/// 胡牌情境（docs/02-技术方案设计.md §3.3）。
///
/// 规则已全部裁决固定（2026-08-16，用户拍板），无持久化配置：
///  - 卡五星：手中 4、6 卡张夹 5（筒/条同计）×2；
///  - 屁胡只能自摸（点炮胡须有其他番型）。
library;

/// 胡牌情境开关（影响番型判定与可行性，纯输入不持久化）。
class WinContext {
  /// 自摸（屁胡可行、暗四归一前提）。默认 false = 点炮/待定。
  final bool selfDraw;

  /// 杠上补牌后自摸（杠上开花 ×2，蕴含自摸）。
  final bool afterGang;

  /// 抢杠胡（他家补杠的那张，×2）。
  final bool robKong;

  /// 杠上炮（胡的是他家杠后打出的牌，×2）。
  final bool gangPao;

  const WinContext({
    this.selfDraw = false,
    this.afterGang = false,
    this.robKong = false,
    this.gangPao = false,
  });

  static const WinContext defaults = WinContext();

  WinContext copyWith({
    bool? selfDraw,
    bool? afterGang,
    bool? robKong,
    bool? gangPao,
  }) =>
      WinContext(
        selfDraw: selfDraw ?? this.selfDraw,
        afterGang: afterGang ?? this.afterGang,
        robKong: robKong ?? this.robKong,
        gangPao: gangPao ?? this.gangPao,
      );
}
