import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_glass_theme.dart';

/// 底部导航条目。
class GlassBottomBarItem {
  const GlassBottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.activeColor,
  });

  final IconData icon;

  /// 选中态图标（建议 filled 变体，随玻璃卡片一起展示）。
  final IconData activeIcon;

  final String label;

  /// 选中强调色（玻璃卡片内的图标/文字）；缺省时按 薄荷 → 冰蓝 → 薰衣草 轮换。
  final Color? activeColor;
}

/// 悬浮液态玻璃底部导航栏（iOS Liquid-Glass 风 Tab）。
///
/// 分层结构（自下而上）：
///   ① 船体：近乎无色的透明模糊 —— 只有 BackdropFilter σ=24 与
///      α≈0.10 的极淡白染色 + RimLight 描边，通透感来自模糊本身；
///   ② 选中玻璃卡片：一块包裹「图标 + 标题」的小磨砂卡片，从上一
///      选中槽位平移滑入，easeOutBack 非线性曲线带轻微回弹；
///   ③ 槽位内容：选中 = 图标+文字（居中，与卡片严格对齐），
///      未选中 = 仅图标（垂直居中于整条 bar），随选中态 fade+scale 切换。
///
/// 卡片与内容分层渲染：卡片只是滑动的背景，内容即时切换 ——
/// 这样平移动画不需要搬运内容，视觉上"卡片滑过来罩住新内容"。
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.pillWidth = 96,
  });

  final List<GlassBottomBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// 选中玻璃卡片宽度。需容纳「图标+文字」横排（约 70px），
  /// 96 在 3~5 个 Tab 的常见槽位宽度下均能居中放下。
  final double pillWidth;

  /// 布局标尺：卡片 11~53 垂直居中于 64 高的 bar，图标带中心 = 32。
  static const double barHeight = 64;
  static const double _pillTop = 11;
  static const double _pillHeight = 42;

  Color _accentOf(int i) =>
      items[i].activeColor ??
      [GlassColors.mint, GlassColors.iceBlue, GlassColors.lavender][i % 3];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / items.length;
        final pillW = pillWidth.clamp(0.0, slotWidth - 8);
        final active = currentIndex.clamp(0, items.length - 1);

        return SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ① 透明模糊船体
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(GlassRadius.xl),
                  child: BackdropFilter(
                    // σ=10：轻磨砂 —— 背景色块与轮廓保持可辨认，
                    // 玻璃的"透"优先于"糊"
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: CustomPaint(
                      foregroundPainter: _BarGlassPainter(
                        radius: GlassRadius.xl,
                      ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: GlassLight.begin,
                            end: GlassLight.end,
                            // 浅色 α0.14→0.05 极淡染色，通透靠模糊本身；
                            // 暗色为深板岩半透，船体在暗底上保有体量
                            colors: [
                              GlassColors.current.hullHi,
                              GlassColors.current.hullLo,
                            ],
                          ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),

              // ② 选中玻璃卡片：非线性平移 + 回弹
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack, // 过冲≈1.1，液态玻璃的"果冻感"
                top: _pillTop,
                left: slotWidth * active + (slotWidth - pillW) / 2,
                width: pillW,
                child: const _LiquidGlassPill(height: _pillHeight),
              ),

              // ③ 槽位内容
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(child: _slot(context, i)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _slot(BuildContext context, int i) {
    final item = items[i];
    final selected = i == currentIndex;
    final accent = _accentOf(i);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) HapticFeedback.selectionClick();
        onTap(i);
      },
      child: SizedBox(
        height: barHeight,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.82, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: selected
                ? _gradientContent(item, accent)
                : Icon(
                    item.icon,
                    key: const ValueKey('tab_inactive'),
                    size: 22,
                    color: GlassColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }

  /// 选中内容：图标 + 文字套一层品牌色对角渐变（左上亮 → 右下沉），
  /// 与玻璃卡片的受光方向一致，替代单调的纯色。
  Widget _gradientContent(GlassBottomBarItem item, Color accent) {
    Widget content = Row(
      key: const ValueKey('tab_active'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.activeIcon, size: 20, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.0,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: GlassLight.begin,
        end: GlassLight.end,
        // 暗色换提亮 Deep 变体：基础品牌色（尤其 lavender/iceBlue）
        // 在暗玻璃船体上亮度不足，浅色光斑穿透后更糊
        colors: [
          GlassColors.accentOnGlass(accent).lighten(0.18),
          GlassColors.accentOnGlass(accent).darken(0.06),
        ],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: content,
    );
  }
}

/// 液态玻璃卡片（选中态背景）：
/// 叠加在船体模糊之上的第二层磨砂 —— 双层 BackdropFilter 让卡片
/// 比船体更朦胧、更亮，形成液态玻璃的"厚折射"层次。
/// 描边画在裁剪层之外（完整圆角），裁剪半径收缩到描边内缘。
class _LiquidGlassPill extends StatelessWidget {
  const _LiquidGlassPill({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final borderWidth = 1.1;
    final innerRadius = BorderRadius.circular(height / 2 - borderWidth / 2);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: GlassColors.rim(0.8),
            width: borderWidth,
          ),
          // 灰墨投影在浅色底图上显脏：液态玻璃的立体层次靠双层磨砂
          // + RimLight 描边表达，浅色不用影；暗色保留淡黑影维持悬浮深度
          boxShadow: GlassColors.isDark
              ? GlassShadow.chip(GlassColors.shadowInk)
              : null,
        ),
        child: ClipRRect(
          borderRadius: innerRadius,
          child: BackdropFilter(
            // 二级模糊 σ=10：对已被船体模糊的内容再细化，透出"厚玻璃"质感
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: CustomPaint(
              foregroundPainter: _PillRimPainter(radius: height / 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: GlassLight.begin,
                    end: GlassLight.end,
                    // 比船体明显更实的白玻璃（暗色收敛为低透明白）
                    colors: [
                      GlassColors.surface(0.52),
                      GlassColors.surface(0.26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 船体玻璃质感：① 上表面反光带（顶部 40% 区域白色渐隐，模拟
/// 光线掠过玻璃上表面的宽反射）+ ② RimLight 棱线描边。
/// 这两层"亮部"是通透玻璃感的关键 —— 玻璃之所以像玻璃，
/// 靠的是反光层次而非模糊强度。
class _BarGlassPainter extends CustomPainter {
  _BarGlassPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ① 上表面反光带（sheen）
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * 0.4),
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height * 0.4),
          [
            Colors.white.withValues(alpha: 0.20), // 顶部反光较强
            Colors.white.withValues(alpha: 0), // 40% 高度处完全消散
          ],
        ),
    );
    canvas.restore();

    // ② RimLight 棱线
    final stroke = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(stroke / 2),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          Colors.white.withValues(alpha: 0.8), // 受光棱：亮（玻璃棱线反光）
          Colors.white.withValues(alpha: 0.08),
        ]),
    );
  }

  @override
  bool shouldRepaint(_BarGlassPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// 卡片 RimLight：左上亮棱，果冻高光感。
class _PillRimPainter extends CustomPainter {
  _PillRimPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(stroke / 2),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.1),
        ]),
    );
  }

  @override
  bool shouldRepaint(_PillRimPainter oldDelegate) =>
      oldDelegate.radius != radius;
}
