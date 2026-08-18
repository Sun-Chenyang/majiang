import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/tile.dart';
import 'design_system/design_system.dart';
import 'features/settings/appearance.dart';
import 'features/shell/dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 浅色玻璃体系：状态栏透明 + 深色图标（Android/iOS 各自的字段）。
  // 运行期明暗切换由 DashboardShell 的 AnnotatedRegion 接管。
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS（亮背景 → 深色文字）
  ));
  final mode = await AppearancePrefs.load();
  final prefill = await _prefill();
  runApp(KaWuXingApp(prefill: prefill, initialMode: mode));
}

/// 调试用：预填手牌（仅 debug 生效）。
/// - Android：`adb shell am start ... --es prefill "0,1,2,…"`（intent extra，经 MethodChannel 读取）
/// - Web：URL fragment `#h=0,1,2,…`
/// 格式：逗号分隔的牌种编码（可重复）。
Future<Uint8List?> _prefill() async {
  if (!kDebugMode) return null;
  if (kIsWeb) return _parsePrefill(Uri.base.fragment.startsWith('h=') ? Uri.base.fragment.substring(2) : null);
  try {
    final s = await const MethodChannel('kawuxing/debug').invokeMethod<String>('getPrefill');
    return _parsePrefill((s ?? '').isEmpty ? null : s);
  } catch (_) {
    return null;
  }
}

Uint8List? _parsePrefill(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final counts = Uint8List(kTileKindCount);
  for (final part in raw.split(',')) {
    final t = int.tryParse(part.trim());
    if (t == null || t < 0 || t >= kTileKindCount) continue;
    if (counts[t] < 4) counts[t]++;
  }
  return counts;
}

class KaWuXingApp extends StatefulWidget {
  final Uint8List? prefill;

  /// 启动时从持久化读取的外观模式。
  final ThemeMode initialMode;

  const KaWuXingApp({super.key, this.prefill, this.initialMode = ThemeMode.system});

  @override
  State<KaWuXingApp> createState() => _KaWuXingAppState();
}

class _KaWuXingAppState extends State<KaWuXingApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  void _changeMode(ThemeMode mode) {
    setState(() => _mode = mode);
    AppearancePrefs.save(mode);
  }

  @override
  Widget build(BuildContext context) {
    // 解析有效明暗 → 同步调色板门面（幂等）+ 驱动 MaterialApp 双主题。
    // 单 Shell 应用整树随 setState 全量重建，门面取值与 widget 树一致。
    final dark = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    GlassColors.current = dark ? GlassPalette.dark : GlassPalette.light;

    return MaterialApp(
      title: '卡五星听牌器',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: AppGlassTheme.themeData(),
      darkTheme: AppGlassTheme.themeData(brightness: Brightness.dark),
      // 调色板门面是即时切换：关掉 Material 主题过渡动画避免两层不同步
      themeAnimationDuration: Duration.zero,
      scrollBehavior: const GlassScrollBehavior(), // 全局 iOS 式回弹
      home: DashboardShell(
        prefill: widget.prefill,
        appearanceMode: _mode,
        onAppearanceModeChanged: _changeMode,
      ),
    );
  }
}
