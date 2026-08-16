import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// 设置页：体验开关 + 规则速览 + 关于信息。
///
/// 开关状态由 DashboardShell 持有（跨页面生效）：
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
  });

  final bool ambientAnimated;
  final ValueChanged<bool> onAmbientAnimatedChanged;

  final bool hapticsEnabled;
  final ValueChanged<bool> onHapticsEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 118),
        children: [
          const Text('设置', style: GlassTypography.display),
          const SizedBox(height: 3),
          Text('调整视觉偏好，立即生效', style: GlassTypography.caption),
          const SizedBox(height: 16),
          _section('体验', [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              title: const Text('动态氛围底图', style: GlassTypography.titleSm),
              subtitle: Text('彩色光斑缓慢漂移；关闭可省电',
                  style: GlassTypography.caption),
              value: ambientAnimated,
              onChanged: onAmbientAnimatedChanged,
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              title: const Text('触感反馈', style: GlassTypography.titleSm),
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
            _aboutRow('应用', '卡五星听牌器 v1.1.0'),
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
                const Icon(Icons.auto_awesome_rounded,
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
                  gradient: const LinearGradient(
                    begin: GlassLight.begin,
                    end: GlassLight.end,
                    colors: [
                      Color(0xFFB7A3FF),
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
