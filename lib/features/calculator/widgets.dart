import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/tile.dart';
import '../../design_system/design_system.dart';

/// 牌面卡片 v4：切图为「透明底纯图案」（尺寸=图案尺寸，宽高比各异，
/// 0.13 竖长条 ~ 1.03 方形），牌面全部质感由容器按设计系统绘制：
///
///   底层   象牙白对角渐变（左上纯白受光 → 右下米白背光）+ 圆角 + 双层柔影
///   图案区 inset 11% 内容框内 [BoxFit.contain] —— 各宽高比图案
///          以内容框为界等比缩放，视觉大小统一
///   光照层 画在图案之上（[_TileLightPainter]）：顶部玻璃反光带
///          + RimLight 高光棱线
///
/// 透明底切图让牌面底色完全可控（换肤/庆祝色牌面只需改渐变）。
class TileCard extends StatelessWidget {
  final int tile;

  /// 卡片宽度；null 时填满父约束宽度（高度按 87:114 牌面比例撑开）。
  final double? width;

  /// 阴影强度 0~1；列表里的小牌用小值避免视觉噪声。
  final double elevation;

  const TileCard({
    super.key,
    required this.tile,
    this.width,
    this.elevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    final w = width;
    if (w != null) return _card(w);
    return LayoutBuilder(builder: (context, c) => _card(c.maxWidth));
  }

  Widget _card(double width) {
    // 显式定高：布局不依赖图片解码时序，点击热区稳定
    final height = width * 114 / 87;
    final radius = width * 0.12;
    // 图案内容框：四周留 11%（麻将牌图案离边的呼吸空间）
    final pad = width * 0.11;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // 象牙白受光渐变：左上 #FFFFFF → 右下 #F1EAE0（全局光源方向）
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1EAE0)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevation <= 0
            ? null
            : [
                // 近影：投影墨色右下向（x/y 正偏移遵循全局光源；暗色墨色更深）
                BoxShadow(
                  color: GlassColors.shadowInk.withValues(alpha: 0.18 * elevation),
                  blurRadius: width * 0.10,
                  offset: Offset(width * 0.03, width * 0.06),
                ),
                // 远影：极淡冰蓝环境漫反射，悬浮感
                BoxShadow(
                  color: GlassColors.iceBlue.withValues(alpha: 0.10 * elevation),
                  blurRadius: width * 0.22,
                  offset: Offset(width * 0.06, width * 0.14),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          foregroundPainter: _TileLightPainter(radius: radius),
          child: Padding(
            padding: EdgeInsets.all(pad),
            // 各图案宽高比不同（0.13~1.03）：contain 以内容框为界
            // 等比缩放，竖长条（2条）撑高、方形（发/1筒）撑宽；
            // 个别牌种（如"发"）contain 后视觉偏小，按表放大微调
            child: _pattern(width: width - pad * 2, height: height - pad * 2),
          ),
        ),
      ),
    );
  }

  /// 图案 + 按牌种缩放。OverflowBox 允许放大后的图案越出内容框，
  /// 由外层牌面圆角与 11% 呼吸边距兜底，不会贴边或被裁。
  Widget _pattern({required double width, required double height}) {
    final image = Image.asset(
      tileAsset(tile),
      fit: BoxFit.contain,
      width: width,
      height: height,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _fallbackFace(width),
    );
    final scale = tilePatternScale(tile);
    if (scale == 1.0) return image;
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: Transform.scale(scale: scale, child: image),
    );
  }

  /// 缺图回退：象牙白牌面 + 汉字
  Widget _fallbackFace(double width) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        tileName(tile),
        style: TextStyle(
          fontSize: width * 0.24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF334049),
        ),
      ),
    );
  }
}

/// 牌面光照层（画在图案之上）：顶部玻璃反光带 + RimLight 棱线。
/// 光照统一从左上射入，与全系统 [GlassLight] 方向一致。
class _TileLightPainter extends CustomPainter {
  _TileLightPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // ① 顶部玻璃反光带：顶部 32% 高度白色渐隐（光掠过牌面上表面）
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * 0.32),
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height * 0.32),
          [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
    );
    canvas.restore();

    // ② RimLight 棱线：左上白 0.9 → 右下白 0.15（凸起受光边）
    final stroke = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(stroke / 2),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.15),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(_TileLightPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// 牌池格子：牌面卡片 + 已选数角标（右上），点击 +1；
/// 长按弹已见牌标记（他家弃牌/碰/杠，M8.4），已见时左下角显示"见n"角标。
class PoolTileCell extends StatelessWidget {
  final int tile;
  final int count;
  final VoidCallback? onTap;

  /// 长按：已见牌标记入口。
  final VoidCallback? onLongPress;

  /// 他家已见张数（长按标记累计），>0 时左下角显示角标。
  final int externalSeen;

  const PoolTileCell({
    super.key,
    required this.tile,
    required this.count,
    this.onTap,
    this.onLongPress,
    this.externalSeen = 0,
  });

  @override
  Widget build(BuildContext context) {
    final full = count >= 4;
    return InkWell(
      onTap: full ? null : onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: full ? 0.35 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TileCard(tile: tile),
            if (count > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    // 薄荷→冰蓝的对角渐变角标：受光方向与全局一致
                    gradient: LinearGradient(
                      begin: GlassLight.begin,
                      end: GlassLight.end,
                      colors: [GlassColors.mint, GlassColors.iceBlue],
                    ),
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                    border: Border.all(
                      color: GlassColors.rim(0.9),
                      width: 1,
                    ),
                    boxShadow: GlassShadow.chip(GlassColors.mint),
                  ),
                  child: Text(
                    '×$count',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: GlassColors.textOnAccent,
                    ),
                  ),
                ),
              ),
            if (externalSeen > 0)
              Positioned(
                left: -2,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    // 已见角标：冷墨深底白字（明暗两主题下都可读）
                    color: GlassColors.shadowInk.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                    boxShadow: GlassShadow.chip(GlassColors.shadowInk),
                  ),
                  child: Text(
                    '见$externalSeen',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: GlassColors.textOnAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 结果行里的小牌图。
class MiniTile extends StatelessWidget {
  final int tile;
  final double width;
  const MiniTile({super.key, required this.tile, this.width = 26});

  @override
  Widget build(BuildContext context) {
    return TileCard(tile: tile, width: width, elevation: 0.55);
  }
}

/// 番型小标签：白玻璃 chip + 薄荷描边（浅底上用深化色保证可读）。
class FanChip extends StatelessWidget {
  final String label;
  const FanChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            GlassColors.surface(0.72),
            GlassColors.surface(0.38),
          ],
        ),
        borderRadius: BorderRadius.circular(GlassRadius.xs),
        border: Border.all(color: GlassColors.mint.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: GlassColors.mintDeep),
      ),
    );
  }
}
