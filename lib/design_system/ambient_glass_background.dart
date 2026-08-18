import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_glass_theme.dart';

/// 弥散渐变环境底图（Ambient Glass Background）。
///
/// 在 App 最底层铺一层「冷灰白基底 + 多枚柔和彩色光斑（Aura）」：
///  - 光斑用 [ui.Gradient.radial] 绘制，径向渐变天然弥散，
///    不需要全屏 Blur filter，单帧仅 8 次 drawCircle；
///  - 光斑随时间缓慢漂移（周期 [GlassDuration.ambient]），让上层
///    玻璃卡片的折射内容产生「色彩流动感」；
///  - 相位由 ~30Hz 的 [Timer] 推进（见 State 注释）：只在内容真的
///    变化时才调度帧，避免 vsync 级合成把上层 BackdropFilter 拖进
///    逐帧重磨砂；
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

  /// 整队光斑在相位 [t]（弧度）下的 (中心坐标, 呼吸系数)。
  ///
  /// 仅供循环无缝性回归测试（`test/design_system/ambient_background_test.dart`）
  /// 使用：校验 t=2π（repeat 回绕末帧）与 t=0（下一循环首帧）状态一致，
  /// 防止再引入非整数倍频导致的光斑浓度跳变。
  @visibleForTesting
  static List<({Offset center, double breathe})> debugFleetState(
      double t, Size size) {
    return [
      for (final b in _kBlobs)
        (center: _blobCenter(b, t, size), breathe: _blobBreathe(b, t)),
    ];
  }

  @override
  State<AmbientGlassBackground> createState() => _AmbientGlassBackgroundState();
}

class _AmbientGlassBackgroundState extends State<AmbientGlassBackground> {
  /// 相位源（0~1 循环）。painter 的 repaint 监听它：值变才重绘。
  final ValueNotifier<double> _t = ValueNotifier(0);

  /// 单调时钟：跨「关→开」保持相位连续，光斑不瞬移、不回零。
  final Stopwatch _clock = Stopwatch();

  Timer? _timer;

  /// 为什么用 [Timer] 而不是 AnimationController：控制器的 Ticker 锚定
  /// vsync，repeat() 期间引擎**每个 vsync 都合成并提交整帧**（60/120
  /// 帧/s），上层 BackdropFilter（牌池卡/手牌卡/玻璃钮/底栏）被迫逐帧
  /// 重新磨砂 —— 这是底图动画掉帧的主因。Timer 以 ~30Hz 推进相位、
  /// 仅在内容确实变化时才调度帧，把整条渲染链降到 30fps：光斑漂移
  /// 仅 ~20px/s，30fps 步进不足 1px 视觉无感，GPU 负载直接减半
  /// （120Hz 屏减 3/4）。
  static const Duration _frameInterval = Duration(milliseconds: 33);

  void _start() {
    _clock.start();
    _timer?.cancel();
    _timer = Timer.periodic(_frameInterval, _onTick);
  }

  void _onTick(Timer _) {
    final cycleUs = GlassDuration.ambient.inMicroseconds;
    _t.value = (_clock.elapsedMicroseconds % cycleUs) / cycleUs;
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop(); // _t 保留当前值：painter 定格在当前姿态
  }

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  @override
  void didUpdateWidget(AmbientGlassBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate == old.animate) return;
    widget.animate ? _start() : _stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        // painter（而非 foregroundPainter）：光斑画在页面内容之下，
        // 上层玻璃卡片才能"折射"出底图的色彩
        painter: _AmbientPainter(t: _t),
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

  /// 浓度呼吸频率（相对漂移周期的倍频）。**只允许整数**：repeat() 每
  /// 周期把相位 t 从 2π 跳回 0，sin(t·k+φ) 仅在 k 为整数时无跳变 ——
  /// 填小数会让光斑浓度每 7s 瞬跳一次（回归见 ambient_background_test）。
  final double pulseSpeed;
}

