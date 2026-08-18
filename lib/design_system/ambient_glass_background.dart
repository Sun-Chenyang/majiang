import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_glass_theme.dart';

/// 弥散渐变环境底图（Ambient Glass Background）。
///
/// 在 App 最底层铺一层「冷灰白基底 + 多枚柔和彩色光斑（Aura）」：
///  - 光斑用 [ui.Gradient.radial] 绘制，径向渐变天然弥散，
///    不需要全屏 Blur filter，单帧仅 8 次 drawCircle，性能极佳；
///  - 光斑随时间缓慢漂移（周期 [GlassDuration.ambient]），让上层
///    玻璃卡片的折射内容产生「色彩流动感」；
///  - 外层 [RepaintBoundary] 隔离重绘：光斑动画只重画自身图层，
///    不会引发业务子树的 paint 风暴。
class AmbientGlassBackground extends StatefulWidget {
  const AmbientGlassBackground({
    super.key,
    required this.child,
    this.animate = true,
  });

  final Widget child;

  /// 是否开启光斑漂移动画；关闭时定格在 t=0（省电模式 / 无障碍场景）。
  final bool animate;

  @override
  State<AmbientGlassBackground> createState() => _AmbientGlassBackgroundState();
}

class _AmbientGlassBackgroundState extends State<AmbientGlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GlassDuration.ambient,
  );

  /// animate=false 时用静止动画源，painter 不会收到任何 repaint 通知。
  Animation<double> get _t =>
      widget.animate ? _controller : const AlwaysStoppedAnimation(0);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(AmbientGlassBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate == old.animate) return;
    widget.animate ? _controller.repeat() : _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        // painter（而非 foregroundPainter）：光斑画在页面内容之下，
        // 上层玻璃卡片才能"折射"出底图的色彩
        painter: _AmbientPainter(animation: _t),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// 单枚光斑的静态描述。
class _Blob {
  const _Blob({
    required this.alignment,
    required this.radiusFactor,
    required this.color,
    required this.alpha,
    required this.driftFactor,
    required this.phaseX,
    required this.phaseY,
    this.pulseSpeed = 1.0,
  });

  final Alignment alignment; // 光斑锚点（Alignment 归一化坐标）
  final double radiusFactor; // 半径 = 因子 × 屏幕长边
  final Color color; // 光斑色相
  final double alpha; // 中心峰值透明度（0.2~0.45：保持高明度通透）
  final double driftFactor; // 漂移振幅 = 因子 × 屏幕长边
  final double phaseX; // X 向漂移相位（错开各光斑节奏）
  final double phaseY; // Y 向漂移相位
  final double pulseSpeed; // 浓度呼吸频率（相对漂移周期的倍频）
}

/// 八色光斑编队（高明度淡彩）：
///   薄荷(左上主光) / 冰蓝(右上) / 薰衣草(左下) / 暖杏(右下)
///   + 樱花粉(右中) / 柔黄(左中) / 湖青(下中) / 白高光(顶中)
/// driftFactor 0.08~0.16 + 各自独立的呼吸频率 —— 位置与浓淡双重流动，
/// 1~2 秒即可感知色彩变化。

/// 装饰光斑专用色相（仅编队使用，不入 GlassPalette 语义令牌）。
const Color _kSakura = Color(0xFFFFAEC9); // 樱花粉：清新暖调点缀
const Color _kApricot = Color(0xFFFFD9A8); // 暖杏：平衡冷调、避免画面发闷
const Color _kSoftYellow = Color(0xFFFFE486); // 柔黄：提升整体明度层次
const Color _kAqua = Color(0xFF7DE3DC); // 湖青：薄荷与冰蓝之间的过渡色相

