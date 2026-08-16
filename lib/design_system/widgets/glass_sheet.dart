import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_glass_theme.dart';
import 'skeuo_button.dart';

/// 磨砂玻璃抽屉弹窗（Glass Modal Bottom Sheet）。
///
/// 用法：
/// ```dart
/// showGlassModalBottomSheet(
///   context,
///   title: '番型详情',
///   builder: (_) => const Text('内容'),
/// );
/// ```
///
/// 特性：
///  - 悬浮式：四边留白 + 四角圆角 30，区别于贴边的老式 sheet；
///  - 高斯磨砂 σ=26（弹层是注意力焦点，比底栏更"厚"）；
///  - 默认支持拖拽把手下滑关闭（沿 showModalBottomSheet 手势）；
///  - 自动避开键盘（viewInsets）。
Future<T?> showGlassModalBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  Color accent = GlassColors.mint,
  Color? barrierColor,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // 遮罩：冷墨 α≈0.18，够压暗背景突出弹层，又不杀掉环境光斑的呼吸感
    barrierColor: barrierColor ?? GlassColors.scrim.withValues(alpha: 0.18),
    builder: (sheetContext) => _GlassSheet(
      title: title,
      accent: accent,
      showDragHandle: showDragHandle,
      child: Builder(builder: builder),
    ),
  );
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({
    required this.child,
    required this.accent,
    this.title,
    this.showDragHandle = true,
  });

  final Widget child;
  final Color accent;
  final String? title;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final radius = BorderRadius.circular(GlassRadius.xl);

    return Padding(
      // 键盘弹起时把整个抽屉顶上去
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        // 悬浮边距：左右 12 / 底 12，让磨砂边缘能"折"出环境光
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.82),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: GlassShadow.soft(accent),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              // σ=26：全场最厚的玻璃 —— 弹层需要与背景内容明显分离
              filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: GlassLight.begin,
                    end: GlassLight.end,
                    colors: [
                      // 白玻璃 α0.66 → α0.38：内容可读性与通透度的平衡点
                      Colors.white.withValues(alpha: 0.66),
                      Colors.white.withValues(alpha: 0.38),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDragHandle) _dragHandle(),
                      if (title != null) ...[
                        const SizedBox(height: 6),
                        _header(context),
                      ],
                      Flexible(child: child),
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

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 38,
        height: 4.5,
        decoration: BoxDecoration(
          // 把手：白色半透明胶囊，暗示"可拖拽"
          borderRadius: BorderRadius.circular(GlassRadius.pill),
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title!, style: GlassTypography.title),
        ),
        SkeuoButton(
          icon: Icons.close_rounded,
          glass: true,
          accent: accent,
          minHeight: 38,
          haptics: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