/// 八色光斑编队（高明度淡彩）：
///   薄荷(左上主光) / 冰蓝(右上) / 薰衣草(左下) / 樱花粉(右下)
///   + 暖杏(下中偏右) / 柔黄(左中) / 湖青(下中) / 白高光(顶中)
/// driftFactor 0.08~0.16 + 相位错开的整数倍频呼吸 —— 位置与浓淡双重
/// 流动，1~2 秒即可感知色彩变化，且循环回绕处严格无缝（不跳变）。

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
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(0.95, -0.2),
    radiusFactor: 0.50,
    color: GlassColors.iceBlue,
    alpha: 0.36,
    driftFactor: 0.14,
    phaseX: 2.1,
    phaseY: 0.6,
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(0.8, 0.45),
    radiusFactor: 0.42,
    color: _kSakura,
    alpha: 0.30,
    driftFactor: 0.13,
    phaseX: 3.7,
    phaseY: 4.4,
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(-0.7, 0.9),
    radiusFactor: 0.54,
    color: GlassColors.lavender,
    alpha: 0.34,
    driftFactor: 0.15,
    phaseX: 4.2,
    phaseY: 3.1,
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(0.6, 1.0),
    radiusFactor: 0.36,
    color: _kApricot,
    alpha: 0.24,
    driftFactor: 0.12,
    phaseX: 1.0,
    phaseY: 5.0,
    pulseSpeed: 1.0,
  ),
  _Blob(
    alignment: Alignment(-1.0, 0.15),
    radiusFactor: 0.40,
    color: _kSoftYellow,
    alpha: 0.26,
    driftFactor: 0.13,
    phaseX: 5.3,
    phaseY: 1.9,
    // 原 1.3 倍频升为整 2 倍：保一支快呼吸调节奏（非整数会跳变）
    pulseSpeed: 2.0,
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
    pulseSpeed: 1.0,
  ),
];

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t}) : super(repaint: t);

  /// 相位源（0~1 循环）。由 State 的 ~30Hz Timer 推进：值变即重绘。
  final ValueNotifier<double> t;

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

    final t = this.t.value * 2 * math.pi;
    for (final b in _kBlobs) {
      final center = _blobCenter(b, t, size);
      final radius = b.radiusFactor * size.longestSide;
      // 浓度呼吸：与漂移不同相，光斑颜色忽浓忽淡 —— 位置与
      // 色彩双重流动，整体色彩变换更丰富；暗色下整体浓度收敛
      final breathe = _blobBreathe(b, t);
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
      oldDelegate.t != t || oldDelegate._paintedDark != GlassColors.isDark;
}

/// 光斑中心在相位 [t]（弧度）处的像素坐标。
///
/// 双频正弦漂移：位置随时间画"8"字轨迹，缓慢且不完全可预测；
/// 频率为 1（基频）保证 t=2π 回绕时位置连续无缝。
Offset _blobCenter(_Blob b, double t, Size size) {
  // Alignment(-1..1) → 像素中心点
  final base = Offset(
    size.width * (b.alignment.x + 1) / 2,
    size.height * (b.alignment.y + 1) / 2,
  );
  final drift = Offset(
    math.sin(t + b.phaseX),
    math.cos(t + b.phaseY),
  ) * (b.driftFactor * size.longestSide);
  return base + drift;
}

/// 浓度呼吸系数（0.56~1.0）。
///
/// [_Blob.pulseSpeed] 必须取**整数**倍频：repeat() 每 7s 把 t 从 2π
/// 跳回 0，sin(t·k+φ) 仅在 k∈ℤ 时周期为 2π —— 非整数 k 会让光斑
/// 浓度在循环回绕处瞬间跳变（回归见 ambient_background_test）。
double _blobBreathe(_Blob b, double t) =>
    0.78 + 0.22 * math.sin(t * b.pulseSpeed + b.phaseX * 1.7);
