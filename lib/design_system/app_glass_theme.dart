import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_palette.dart';

export 'glass_palette.dart';

/// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
///  AppGlassTheme · 现代清新微拟物 + 玻璃拟态 设计系统令牌
///  Modern Fresh Skeuo-Glassmorphism Design Tokens
///
///  【统一光源方向】所有渐变与阴影固定为「左上 → 右下」：
///    - 受光面（渐变亮端）永远在 topLeft；
///    - 投影（阴影 offset）永远朝向右下（x/y 为正）；
///    - 凹槽内阴影相反：顶部内侧背光（暗），底部内侧受光（亮）。
///    暗色主题下方向同样不变（不变式 3）。
///
///  【明暗切换】[GlassColors] 是 [GlassPalette] 的静态门面：App 根部
///  解析 ThemeMode 后把 [GlassColors.current] 指到 light/dark 调色板并
///  重建整树。因全局同一时刻只有一套主题、切换即全量重建，门面取值
///  与 widget 树保持一致（单 Shell App 的取舍，换取业务侧零 Inherited
///  查找与最小改动面）。
/// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

/// 光源方向常量：渐变统一使用 [GlassLight.begin] → [GlassLight.end]。
abstract final class GlassLight {
  static const Alignment begin = Alignment.topLeft; // 受光角
  static const Alignment end = Alignment.bottomRight; // 背光角
}

/// 色彩令牌门面（Color Tokens）：成员语义见 [GlassPalette]。
abstract final class GlassColors {
  /// 当前调色板（根部在 build 中随 ThemeMode 同步，幂等赋值）。
  static GlassPalette current = GlassPalette.light;

  static bool get isDark => current.isDark;

  // —— 品牌色板（高明度淡彩） ——
  static Color get mint => current.mint; // 薄荷绿 · 主色（成功 / 听牌）
  static Color get iceBlue => current.iceBlue; // 冰蓝 · 辅色（计算 / 进张）
  static Color get lavender => current.lavender; // 薰衣草紫 · 点缀（庆祝）
  static Color get canvas => current.canvas; // 画布基底

  // —— 深化色（玻璃面上的文字/图标；暗色下为提亮色，对比度 ≥ 4.5:1） ——
  static Color get mintDeep => current.mintDeep;
  static Color get iceDeep => current.iceDeep;
  static Color get lavenderDeep => current.lavenderDeep;

  // —— 功能色（清新系，禁止脏灰与高饱和） ——
  static Color get success => current.mint;
  static Color get warning => current.warning; // 柔杏 · 提示 / 打牌建议
  static Color get warningDeep => current.warningDeep;
  static Color get danger => current.danger; // 樱粉 · 错误 / 警示
  static Color get dangerDeep => current.dangerDeep;
  static Color get neutral => current.neutral; // 中性态（未听等）
  static Color get neutralDeep => current.neutralDeep;

  // —— 文字色（青灰 slate 系，避免纯黑生硬） ——
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textTertiary => current.textTertiary;
  static Color get textOnAccent => current.textOnAccent;

  // —— 玻璃材质 ——
  static Color get glassWhite => current.glass; // 玻璃本体色（随主题）
  static Color get shadowInk => current.shadowInk; // 投影墨色
  static Color get scrim => current.scrim; // 弹层遮罩基色

  // —— 白玻璃表面（暗色自动收敛为低透明白） ——
  static Color surface(double alpha) => current.surface(alpha);
  static Color rim(double alpha) => current.rim(alpha);
  static Color tintForGlass(Color tint) => current.tintForGlass(tint);

  /// 品牌色在玻璃面上做文字/图标的可读变体（暗色换提亮 Deep）。
  static Color accentOnGlass(Color brand) => current.accentOnGlass(brand);
}

