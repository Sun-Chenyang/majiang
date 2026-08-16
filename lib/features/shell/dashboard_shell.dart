import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../design_system/design_system.dart';
import '../calculator/calculator_page.dart';
import '../rules/rules_page.dart';
import '../settings/settings_page.dart';

/// 应用外壳（Dashboard Shell）：
/// 弥散渐变环境底图 + 三页 IndexedStack + 悬浮玻璃底部导航。
///
/// 页面切换用 IndexedStack 保活（听牌器输入状态在切 Tab 后不丢失），
/// 底栏以 Stack 方式悬浮其上，滚动内容通过各自的底部留白(118)避让。
class DashboardShell extends StatefulWidget {
  final Uint8List? prefill;

  const DashboardShell({super.key, this.prefill});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _tab = 0;

  /// 设置项状态（设置页修改 → 全局即时生效）
  bool _ambientAnimated = true;
  bool _hapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    AppFeedback.hapticsEnabled = _hapticsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ① 环境底图 + 页面层
          AmbientGlassBackground(
            animate: _ambientAnimated,
            child: IndexedStack(
              index: _tab,
              children: [
                CalculatorPage(initialCounts: widget.prefill),
                const RulesPage(),
                SettingsPage(
                  ambientAnimated: _ambientAnimated,
                  onAmbientAnimatedChanged: (v) =>
                      setState(() => _ambientAnimated = v),
                  hapticsEnabled: _hapticsEnabled,
                  onHapticsEnabledChanged: (v) => setState(() {
                    _hapticsEnabled = v;
                    AppFeedback.hapticsEnabled = v;
                  }),
                ),
              ],
            ),
          ),

          // ② 悬浮玻璃底栏（避开手势条）
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: GlassBottomBar(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              items: const [
                GlassBottomBarItem(
                  icon: Icons.casino_outlined,
                  activeIcon: Icons.casino_rounded,
                  label: '听牌器',
                ),
                GlassBottomBarItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  label: '规则',
                  activeColor: GlassColors.iceBlue,
                ),
                GlassBottomBarItem(
                  icon: Icons.tune,
                  activeIcon: Icons.tune_rounded,
                  label: '设置',
                  activeColor: GlassColors.lavender,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
