import 'package:flutter/services.dart';

/// 全局触感反馈开关（设置页可关）。
///
/// 统一入口的意义：让"触感"成为可系统关闭的行为，
/// 而不是散落在各 Widget 里的 HapticFeedback 裸调用。
abstract final class AppFeedback {
  static bool hapticsEnabled = true;

  /// 轻点反馈（选牌、切 Tab）。
  static void tap() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }
}