/// 文字样式（Typography）：颜色取当前调色板，字号/字重两套一致。
abstract final class GlassTypography {
  static TextStyle get display => TextStyle(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: GlassColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get title => TextStyle(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: GlassColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get titleSm => TextStyle(
        fontSize: 15.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: GlassColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w500,
        color: GlassColors.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: GlassColors.textTertiary,
      );

  /// 高对比辅助字：直接落在环境底图（明暗流动的光斑）上的副标题、
  /// 搜索提示与列表描述用。tertiary 在浅色光斑上对比仅 ~2.2-2.6:1，
  /// 这类背景不定的文字一律升到 textSecondary（玻璃面上的装饰性
  /// 辅助字仍用 [caption]）。
  static TextStyle get captionStrong => TextStyle(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: GlassColors.textSecondary,
      );

  /// 彩色玻璃底上的强调文字。
  static TextStyle get onGlass => TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: GlassColors.textPrimary,
      );
}

/// 圆角规范（Radius Tokens）。
abstract final class GlassRadius {
  static const double xs = 10; // 微型元素：角标、小 chip
  static const double sm = 14; // 输入框、列表行
  static const double md = 18; // 次级卡片
  static const double lg = 24; // 主卡片、玻璃面板
  static const double xl = 30; // 弹层抽屉、底部导航
  static const double pill = 999; // 胶囊
}

/// 动效时长（Motion Tokens）。
abstract final class GlassDuration {
  static const Duration press = Duration(milliseconds: 110); // 按压物理反馈
  static const Duration switchToggle = Duration(milliseconds: 260); // 选中切换滑动
  static const Duration focus = Duration(milliseconds: 220); // 输入框聚焦光晕
  static const Duration ambient = Duration(seconds: 7); // 环境光斑漂移周期
}

/// 阴影规范：双层柔影 = 近影（染色）+ 远影（漫反射）。
///
/// 微拟物的立体感来自「彩色环境反光」而非黑灰死影：
///  - 近影：小 offset、小 blur，颜色取环境色（玻璃把背景光染进影子）；
///  - 远影：大 offset(右下)、大 blur、低 alpha，模拟漫反射悬浮感。
abstract final class GlassShadow {
  /// 标准玻璃悬浮影。[ambient] 为环境染色（通常传页面主色调）。
  static List<BoxShadow> soft([Color? ambient]) {
    final tint = ambient ?? GlassColors.iceBlue;
    return [
      // 近影：贴合作物，向右下偏移 2~6px，染环境色
      BoxShadow(
        color: tint.withValues(alpha: 0.20),
        blurRadius: 14,
        offset: const Offset(2, 6),
      ),
      // 远影：中性墨色，大范围低浓度，制造空气感
      BoxShadow(
        color: GlassColors.shadowInk.withValues(alpha: 0.10),
        blurRadius: 30,
        offset: const Offset(8, 18),
      ),
    ];
  }

  /// 小元素（chip / 小按钮 / 浮标）用影。
  static List<BoxShadow> chip([Color? tint]) {
    final c = tint ?? GlassColors.shadowInk;
    return [
      BoxShadow(
        color: c.withValues(alpha: 0.18),
        blurRadius: 8,
        offset: const Offset(1, 3), // 右下小位移
      ),
    ];
  }

  /// 按压态影：收缩至贴地，体现物理下陷。
  static List<BoxShadow> pressed(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.22),
          blurRadius: 4,
          offset: const Offset(0, 1), // 几乎零位移 = 物体被压进平面
        ),
      ];
}

/// 颜色混合扩展：受光面提亮 / 背光面压暗（替代老旧拟物的灰阶叠加）。
///
/// 注意：Flutter 3.44 的 [Color.r]/[Color.g]/[Color.b] 均为 0.0~1.0
/// 归一化分量（[Color.a] 同为 0~1），混合直接在归一化空间进行。
extension GlassColorX on Color {
  /// 向白色混合 [t]（0~1）：生成受光面（渐变亮端）。
  Color lighten([double t = 0.18]) {
    double mix(double v) => v + (1.0 - v) * t;
    return Color.from(
      alpha: a,
      red: mix(r),
      green: mix(g),
      blue: mix(b),
    );
  }

