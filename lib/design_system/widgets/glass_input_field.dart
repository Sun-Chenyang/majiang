import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_glass_theme.dart';

/// 玻璃拟物输入框（Glass Input Field）· 重制版。
///
/// 四层结构（自外而内，职责单一、互不重叠）：
///   1. 光晕壳：唯一的描边层 + 聚焦外发光。描边画在裁剪层之外，
///      圆角处完整（不会被 ClipRRect 裁掉外半圈）；
///   2. 磨砂层：BackdropFilter σ=9，只负责模糊；
///   3. 玻璃底：白玻璃对角渐变（左上受光）；
///   4. 凹槽内阴影：沿边缘的描边式渐变（见 [_EdgeInnerShadowPainter]），
///      顶部背光、底部受光，圆角弧段自然连续，左右不会断开。
class GlassInputField extends StatefulWidget {
  const GlassInputField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.accent,
    this.clearable = true,
    this.enabled = true,
  });

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final String? hint;

  /// 前缀图标（搜索放大镜 / 邮箱等）。
  final IconData? prefixIcon;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;

  /// 聚焦主题色（光晕、描边与光标）；缺省薄荷。
  final Color? accent;

  /// 文字非空时显示一键清除按钮。
  final bool clearable;

  final bool enabled;

  @override
  State<GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<GlassInputField> {
  /// 外部未提供时内部自建，dispose 时随宿主销毁。
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  FocusNode? _ownFocusNode;
  FocusNode get _focus => widget.focusNode ?? _ownFocusNode!;

  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) _ownFocusNode = FocusNode();
    _focus.addListener(_handleFocus);
    _controller.addListener(_handleText);
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocus);
    _controller.removeListener(_handleText);
    _ownFocusNode?.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() => _focused = _focus.hasFocus);

  void _handleText() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? GlassColors.mint;
    final borderWidth = 1.3;
    final outer = Radius.circular(GlassRadius.sm);
    final inner = Radius.circular(GlassRadius.sm - borderWidth / 2);

    return AnimatedContainer(
      duration: GlassDuration.focus,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(outer),
        // 聚焦外光晕：主题色 α 0.25 / blur 12 —— 弱发光提示而非描边加粗
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      // ① 光晕壳：唯一描边层（静止白高光，聚焦染主题色）
      child: AnimatedContainer(
        duration: GlassDuration.focus,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(outer),
          border: Border.all(
            color: _focused
                ? accent.withValues(alpha: 0.55)
                : GlassColors.rim(0.65),
            width: borderWidth,
          ),
        ),
        // ②③ 磨砂 + 玻璃底（裁剪收缩到描边内缘）
        child: ClipRRect(
          borderRadius: BorderRadius.all(inner),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: GlassLight.begin,
                  end: GlassLight.end,
                  colors: [
                    GlassColors.surface(0.45),
                    GlassColors.surface(0.20),
                  ],
                ),
              ),
              // ④ 沿边内阴影
              child: CustomPaint(
                foregroundPainter: _EdgeInnerShadowPainter(
                  borderWidth: borderWidth,
                  radius: GlassRadius.sm,
                  // 顶带背光色随主题：浅色冷墨；暗色用投影墨（纯黑）加深
                  // 浓度——深板岩底上淡黑不可见，提到 0.5 才有凹槽感
                  shadowColor: _focused
                      ? accent.darken(0.15).withValues(alpha: 0.30)
                      : GlassColors.shadowInk.withValues(
                          alpha: GlassColors.isDark ? 0.5 : 0.15,
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        Icon(
                          widget.prefixIcon,
                          size: 20,
                          // 未聚焦态与提示文字同级：玻璃面在浅色光斑上
                          // 会被穿透提亮，tertiary 看不清，用 secondary
                          color: _focused
                              ? GlassColors.accentOnGlass(accent).darken(0.2)
                              : GlassColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          enabled: widget.enabled,
                          keyboardType: widget.keyboardType,
                          textInputAction: TextInputAction.search,
                          onChanged: widget.onChanged,
                          onSubmitted: widget.onSubmitted,
                          cursorColor: accent,
                          cursorWidth: 1.8,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: GlassColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            hintText: widget.hint,
                            hintStyle: TextStyle(
                              fontSize: 14.5,
                              // 提示文字在磨砂玻璃上仍会被浅色光斑穿透，
                              // tertiary 对比不足，用 secondary
                              color: GlassColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (widget.clearable && _hasText) ...[
                        const SizedBox(width: 8),
                        _clearButton(),
                      ],
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

  Widget _clearButton() {
    // 视觉 22×22，外包 40×40 热区（移动端易点，视觉不变）
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _controller.clear();
        widget.onChanged?.call('');
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: GlassLight.begin,
                end: GlassLight.end,
                colors: [
                  GlassColors.textTertiary.withValues(alpha: 0.35),
                  GlassColors.textTertiary.withValues(alpha: 0.18),
                ],
              ),
            ),
            child: const Icon(Icons.close, size: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// 沿边缘的凹槽内阴影（描边式，非矩形带）。
///
/// 用两条「圆角矩形描边 + 方向性渐变」绘制：
///  - 顶部背光：stroke 外沿贴外描边内缘，向内延伸 9px，垂直渐变
///    从暗到透明 —— 颜色跟随描边路径分布：顶部水平边最深，
///    左右上角弧段按其 y 位置自然取色，左右垂直边已渐变到透明
///    （不该有阴影的位置恰好没有），全程贴边、圆角连续、左右无断口；
///  - 底部受光：同理反向，7px 内从透明到白。
class _EdgeInnerShadowPainter extends CustomPainter {
  _EdgeInnerShadowPainter({
    required this.borderWidth,
    required this.radius,
    required this.shadowColor,
  });

  /// 外层描边宽度：内阴影的起点（描边内缘）。
  final double borderWidth;

  final double radius;

  final Color shadowColor;

  /// 上次绘制时的明暗态：主题切换后与之不同则强制重绘
  /// （底部受光带走 rim() 门面，颜色不经过参数，需此兜底）。
  bool? _paintedDark;

  static const double _topBand = 9; // 顶部背光带宽度
  static const double _bottomBand = 7; // 底部受光带宽度

  @override
  void paint(Canvas canvas, Size size) {
    _paintedDark = GlassColors.isDark;
    final rect = Offset.zero & size;

    // 顶部背光描边：外沿贴外描边内缘，向内延伸 _topBand
    final topCenter = borderWidth / 2 + _topBand / 2;
    final topRect = rect.deflate(topCenter);
    if (topRect.isEmpty) return;
    final topRRect = RRect.fromRectAndRadius(
      topRect,
      Radius.circular((radius - topCenter).clamp(0, radius)),
    );
    final topMid = topRect.top; // stroke 中心线的 y
    canvas.drawRRect(
      topRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _topBand
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(0, topMid - _topBand / 2),
          Offset(0, topMid + _topBand / 2),
          [shadowColor, shadowColor.withValues(alpha: 0)],
        ),
    );

    // 底部受光描边（白走 rim() 门面：暗色按 rimAlphaScale 收敛）
    final bottomCenter = borderWidth / 2 + _bottomBand / 2;
    final bottomRect = rect.deflate(bottomCenter);
    final bottomRRect = RRect.fromRectAndRadius(
      bottomRect,
      Radius.circular((radius - bottomCenter).clamp(0, radius)),
    );
    final bottomMid = bottomRect.bottom;
    canvas.drawRRect(
      bottomRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _bottomBand
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset(0, bottomMid - _bottomBand / 2),
          Offset(0, bottomMid + _bottomBand / 2),
          [GlassColors.rim(0), GlassColors.rim(0.5)],
        ),
    );
  }

  @override
  bool shouldRepaint(_EdgeInnerShadowPainter oldDelegate) =>
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.radius != radius ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate._paintedDark != GlassColors.isDark;
}
