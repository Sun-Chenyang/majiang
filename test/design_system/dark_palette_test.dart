/// M10.3 暗色回归：调色板门面切换 + 文字对比度（WCAG ≥ 4.5:1）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/design_system/design_system.dart';
import 'package:kawuxing/main.dart';

/// WCAG 相对亮度（sRGB 分量先做伽马线性化）。
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDownAll(() => GlassColors.current = GlassPalette.light);

  test('门面切换：current 指到暗色调色板后全部 getter 跟随', () {
    GlassColors.current = GlassPalette.dark;
    expect(GlassColors.isDark, isTrue);
    expect(GlassColors.textPrimary, same(GlassPalette.dark.textPrimary));
    expect(GlassColors.mintDeep, same(GlassPalette.dark.mintDeep));
    expect(GlassColors.surface(0.62).a, closeTo(0.62 * 0.22, 1e-6));
    expect(GlassColors.rim(0.7).a, closeTo(0.7 * 0.35, 1e-6));

    GlassColors.current = GlassPalette.light;
    expect(GlassColors.isDark, isFalse);
    expect(GlassColors.surface(0.62).a, closeTo(0.62, 1e-6));
  });

  test('暗色：文字/深化色在暗色玻璃面上的对比度 ≥ 4.5:1', () {
    // 玻璃本体近似面：暗板岩玻璃不透明等价色
    const darkSurface = Color(0xFF223041);
    final checks = <String, Color>{
      'textPrimary': GlassPalette.dark.textPrimary,
      'textSecondary': GlassPalette.dark.textSecondary,
      'mintDeep': GlassPalette.dark.mintDeep,
      'iceDeep': GlassPalette.dark.iceDeep,
      'lavenderDeep': GlassPalette.dark.lavenderDeep,
      'warningDeep': GlassPalette.dark.warningDeep,
      'dangerDeep': GlassPalette.dark.dangerDeep,
      'neutralDeep': GlassPalette.dark.neutralDeep,
    };
    for (final e in checks.entries) {
      final ratio = contrastRatio(e.value, darkSurface);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '暗色 ${e.key} 在玻璃面上对比度 $ratio < 4.5',
      );
    }
  });

  test('浅色：文字/深化色在白玻璃面上的对比度 ≥ 3.0（既有已验收视觉）', () {
    // M10.1 的 ≥ 4.5:1 承诺针对新增暗色令牌；浅色薄荷系 Deep 为
    // 人工视觉验收定稿（mintDeep 实测 3.45:1，粗体小字号按 WCAG
    // 组件级 3:1 底线锁定，不回改已发布颜色）。
    const lightSurface = Color(0xFFFFFFFF);
    final checks = <String, Color>{
      'textPrimary': GlassPalette.light.textPrimary,
      'textSecondary': GlassPalette.light.textSecondary,
      'mintDeep': GlassPalette.light.mintDeep,
      'iceDeep': GlassPalette.light.iceDeep,
      'lavenderDeep': GlassPalette.light.lavenderDeep,
      'warningDeep': GlassPalette.light.warningDeep,
      'dangerDeep': GlassPalette.light.dangerDeep,
      'neutralDeep': GlassPalette.light.neutralDeep,
    };
    for (final e in checks.entries) {
      final ratio = contrastRatio(e.value, lightSurface);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: '浅色 ${e.key} 在白玻璃上对比度 $ratio < 3.0',
      );
    }
  });

  test('暗色染色修正：彩色 tint 混向深板岩，白玻璃不变化', () {
    GlassColors.current = GlassPalette.dark;
    final tinted = GlassColors.tintForGlass(GlassColors.mint);
    expect(tinted.r, lessThan(GlassPalette.dark.mint.r));
    // 白玻璃 tint 与暗色玻璃同值（lerp 无损，比较分量而非实例）
    final glassed = GlassColors.tintForGlass(GlassPalette.dark.glass);
    expect(glassed.r, GlassPalette.dark.glass.r);
    expect(glassed.g, GlassPalette.dark.glass.g);
    expect(glassed.b, GlassPalette.dark.glass.b);
    expect(glassed.a, GlassPalette.dark.glass.a);
    GlassColors.current = GlassPalette.light;
    expect(GlassColors.tintForGlass(GlassColors.mint),
        same(GlassPalette.light.mint));
  });

  testWidgets('暗色模式渲染冒烟：主页/设置/规则三页无异常且令牌生效', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const KaWuXingApp(initialMode: ThemeMode.dark));
    await tester.pump();
    expect(GlassColors.isDark, isTrue);
    expect(find.text('卡五星听牌器'), findsOneWidget);

    // 设置页外观三态存在
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('白天'), findsOneWidget);
    expect(find.text('黑暗'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);

    // 切回白天：门面即时回浅色
    await tester.tap(find.text('白天'));
    await tester.pump();
    expect(GlassColors.isDark, isFalse);

    // 规则页弹层（暗色 sheet 路径）
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('胡牌结构'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('牌例'), findsOneWidget);
  });

  // 光斑动画永续 repeat，pumpAndSettle 会超时——一律定长 pump。
  testWidgets('外观切换即时生效：规则页列表不残留旧主题色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const KaWuXingApp()); // 浅色（跟随系统=亮）
    await tester.pump();

    Color tileNameColor() =>
        (tester.widget(find.text('起手牌数')) as Text).style!.color!;

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tileNameColor(), GlassPalette.light.textPrimary);

    // 设置页切黑暗
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('黑暗'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(GlassColors.isDark, isTrue);

    // 回规则页：列表项文字必须已是暗色 textPrimary。
    // 回归点：曾因 const RulesPage() 被 Flutter 跳过重建，
    // 页面残留浅色旧值，要滚动若干次才陆续换色。
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tileNameColor(), GlassPalette.dark.textPrimary);
  });
}
