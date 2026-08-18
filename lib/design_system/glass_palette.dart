/// 玻璃调色板（Glass Palette）：同一套语义令牌的浅色 / 暗色两套值。
///
/// 设计约定（规范 §2/§3，暗色扩展）：
///  - 全局光照方向左上→右下在暗色下**不变**：受光面仍是"更亮的一端"，
///    只是暗色下的"亮"指相对提亮（低透明白），而非纯白；
///  - 品牌色（薄荷/冰蓝/薰衣草）两套共用——它们是"环境光色相"，
///    在深浅底上都成立；**Deep 系列反转**：浅色下 Deep 是加深文字色，
///    暗色下是提亮文字色（保证暗色玻璃上 ≥ 4.5:1，见 color_range_test）；
///  - 白玻璃表面在暗色下按 [surfaceAlphaScale] 收敛为"低透明白"，
///    避免大面积刺眼白块；牌面（象牙白实物）不参与反转。
library;

import 'package:flutter/material.dart';

/// 一套完整色彩令牌。
class GlassPalette {
  final bool isDark;

  // —— 品牌色板（两套共用） ——
  final Color mint;
  final Color iceBlue;
  final Color lavender;
  final Color canvas;

  // —— 深化色：浅色下=加深（浅底文字），暗色下=提亮（深底文字） ——
  final Color mintDeep;
  final Color iceDeep;
  final Color lavenderDeep;

  // —— 功能色 ——
  final Color warning;
  final Color warningDeep;
  final Color danger;
  final Color dangerDeep;
  final Color neutral;
  final Color neutralDeep;

  // —— 文字色：浅色青灰 slate / 暗色浅雾 slate ——
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  // —— 玻璃材质 ——
  /// 玻璃本体色（GlassCard surfaceTint 缺省）：浅色纯白 / 暗色深板岩。
  final Color glass;

  /// 投影墨色：浅色冷调蓝灰 / 暗色纯黑。
  final Color shadowInk;

  /// 弹层遮罩基色。
  final Color scrim;

  // —— 环境底图 ——
  /// 底图对角渐变（左上→右下，3 档）。
  final List<Color> ambientBase;

  /// 光斑浓度缩放：暗色约 0.55（保留色相流动但整体沉静）。
  final double blobAlphaScale;

  // —— 白玻璃表面缩放：业务里"画白玻璃"的 alpha 乘子 ——
  /// 表面填充：浅色 1.0 / 暗色 0.22（低透明白，避免刺眼）。
  final double surfaceAlphaScale;

  /// 边缘/描边高光：浅色 1.0 / 暗色 0.35。
  final double rimAlphaScale;

  // —— 大面积玻璃面（弹层 / 底栏船体）：内容可读性优先的专用填充 ——
  /// 弹层玻璃（亮端/暗端）：浅色白玻璃，暗色近实体深板岩玻璃。
  final Color sheetHi;
  final Color sheetLo;

  /// 底栏船体填充（亮端/暗端）：浅色近无色，暗色深板岩半透。
  final Color hullHi;
  final Color hullLo;

  const GlassPalette({
    required this.isDark,
    required this.mint,
    required this.iceBlue,
    required this.lavender,
    required this.canvas,
    required this.mintDeep,
    required this.iceDeep,
    required this.lavenderDeep,
    required this.warning,
    required this.warningDeep,
    required this.danger,
    required this.dangerDeep,
    required this.neutral,
    required this.neutralDeep,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.glass,
    required this.shadowInk,
    required this.scrim,
    required this.ambientBase,
    required this.blobAlphaScale,
    required this.surfaceAlphaScale,
    required this.rimAlphaScale,
    required this.sheetHi,
    required this.sheetLo,
    required this.hullHi,
    required this.hullLo,
  });

  /// 白玻璃表面填充：chips / 托盘 / 玻璃按钮等"画白玻璃"处统一走这里，
  /// 暗色下自动收敛为低透明白。
  Color surface(double alpha) =>
      Colors.white.withValues(alpha: alpha * surfaceAlphaScale);

  /// 白玻璃边缘高光 / 描边。
  Color rim(double alpha) =>
      Colors.white.withValues(alpha: alpha * rimAlphaScale);

  /// GlassCard 染色修正：暗色下把彩色 tint 向深板岩混合，
  /// 得到"彩色暗玻璃"而非高饱和亮色块；浅色原样返回。
  Color tintForGlass(Color tint) =>
      isDark ? Color.lerp(tint, glass, 0.55)! : tint;

