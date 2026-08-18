import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_glass_theme.dart';

/// 微拟物触感按钮（Skeuo Button）。
///
/// 物理模型（光源：左上 → 右下）：
///   ┌─ 静止（凸起）─────────┐   ┌─ 按压（下陷）─────────┐
///   │ 表面渐变：亮 → 暗      │   │ 表面渐变：暗 → 亮(反向) │
///   │ 高光条：顶部白弧       │   │ 高光条：底部反白        │
///   │ 影子：双层柔影(右下)   │   │ 影子：收缩贴地          │
///   │ 缩放：1.0             │   │ 缩放：0.965            │
///   └───────────────────────┘   └───────────────────────┘
///
/// [glass] = true 时切换为「玻璃次级按钮」：磨砂白底 + 彩色文字，
/// 用于与主按钮形成层级对比（主 CTA / 次操作）。
class SkeuoButton extends StatefulWidget {
  const SkeuoButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.accent,
    this.glass = false,
    this.minHeight = 48,
    this.haptics = true,
  });

  /// 按钮文字；与 [icon] 至少提供一个。仅 icon 时渲染为方形小按钮。
  final String? label;

  final IconData? icon;
  final VoidCallback? onPressed;

  /// 主题色（默认薄荷）。按钮整体色相由此派生：亮面 = lighten，暗面 = darken。
  final Color? accent;

  final bool glass;
  final double minHeight;

  /// 按下时是否触发光感震动（selectionClick，轻量不打扰）。
  final bool haptics;

  @override
  State<SkeuoButton> createState() => _SkeuoButtonState();
}

class _SkeuoButtonState extends State<SkeuoButton> {
  bool _pressed = false;

  bool get _iconOnly => widget.label == null;

  Color get _accent => widget.accent ?? GlassColors.mint;

  void _setPressed(bool v) {
    if (_pressed == v || !mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_iconOnly ? 12 : GlassRadius.pill);
    final disabled = widget.onPressed == null;

    Widget face = widget.glass ? _glassFace(radius) : _solidFace(radius);

    // 按压缩放：0.965 而非 0.9 —— 物理下陷是"轻按入平面"，不是"缩小"
    Widget button = AnimatedScale(
      scale: _pressed ? 0.965 : 1.0,
      duration: GlassDuration.press,
      curve: Curves.easeOut,
      child: face,
    );

    if (disabled) {
      return Opacity(opacity: 0.45, child: button);
    }
    return Semantics(
      button: true,
      enabled: !disabled,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          if (widget.haptics) HapticFeedback.selectionClick();
          widget.onPressed?.call();
        },
        child: button,
      ),
    );
  }

  // —— 实心拟物按钮：彩色渐变凸起体 ——

  Widget _solidFace(BorderRadius radius) {
    final accent = _accent;
    return ClipRRect(
      borderRadius: radius,
      child: AnimatedContainer(
        duration: GlassDuration.press,
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: widget.minHeight),
        padding: _iconOnly
            ? const EdgeInsets.all(13)
            : EdgeInsets.symmetric(
                horizontal: widget.icon != null ? 18 : 22, vertical: 12),
        decoration: BoxDecoration(
          // 受光渐变：静止时「亮→暗」(凸)；按压时反向为「暗→亮」(凹壁受光)
          gradient: LinearGradient(
            begin: GlassLight.begin,
            end: GlassLight.end,
            colors: _pressed
                ? [
                    accent.darken(0.12),
                    accent,
                    accent.lighten(0.16),
                  ]
                : [
                    accent.lighten(0.24),
                    accent,
                    accent.darken(0.15),
                  ],
          ),
          boxShadow: _pressed
              ? GlassShadow.pressed(accent) // 影子收缩：物体被压向平面
              : [
                  // 近影染色 + 远影中性：与 GlassShadow.soft 同构，浓度略高保证按压对比
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(5, 12),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 折射高光层：静止时顶部白弧（球面顶受光）；
            // 按压时翻到底部（凹陷的内壁下缘把光反射回来）
            Positioned.fill(
              child: AnimatedContainer(
                duration: GlassDuration.press,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _pressed ? Alignment.bottomCenter : Alignment.topCenter,
                    end: _pressed ? Alignment.bottomCenter : Alignment(0, 0.85),
                    colors: _pressed
                        ? [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0),
                          ],
                  ),
                ),
              ),
            ),
            _content(GlassColors.textOnAccent, GlassColors.textOnAccent),
          ],
        ),
      ),
    );
  }

  // —— 玻璃次级按钮：磨砂白 + 彩字 ——

  Widget _glassFace(BorderRadius radius) {
    final accent = _accent;
    final ink = widget.accent == null
        ? GlassColors.textPrimary
        // 玻璃底上文字需保证对比：浅色加深、暗色提亮
        : (GlassColors.isDark ? _accent.lighten(0.22) : _accent.darken(0.28));
    final borderWidth = 1.1;

    // 层级（外→内）：描边壳 → ClipRRect(描边内缘) → BackdropFilter → 渐变体。
    // 描边必须画在裁剪之外：Border 以边界为中心线，放进 ClipRRect 会被
    // 裁掉外侧一半，圆角处出现残缺。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: GlassColors.rim(_pressed ? 0.5 : 0.75),
          width: borderWidth,
        ),
        boxShadow: _pressed
            ? GlassShadow.pressed(GlassColors.shadowInk)
            : GlassShadow.chip(accent),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.elliptical(
            radius.topLeft.x - borderWidth / 2,
            radius.topLeft.y - borderWidth / 2,
          ),
          topRight: Radius.elliptical(
            radius.topRight.x - borderWidth / 2,
            radius.topRight.y - borderWidth / 2,
          ),
          bottomLeft: Radius.elliptical(
            radius.bottomLeft.x - borderWidth / 2,
            radius.bottomLeft.y - borderWidth / 2,
          ),
          bottomRight: Radius.elliptical(
            radius.bottomRight.x - borderWidth / 2,
            radius.bottomRight.y - borderWidth / 2,
          ),
        ),
        child: BackdropFilter(
          // 次级按钮磨砂弱于卡片：σ=10，避免与底卡叠加成"浆糊"
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: GlassDuration.press,
            curve: Curves.easeOut,
            constraints: BoxConstraints(minHeight: widget.minHeight),
            padding: _iconOnly
                ? const EdgeInsets.all(11)
                : EdgeInsets.symmetric(
                    horizontal: widget.icon != null ? 18 : 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: GlassLight.begin,
                end: GlassLight.end,
                // 按压时整体压暗一档，模拟玻璃被手指遮光（暗色收敛为低透明白）
                colors: _pressed
                    ? [
                        GlassColors.surface(0.32),
                        GlassColors.surface(0.14),
                      ]
                    : [
                        GlassColors.surface(0.55),
                        GlassColors.surface(0.26),
                      ],
              ),
            ),
            child: _content(ink, ink),
          ),
        ),
      ),
    );
  }

  Widget _content(Color fg, Color accentFg) {
    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, size: _iconOnly ? 18 : 20, color: fg);
    if (widget.label == null) return icon!;
    final text = Text(
      widget.label!,
      style: TextStyle(
        fontSize: 15,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: fg,
        letterSpacing: 0.2,
      ),
    );
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 7),
        text,
      ],
    );
  }
}
