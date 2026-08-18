import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外观模式持久化（开发计划 M10.2：仅此一项落盘，无其他配置）。
///
/// 三态：白天 / 黑暗 / 跟随系统（默认）。读写失败（如测试环境无插件
/// 通道）静默回退系统默认，不阻塞启动。
class AppearancePrefs {
  static const String _key = 'appearance_mode';

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // 持久化失败不影响当前会话
    }
  }
}
