import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_glass_theme.dart';

/// 毛玻璃卡片（GlassCard）。
///
/// 结构自内而外：
///   BackdropFilter(磨砂) → 染色玻璃渐变(左上亮→右下沉) → RimLight 折射描边 → 双层柔影
///
/// 性能提示：BackdropFilter 每个实例都会触发一次 saveLayer，
/// 长列表 / 大量小卡片请传 [frost] = false 退化为「纯染色玻璃」，
/// 视觉 90% 相似而零模糊开销；全屏同时保持 ≤ 4 张 frosted 卡片为宜。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = GlassRadius.lg,
    this.blurSigma = 16,
    this.frost = true,
    this.surfaceTint,
    this.tintStrength = 0.5,
    this.ambient,
    this.shadow = true,
    this.rimLight = true,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 圆角（默认主卡片 24）。
  final double radius;

  /// 磨砂强度 σ：像素采样半径。16≈磨砂亚克力；8≈轻纱；列表项建议 frost=false。
  final double blurSigma;

  /// 是否启用 BackdropFilter 真实磨砂（性能开关，见类注释）。
  final bool frost;

  /// 玻璃染色：默认白玻璃（暗色下自动为深板岩玻璃）；传品牌色可得到
  /// 「薄荷玻璃 / 冰蓝玻璃」等彩色磨砂。
  final Color? surfaceTint;

  /// 染色强度 0~1：玻璃不透明度。0.5=通透；0.15=彩色薄纱（用于状态卡）。
  final double tintStrength;

  /// 阴影环境染色：让近影呼应页面主色，产生"玻璃在折射环境光"的错觉。
  final Color? ambient;

  /// 是否投影。嵌套在玻璃内的子卡可关闭，避免影子叠脏。
  final bool shadow;

  /// 是否绘制 RimLight 高光描边（顶部折射白边）。
  final bool rimLight;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    // 暗色染色修正：彩色 tint 向深板岩混合成"彩色暗玻璃"；
    // 白玻璃 tint（glassWhite 在暗色下已是深板岩）不受影响。
    final tint = GlassColors.tintForGlass(surfaceTint ?? GlassColors.glassWhite);

    // 玻璃本体：染色渐变（左上 alpha 全值 → 右下 alpha×0.6，形成受光坡面）
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            tint.withValues(alpha: tintStrength),
            tint.withValues(alpha: tintStrength * 0.6),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (frost) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          // sigmaX/sigmaY 相等 = 各向同性磨砂；只在 ClipRRect 内生效，边缘不糊出
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: body,
        ),
      );
    }

    Widget card = body;
    if (rimLight) {
      card = CustomPaint(
        foregroundPainter: _RimLightPainter(radius: radius),
        child: card,
      );
    }

    if (shadow) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: GlassShadow.soft(ambient),
        ),
        child: card,
      );
    }

    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// 顶部折射高光描边（Rim Light）：
/// 从左上 white·72% 渐隐到右下 white·6% —— 模拟光线射入玻璃后
/// 沿受光棱边聚拢的物理现象，是玻璃拟态「透」感的关键。
class _RimLightPainter extends CustomPainter {
  _RimLightPainter({required this.radius});

  final double radius;

  /// 上次绘制时的明暗态：主题切换后与之不同则强制重绘。
  bool? _paintedDark;

  @override
  void paint(Canvas canvas, Size size) {
    _paintedDark = GlassColors.isDark;
    final rect = Offset.zero & size;
    final stroke = 1.2; // 描边宽：细于 1px 会在低分屏丢失
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2), // 内缩半个笔宽，避免被裁切
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            GlassColors.rim(0.72), // 受光棱：亮白（暗色自动收敛）
            GlassColors.rim(0.06), // 背光棱：近无
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_RimLightPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate._paintedDark != GlassColors.isDark;
}
