import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// 设置页：外观三态 + 体验开关 + 规则速览 + 关于信息。
///
/// 开关状态由 DashboardShell / 根部 App 持有（跨页面生效）：
///  - 外观（白天/黑暗/跟随系统）→ 根部 MaterialApp 双主题 + 调色板切换，
///    选择持久化（M10.2：仅此项落盘）；
///  - 动态底图 → 控制 AmbientGlassBackground 的光斑漂移；
///  - 触感反馈 → 写入 AppFeedback 全局开关。
/// 玩法规则已全部裁决固定，此处仅速览（详见"规则"Tab）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.ambientAnimated,
    required this.onAmbientAnimatedChanged,
    required this.hapticsEnabled,
    required this.onHapticsEnabledChanged,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
  });

  final bool ambientAnimated;
  final ValueChanged<bool> onAmbientAnimatedChanged;

  final bool hapticsEnabled;
  final ValueChanged<bool> onHapticsEnabledChanged;

  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode> onAppearanceModeChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 118),
        children: [
          Text('设置', style: GlassTypography.display),
          const SizedBox(height: 3),
          // 副标题裸露在流动光斑上，用高对比辅助字（captionStrong）
          Text('调整视觉偏好，立即生效', style: GlassTypography.captionStrong),
          const SizedBox(height: 16),
          _section('外观', [_appearanceSection()]),
          const SizedBox(height: 14),
          _section('体验', [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              title: Text('动态氛围底图', style: GlassTypography.titleSm),
              subtitle: Text('彩色光斑缓慢漂移；关闭可省电',
                  style: GlassTypography.caption),
              value: ambientAnimated,
              onChanged: onAmbientAnimatedChanged,
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              title: Text('触感反馈', style: GlassTypography.titleSm),
              subtitle: Text('选牌与切换时轻微震动', style: GlassTypography.caption),
              value: hapticsEnabled,
              onChanged: onHapticsEnabledChanged,
            ),
          ]),
          const SizedBox(height: 14),
          _section('规则速览', [
            _aboutRow('卡五星', '手中 4、6 卡张夹 5（筒/条同计）×2'),
            _aboutRow('屁胡', '只能自摸；点炮胡需有其他番型'),
          ]),
          const SizedBox(height: 14),
          _section('关于', [
            _aboutRow('应用', '卡五星听牌器 v1.2.0'),
            _aboutRow('定位', '单机离线工具 · 无账号 · 无网络依赖'),
            _aboutRow('数据', '规则内容整理自本地规则文档'),
          ]),
          const SizedBox(height: 14),
          GlassCard(
            frost: false,
            surfaceTint: GlassColors.lavender,
            tintStrength: 0.12,
            shadow: false,
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: GlassColors.lavenderDeep, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '设计体系：现代清新微拟物 + 玻璃拟态。',
                    style: GlassTypography.caption.copyWith(
                        color: GlassColors.lavenderDeep,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 外观（M10.2 三态） ----------------

  Widget _appearanceSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined,
                  size: 20, color: GlassColors.lavenderDeep),
              const SizedBox(width: 10),
              Text('主题', style: GlassTypography.titleSm),
              const Spacer(),
              Text(_modeLabel(appearanceMode), style: GlassTypography.caption),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (mode, label, icon) in [
                (ThemeMode.light, '白天', Icons.light_mode_outlined),
                (ThemeMode.dark, '黑暗', Icons.dark_mode_outlined),
                (ThemeMode.system, '跟随系统', Icons.brightness_auto_outlined),
              ]) ...[
                Expanded(child: _modeSegment(mode, label, icon)),
                if (mode != ThemeMode.system) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text('黑暗模式保持左上→右下光照方向；选择会记住（仅此项持久化）。',
              style: GlassTypography.caption),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => '白天模式',
        ThemeMode.dark => '黑暗模式',
        ThemeMode.system => '跟随系统',
      };

  /// 三态分段按钮：选中态薰衣草染色玻璃凸起（与情境 chip 同光照语言）。
  Widget _modeSegment(ThemeMode mode, String label, IconData icon) {
    final selected = appearanceMode == mode;
    final accent = GlassColors.lavender;
    return GestureDetector(
      onTap: () => onAppearanceModeChanged(mode),
      child: AnimatedContainer(
        duration: GlassDuration.press,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: GlassLight.begin,
            end: GlassLight.end,
            colors: selected
                ? [
                    GlassColors.tintForGlass(accent).withValues(alpha: 0.55),
                    GlassColors.tintForGlass(accent).withValues(alpha: 0.34),
                  ]
                : [
                    GlassColors.surface(0.34),
                    GlassColors.surface(0.18),
                  ],
          ),
          borderRadius: BorderRadius.circular(GlassRadius.sm),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.65)
                : GlassColors.rim(0.45),
            width: 1.1,
          ),
          boxShadow:
              selected ? GlassShadow.chip(accent) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? GlassColors.lavenderDeep
                    : GlassColors.textTertiary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? GlassColors.lavenderDeep
                      : GlassColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  // ---------------- 通用区块 ----------------

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: GlassLight.begin,
                    end: GlassLight.end,
                    colors: [
                      GlassColors.lavender.lighten(0.2),
                      GlassColors.lavender,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(GlassRadius.pill),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: GlassTypography.titleSm),
            ],
          ),
        ),
        GlassCard(
          frost: false,
          tintStrength: 0.5,
          shadow: false,
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: GlassTypography.caption),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: GlassTypography.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
