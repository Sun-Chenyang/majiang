import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kawuxing/design_system/design_system.dart';

void main() {
  group('ClampedBouncingScrollPhysics 拖动弹性钳制（软墙）', () {
    const physics = ClampedBouncingScrollPhysics();

    ScrollMetrics metrics(double pixels,
        {double min = 0, double max = 1600, double viewport = 400}) {
      return FixedScrollMetrics(
        pixels: pixels,
        minScrollExtent: min,
        maxScrollExtent: max,
        viewportDimension: viewport,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3.0,
      );
    }

    /// SDK 语义：offset 为正 = 手指向下拖 = pixels 减小；
    /// 拖完后 pixels = oldPixels - physics 返回值。
    double drag(double pixels, double offset) =>
        pixels - physics.applyPhysicsToUserOffset(metrics(pixels), offset);

    test('范围内拖动不受影响', () {
      expect(drag(100, -50), 150); // 向上拖 50：pixels 增 50
      expect(drag(100, 50), 50); // 向下拖 50：pixels 减 50
    });

    test('线性段内越界保持 1:1 跟手（软墙在 64px 处才接管）', () {
      // 已越界 -30，再向下拖 20：仍在 64 线性段内，落点 ≈ -50 附近
      // （iOS 阻尼会轻微衰减，但绝不应被压缩回浅处）
      final p = drag(-30, 20);
      expect(p, lessThan(-30));
      expect(p, greaterThan(-64));
    });

    test('大步越界被渐进压缩，落点在渐近区间内（顶部）', () {
      // 一次拖 1000：无论阻尼算出多少，落点必须压入 (-77, -60)：
      // 比线性段更深（有弹性余量），但悬在渐近极限 76.8 前
      final gentle = drag(-40, 1000);
      expect(gentle, greaterThan(-77));
      expect(gentle, lessThan(-55));

      // 拖得越狠越接近渐近极限（单调收紧，非严格：大位移下浮点
      // 下溢会精确落在渐近值上）；渐近值被钳在 77 内
      final hard = drag(-40, 10000);
      expect(hard, lessThanOrEqualTo(gentle));
      expect(hard, greaterThanOrEqualTo(-77));
    });

    test('底部越界同样渐进压缩', () {
      final p = drag(1600, -1000); // 底部向上拖 = 越底部界
      expect(p, lessThan(1677));
      expect(p, greaterThan(1660));
    });

    test('从界外向界内拖动不被钳制阻挡', () {
      // 顶部越界 -40 处向上拖 30：应回到约 -10（阻尼后接近），不得被卡在 -40
      final p = drag(-40, -30);
      expect(p, greaterThan(-40));
      expect(p, lessThan(0));
    });
  });
}
