import 'dart:math' as math;

import 'package:flutter/material.dart';

/// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
///  AppGlassTheme · 现代清新微拟物 + 玻璃拟态 设计系统令牌
///  Modern Fresh Skeuo-Glassmorphism Design Tokens
///
///  【统一光源方向】所有渐变与阴影固定为「左上 → 右下」：
///    - 受光面（渐变亮端）永远在 topLeft；
///    - 投影（阴影 offset）永远朝向右下（x/y 为正）；
///    - 凹槽内阴影相反：顶部内侧背光（暗），底部内侧受光（亮）。
/// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

/// 光源方向常量：渐变统一使用 [GlassLight.begin] → [GlassLight.end]。
abstract final class GlassLight {
  static const Alignment begin = Alignment.topLeft; // 受光角
  static const Alignment end = Alignment.bottomRight; // 背光角
}

/// 色彩令牌（Color Tokens）。
abstract final class GlassColors {
  // —— 品牌色板（高明度淡彩） ——
  static const Color mint = Color(0xFF64D2B7); // 薄荷绿 · 主色（成功 / 听牌）
  static const Color iceBlue = Color(0xFF70B6FF); // 冰蓝 · 辅色（计算 / 进张）
  static const Color lavender = Color(0xFFA58BFF); // 薰衣草紫 · 点缀（庆祝 / 强调）
  static const Color canvas = Color(0xFFF8FAFC); // 冷灰白 · 画布基底

  // —— 深化色（浅色玻璃面上的文字/图标，保证对比度 ≥ 4.5:1） ——
  static const Color mintDeep = Color(0xFF0D9C80);
  static const Color iceDeep = Color(0xFF2E6FD0);
  static const Color lavenderDeep = Color(0xFF6F4FD4);

  // —— 功能色（清新系，禁止脏灰与高饱和） ——
  static const Color success = mint;
  static const Color warning = Color(0xFFFFB454); // 柔杏 · 提示 / 打牌建议
  static const Color warningDeep = Color(0xFFAD6410);
  static const Color danger = Color(0xFFFF8FA3); // 樱粉 · 错误 / 警示
  static const Color dangerDeep = Color(0xFFD6385F);
  static const Color neutral = Color(0xFF9DB0BC); // 中性态（未听等）
  static const Color neutralDeep = Color(0xFF5F7482);

  // —— 文字色（青灰 slate 系，避免纯黑生硬） ——
  static const Color textPrimary = Color(0xFF1B2A33); // 主文字
  static const Color textSecondary = Color(0xFF556774); // 次文字
  static const Color textTertiary = Color(0xFF93A3AE); // 占位 / 弱提示
  static const Color textOnAccent = Color(0xFFFFFFFF); // 彩色底上的文字

  // —— 玻璃材质 ——
  static const Color glassWhite = Color(0xFFFFFFFF); // 玻璃本体色（以不同 alpha 使用）
  static const Color shadowInk = Color(0xFF33526B); // 中性投影墨色（冷调，不发脏）
  static const Color scrim = Color(0xFF1B2A33); // 弹层遮罩基色（低 alpha 使用）
}

/// 文字样式（Typography）。
abstract final class GlassTypography {
  static const TextStyle display = TextStyle(
    fontSize: 26,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: GlassColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 19,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: GlassColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle titleSm = TextStyle(
    fontSize: 15.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: GlassColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w500,
    color: GlassColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: GlassColors.textTertiary,
  );

  /// 彩色玻璃底上的强调文字。
  static const TextStyle onGlass = TextStyle(
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
  static ThemeData themeData() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: GlassColors.mint,
        onPrimary: GlassColors.textOnAccent,
        secondary: GlassColors.iceBlue,
        onSecondary: GlassColors.textOnAccent,
        tertiary: GlassColors.lavender,
        surface: GlassColors.canvas,
        onSurface: GlassColors.textPrimary,
        error: GlassColors.danger,
        onError: GlassColors.textOnAccent,
      ),
    );
    return base.copyWith(
      // Scaffold 透明：背景色由 AmbientGlassBackground 环境底图提供
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.apply(
        bodyColor: GlassColors.textPrimary,
        displayColor: GlassColors.textPrimary,
      ),
      // 自研组件自带按压反馈，关闭 Material 水波纹避免玻璃面上的灰闪
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerTheme: const DividerThemeData(
        color: Color(0x14243947),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: snackBarTheme(base),
    );
  }

  static SnackBarThemeData snackBarTheme(ThemeData base) => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF2FFFFFF),
        contentTextStyle: GlassTypography.onGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlassRadius.md),
          side: const BorderSide(color: Color(0x66FFFFFF), width: 1),
        ),
      );
}