  /// 向黑色混合 [t]（0~1）：生成背光面（渐变暗端 / 按压暗面）。
  Color darken([double t = 0.18]) {
    double mix(double v) => v * (1.0 - t);
    return Color.from(
      alpha: a,
      red: mix(r),
      green: mix(g),
      blue: mix(b),
    );
  }
}

/// 全局滚动行为：iOS 式拖动回弹 + Android 式惯性截停。
///
/// - [ClampedBouncingScrollPhysics]：
///   · 拖动：越界跟手（iOS 阻尼），越界距离钳制在 ±64px；
///   · 惯性（fling）：到边界即停，速度按剩余距离预截，
///     不会带着动能飞出屏幕再慢慢弹回；
///   · 越界中松手：弹簧快速收回边界。
/// - parent [AlwaysScrollableScrollPhysics]：内容不足一屏也能拖出回弹；
/// - 去掉 overscroll glow 指示器（回弹本身就是越界反馈）。
class GlassScrollBehavior extends MaterialScrollBehavior {
  const GlassScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampedBouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

/// 混合手感物理：拖动 bounce + 惯性 clamp。
class ClampedBouncingScrollPhysics extends BouncingScrollPhysics {
  const ClampedBouncingScrollPhysics({super.parent, this.maxOverscroll = 64});

  final double maxOverscroll;

  @override
  ClampedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ClampedBouncingScrollPhysics(
        parent: buildParent(ancestor),
        maxOverscroll: maxOverscroll,
      );

  // —— 拖动阶段：iOS 阻尼 + 渐进弹性钳制（软墙） ——

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // 注意返回值语义：ScrollPosition 会执行 setPixels(pixels - 返回值)，
    // 即"将从 pixels 中减去的量"（向下拖 → 返回正数）
    final adjusted = super.applyPhysicsToUserOffset(position, offset);
    final desired = position.pixels - adjusted;

    // 未触及钳制区（含界外 64px 线性段以内）：原样通过，保持 iOS 阻尼手感
    final linearLimit = position.minScrollExtent - maxOverscroll;
    if (desired >= linearLimit && desired <= position.maxScrollExtent + maxOverscroll) {
      return adjusted;
    }

    // 软墙：线性段之后的越界量经指数渐近映射 —— 拖得越狠阻力越大，
    // 但始终留一丝弹性响应（渐近于线性段 + 20% 余量），不会突然卡死
    final double target;
    if (desired < position.minScrollExtent) {
      final raw = position.minScrollExtent - desired;
      target = position.minScrollExtent - _softOverscroll(raw, maxOverscroll);
    } else {
      final raw = desired - position.maxScrollExtent;
      target = position.maxScrollExtent + _softOverscroll(raw, maxOverscroll);
    }
    return position.pixels - target;
  }

  /// 渐进弹性映射：raw ≤ [linear] 时 1:1 跟手；超过后以指数曲线
  /// 渐近于 linear + 20% 余量。在 linear 处函数值与导数均连续（无跳变）。
  static double _softOverscroll(double raw, double linear) {
    if (raw <= linear) return raw;
    final stretch = linear * 0.2; // 弹性余量：橡皮筋最后一段可拉伸总量
    final asymptote = linear + stretch;
    return asymptote - stretch * math.exp(-(raw - linear) / stretch);
  }

