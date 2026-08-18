import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/design_system/ambient_glass_background.dart';

/// 环境底图（AmbientGlassBackground）回归：循环回绕无缝性。
///
/// 底图动画由 AnimationController.repeat() 驱动，每个周期结束 value
/// 从 1.0 跳回 0.0（相位 t：2π → 0）。光斑的漂移/呼吸全部由 sin/cos
/// 构成，只有当所有频率都是**整数倍频**时状态才是 2π 周期的 —— 否则
/// 每 7 秒光斑浓度会瞬间跳变一次（用户可见的「跳变」）。
void main() {
  test('光斑整队状态在循环回绕处无缝（t=2π ≡ t=0）', () {
    const size = Size(412, 915);
    final atWrapStart = AmbientGlassBackground.debugFleetState(0, size);
    final atWrapEnd =
        AmbientGlassBackground.debugFleetState(2 * math.pi, size);

    expect(atWrapEnd.length, atWrapStart.length,
        reason: '光斑数量不应随相位变化');

    for (var i = 0; i < atWrapStart.length; i++) {
      final a = atWrapStart[i];
      final b = atWrapEnd[i];
      expect(
        (b.center - a.center).distance,
        lessThan(1e-6),
        reason: '光斑 #$i 位置在循环回绕处跳变（漂移频率必须为 1）',
      );
      expect(
        (b.breathe - a.breathe).abs(),
        lessThan(1e-9),
        reason: '光斑 #$i 呼吸浓度在循环回绕处跳变'
            '（pulseSpeed 必须取整数倍频）',
      );
    }
  });
}
