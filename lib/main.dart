import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/tile.dart';
import 'design_system/design_system.dart';
import 'features/shell/dashboard_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 浅色玻璃体系：状态栏透明 + 深色图标（Android/iOS 各自的字段）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS（亮背景 → 深色文字）
  ));
  final prefill = await _prefill();
  runApp(KaWuXingApp(prefill: prefill));
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

class KaWuXingApp extends StatelessWidget {
  final Uint8List? prefill;
  const KaWuXingApp({super.key, this.prefill});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '卡五星听牌器',
      debugShowCheckedModeBanner: false,
      theme: AppGlassTheme.themeData(),
      scrollBehavior: const GlassScrollBehavior(), // 全局 iOS 式回弹
      home: DashboardShell(prefill: prefill),
    );
  }
}