final List<_Blob> _kBlobs = [
  _Blob(
    alignment: Alignment(-0.85, -0.7),
    radiusFactor: 0.58,
    color: GlassColors.mint,
    alpha: 0.42,
    driftFactor: 0.16,
    phaseX: 0.0,
    phaseY: 1.3,
    pulseSpeed: 0.9,
  ),
  _Blob(
    alignment: Alignment(0.95, -0.2),
    radiusFactor: 0.50,
    color: GlassColors.iceBlue,
    alpha: 0.36,
    driftFactor: 0.14,
    phaseX: 2.1,
    phaseY: 0.6,
    pulseSpeed: 1.2,
  ),
  _Blob(
    alignment: Alignment(0.8, 0.45),
    radiusFactor: 0.42,
    color: _kSakura,
    alpha: 0.30,
    driftFactor: 0.13,
    phaseX: 3.7,
    phaseY: 4.4,
    pulseSpeed: 0.7,
  ),
  _Blob(
    alignment: Alignment(-0.7, 0.9),
    radiusFactor: 0.54,
    color: GlassColors.lavender,
    alpha: 0.34,
    driftFactor: 0.15,
    phaseX: 4.2,
    phaseY: 3.1,
    pulseSpeed: 1.1,
  ),
  _Blob(
    alignment: Alignment(0.6, 1.0),
    radiusFactor: 0.36,
    color: _kApricot,
    alpha: 0.24,
    driftFactor: 0.12,
    phaseX: 1.0,
    phaseY: 5.0,
    pulseSpeed: 0.8,
  ),
  _Blob(
    alignment: Alignment(-1.0, 0.15),
    radiusFactor: 0.40,
    color: _kSoftYellow,
    alpha: 0.26,
    driftFactor: 0.13,
    phaseX: 5.3,
    phaseY: 1.9,
    pulseSpeed: 1.3,
  ),
  _Blob(
    alignment: Alignment(0.1, 1.0),
    radiusFactor: 0.46,
    color: _kAqua,
    alpha: 0.30,
    driftFactor: 0.13,
    phaseX: 2.8,
    phaseY: 0.3,
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(-0.2, -1.0),
    radiusFactor: 0.30,
    color: Colors.white, // 顶部白色高光，呼应「左上光源」
    alpha: 0.45,
    driftFactor: 0.08,
    phaseX: 3.4,
    phaseY: 2.2,
    pulseSpeed: 0.6,
  ),
];

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  /// 上次绘制时的明暗态：主题切换后与之不同则强制重绘。
  bool? _paintedDark;

  @override
  void paint(Canvas canvas, Size size) {
    _paintedDark = GlassColors.isDark;
    final rect = Offset.zero & size;
    final palette = GlassColors.current;

    // 基底：对角渐变（左上最亮 → 右下微沉，符合光源方向；暗色为深板岩系）
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          palette.ambientBase,
          const [0.0, 0.55, 1.0],
        ),
    );

    final t = animation.value * 2 * math.pi;
    for (final b in _kBlobs) {
      // Alignment(-1..1) → 像素中心点
      final base = Offset(
        size.width * (b.alignment.x + 1) / 2,
        size.height * (b.alignment.y + 1) / 2,
      );
      // 双频正弦漂移：位置随时间画"8"字轨迹，缓慢且不完全可预测
      final drift = Offset(
        math.sin(t + b.phaseX),
        math.cos(t + b.phaseY),
      ) * (b.driftFactor * size.longestSide);
      final center = base + drift;
      final radius = b.radiusFactor * size.longestSide;
      // 浓度呼吸：与漂移不同频不同相，光斑颜色忽浓忽淡 —— 位置与
      // 色彩双重流动，整体色彩变换更丰富；暗色下整体浓度收敛
      final breathe = 0.78 + 0.22 * math.sin(t * b.pulseSpeed + b.phaseX * 1.7);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [
              b.color.withValues(alpha: b.alpha * breathe * palette.blobAlphaScale), // 中心峰值（呼吸）
              b.color.withValues(alpha: 0), // 边缘完全消散（无硬边）
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      !identical(oldDelegate.animation, animation) ||
      oldDelegate._paintedDark != GlassColors.isDark;
}
