import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///
/// 外观模式（白天/黑暗/跟随系统）由根部 KaWuXingApp 持有并下发；
/// 状态栏图标明暗随有效主题切换（M10.4）。
class DashboardShell extends StatefulWidget {
  final Uint8List? prefill;

  final ThemeMode appearanceMode;
  final ValueChanged<ThemeMode> onAppearanceModeChanged;

  const DashboardShell({
    super.key,
    this.prefill,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
  });

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 状态栏透明，图标明暗随主题：暗色底 → 白图标（M10.4）
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // ① 环境底图 + 页面层
            AmbientGlassBackground(
              animate: _ambientAnimated,
              child: IndexedStack(
                index: _tab,
                children: [
                  CalculatorPage(initialCounts: widget.prefill),
                  // 不能写成 const：静态门面（GlassColors）靠根部整树重建
                  // 换值，const 实例会被 Flutter 跳过重建 → 明暗切换后
                  // 规则页残留旧色，只有滚动时重建的列表项陆续换色
                  // （回归见 dark_palette_test）。
                  RulesPage(),
                  SettingsPage(
                    ambientAnimated: _ambientAnimated,
                    onAmbientAnimatedChanged: (v) =>
                        setState(() => _ambientAnimated = v),
                    hapticsEnabled: _hapticsEnabled,
                    onHapticsEnabledChanged: (v) => setState(() {
                      _hapticsEnabled = v;
                      AppFeedback.hapticsEnabled = v;
                    }),
                    appearanceMode: widget.appearanceMode,
                    onAppearanceModeChanged: widget.onAppearanceModeChanged,
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
                items: [
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
      ),
    );
  }
}