  /// 品牌色做玻璃面上的文字/图标用色（"玻璃上可读变体"）：
  ///  - 暗色：换提亮 Deep 变体（基础品牌色亮度不足——lavender 仅
  ///    ~4.4:1，叠上浅色光斑穿透后更低；Deep 系列按 dark_palette_test
  ///    ≥ 4.5:1）；
  ///  - 浅色：换加深 Deep 变体（基础品牌色是"环境光色相"，亮度过高，
  ///    在白玻璃上对比仅 ~1.5:1——底栏选中文字实测）。
  /// 非品牌三色原样返回。底栏选中 tab 渐变文字走这里。
  Color accentOnGlass(Color brand) {
    if (brand == mint) return mintDeep;
    if (brand == iceBlue) return iceDeep;
    if (brand == lavender) return lavenderDeep;
    return brand;
  }

  static const GlassPalette light = GlassPalette(
    isDark: false,
    mint: Color(0xFF64D2B7),
    iceBlue: Color(0xFF70B6FF),
    lavender: Color(0xFFA58BFF),
    canvas: Color(0xFFF8FAFC),
    mintDeep: Color(0xFF0D9C80),
    iceDeep: Color(0xFF2E6FD0),
    lavenderDeep: Color(0xFF6F4FD4),
    warning: Color(0xFFFFB454),
    warningDeep: Color(0xFFAD6410),
    danger: Color(0xFFFF8FA3),
    dangerDeep: Color(0xFFD6385F),
    neutral: Color(0xFF9DB0BC),
    neutralDeep: Color(0xFF5F7482),
    textPrimary: Color(0xFF1B2A33),
    textSecondary: Color(0xFF556774),
    textTertiary: Color(0xFF93A3AE),
    textOnAccent: Color(0xFFFFFFFF),
    glass: Color(0xFFFFFFFF),
    shadowInk: Color(0xFF33526B),
    scrim: Color(0xFF1B2A33),
    ambientBase: [Color(0xFFFDFFFF), Color(0xFFEFF4FA), Color(0xFFE7EEF7)],
    blobAlphaScale: 1.0,
    surfaceAlphaScale: 1.0,
    rimAlphaScale: 1.0,
    sheetHi: Color(0xA8FFFFFF), // 白玻璃 α0.66
    sheetLo: Color(0x61FFFFFF), // 白玻璃 α0.38
    hullHi: Color(0x24FFFFFF), // 近无色 α0.14
    hullLo: Color(0x0DFFFFFF), // α0.05
  );

  /// 暗色调色板：深板岩基底 + 同色相光斑（浓度减半）+ 提亮 Deep 文字色。
  static const GlassPalette dark = GlassPalette(
    isDark: true,
    mint: Color(0xFF64D2B7),
    iceBlue: Color(0xFF70B6FF),
    lavender: Color(0xFFA58BFF),
    canvas: Color(0xFF10161D),
    mintDeep: Color(0xFF5CE0C3),
    iceDeep: Color(0xFF8CC6FF),
    lavenderDeep: Color(0xFFC3ABFF),
    warning: Color(0xFFFFB454),
    warningDeep: Color(0xFFFFCB85),
    danger: Color(0xFFFF8FA3),
    dangerDeep: Color(0xFFFFAEBD),
    neutral: Color(0xFF9DB0BC),
    neutralDeep: Color(0xFF9FB3C2),
    textPrimary: Color(0xFFE9EFF5),
    textSecondary: Color(0xFFABB9C6),
    textTertiary: Color(0xFF74879A),
    textOnAccent: Color(0xFFFFFFFF),
    glass: Color(0xFF223041),
    shadowInk: Color(0xFF000000),
    scrim: Color(0xFF000000),
    ambientBase: [Color(0xFF1D2735), Color(0xFF141C28), Color(0xFF0D141E)],
    blobAlphaScale: 0.55,
    surfaceAlphaScale: 0.22,
    rimAlphaScale: 0.35,
    sheetHi: Color(0xF0263650), // 近实体深板岩玻璃：内容可读性优先
    sheetLo: Color(0xD9223044),
    hullHi: Color(0x80223041), // 深板岩 α0.50：船体在暗底上保有体量
    hullLo: Color(0x4D223041), // α0.30
  );
}