  // —— 惯性阶段：完整重写，杜绝越界飞行 ——

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);

    // 越界中松手（≤64px）：弹簧收回边界。
    // 初速度置 0 —— 不继承用户的甩动速度：弹簧若带大初速会先冲出
    // 几百像素再慢慢拉回（"一甩就飞出去"的元凶）
    if (position.outOfRange) {
      final double end = position.pixels > position.maxScrollExtent
          ? position.maxScrollExtent
          : position.minScrollExtent;
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        end,
        0.0,
        tolerance: tolerance,
      );
    }

    if (velocity.abs() < tolerance.velocity) return null;

    // 已贴边界且速度朝外：直接停住（不再飞出）
    if (velocity > 0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0 && position.pixels <= position.minScrollExtent) {
      return null;
    }

    // 范围内惯性：Android spline 滚动，速度按剩余距离预截，
    // 使滚动恰好停在边界（而非冲出后再弹回）
    final double remaining = velocity > 0
        ? position.maxScrollExtent - position.pixels
        : position.pixels - position.minScrollExtent;
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: _velocityLimitedByDistance(velocity, remaining),
      tolerance: tolerance,
    );
  }

  /// 由 [ClampingScrollSimulation] 的解析式反解速度：
  /// duration(v) = decelRate·inflexion·(v/refV)^(1/decelRate)
  /// distance(v) = v·duration/decelRate ∝ v^(1+1/decelRate)
  /// 若 distance 超过剩余距离，反解恰好停在剩余距离处的安全速度。
  static double _velocityLimitedByDistance(double velocity, double remaining) {
    const friction = 0.015; // 与 ClampingScrollSimulation 默认一致
    const physicalCoeff = 9.80665 * 39.37 * 160.0 * 0.84;
    const inflexion = 0.35;
    final decelRate = math.log(0.78) / math.log(0.9);
    final refV = friction * physicalCoeff / inflexion;
    final exponent = 1.0 + 1.0 / decelRate; // distance 对 v 的幂

    final v = velocity.abs();
    final distance =
        inflexion * math.pow(v, exponent) * math.pow(refV, -1.0 / decelRate);
    if (distance <= remaining || !remaining.isFinite) return velocity;

    final vSafe = math.pow(
      remaining / (inflexion * math.pow(refV, -1.0 / decelRate)),
      1.0 / exponent,
    ) as double;
    return vSafe * velocity.sign;
  }

  @override
  bool operator ==(Object other) =>
      other is ClampedBouncingScrollPhysics &&
      other.maxOverscroll == maxOverscroll &&
      super == other;

  @override
  int get hashCode => Object.hash(runtimeType, maxOverscroll, parent);
}

/// 全局 Material 主题装配：让原生控件（Switch / Snackbar 等）跟随玻璃体系。
abstract final class AppGlassTheme {
  static ThemeData themeData({Brightness brightness = Brightness.light}) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: Color(0xFF64D2B7),
              onPrimary: Colors.white,
              secondary: Color(0xFF70B6FF),
              onSecondary: Colors.white,
              tertiary: Color(0xFFA58BFF),
              surface: Color(0xFF10161D),
              onSurface: Color(0xFFE9EFF5),
              error: Color(0xFFFF8FA3),
              onError: Colors.white,
            )
          : const ColorScheme.light(
              primary: Color(0xFF64D2B7),
              onPrimary: Colors.white,
              secondary: Color(0xFF70B6FF),
              onSecondary: Colors.white,
              tertiary: Color(0xFFA58BFF),
              surface: Color(0xFFF8FAFC),
              onSurface: Color(0xFF1B2A33),
              error: Color(0xFFFF8FA3),
              onError: Colors.white,
            ),
    );
    return base.copyWith(
      // Scaffold 透明：背景色由 AmbientGlassBackground 环境底图提供
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.apply(
        bodyColor: dark ? GlassPalette.dark.textPrimary : GlassPalette.light.textPrimary,
        displayColor:
            dark ? GlassPalette.dark.textPrimary : GlassPalette.light.textPrimary,
      ),
      // 自研组件自带按压反馈，关闭 Material 水波纹避免玻璃面上的灰闪
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(
        // 暗色下分隔线用低透明白（浅色为低透明冷墨）
        color: dark
            ? const Color(0x24FFFFFF)
            : const Color(0x14243947),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: _snackBarTheme(dark),
    );
  }

  static SnackBarThemeData _snackBarTheme(bool dark) => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xE6223041) // 暗色玻璃实体
            : const Color(0xF2FFFFFF),
        contentTextStyle: GlassTypography.onGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.md),
          side: BorderSide(
            color: dark ? GlassColors.rim(0.4) : const Color(0x66FFFFFF),
            width: 1,
          ),
        ),
      );
}
