import 'package:flutter_test/flutter_test.dart';

import 'package:kawuxing/design_system/design_system.dart';

/// 回归：Flutter 3.44 的 Color.r/g/b 为 0~1 归一化分量。
/// 曾因按 0~255 语义混合导致 lighten/darken 输出近黑深灰
/// （规则页装饰条、番数徽标、底栏文字集体发黑）。
void main() {
  test('lighten 向白色混合且保留色相', () {
    const mint = GlassColors.mint; // #64D2B7
    final light = mint.lighten(0.2);

    expect(light.r, greaterThan(mint.r));
    expect(light.g, greaterThan(mint.g));
    expect(light.b, greaterThan(mint.b));
    // 提亮但不能接近黑：各分量归一化值应明显大于 0.2
    expect(light.r, greaterThan(0.2));
    expect(light.g, greaterThan(0.2));
    expect(light.b, greaterThan(0.2));
  });

  test('darken 压暗且不越过原色', () {
    const ice = GlassColors.iceBlue; // #70B6FF
    final dark = ice.darken(0.22);

    expect(dark.r, lessThan(ice.r));
    expect(dark.g, lessThan(ice.g));
    expect(dark.b, lessThan(ice.b));
    // 深化色仍应带明显色彩（各分量 ≥ 0.2），而非趋黑
    expect(dark.r, greaterThan(0.2));
    expect(dark.g, greaterThan(0.2));
    expect(dark.b, greaterThan(0.2));
  });

  test('边界：lighten(1) 为白，darken(1) 为黑', () {
    const c = GlassColors.lavender;
    final white = c.lighten(1.0);
    expect(white.r, greaterThan(0.99));
    expect(white.g, greaterThan(0.99));
    expect(white.b, greaterThan(0.99));

    final black = c.darken(1.0);
    expect(black.r, lessThan(0.01));
  });
}
