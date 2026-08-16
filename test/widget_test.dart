import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kawuxing/features/calculator/widgets.dart';
import 'package:kawuxing/main.dart';

/// 用接近真机的竖屏视口跑测试：默认 800×600 比真机矮，
/// 手牌卡的情境开关行会触发竖向溢出。
Future<void> pumpPortrait(WidgetTester tester, Widget widget) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(widget);
}

/// 构造 prefill 计数数组（与 main.dart 调试通道同语义：牌种编码可重复）。
Uint8List prefillOf(List<int> kinds) {
  final c = Uint8List(21);
  for (final t in kinds) {
    c[t]++;
  }
  return c;
}

void main() {
  testWidgets('主页渲染与手牌计数', (WidgetTester tester) async {
    await pumpPortrait(tester, const KaWuXingApp());

    // 标题与空态提示
    expect(find.text('卡五星听牌器'), findsOneWidget);
    expect(find.textContaining('点击上方牌池录入手牌'), findsOneWidget);

    // 牌池应有 21 张牌面（图片加载失败时走汉字回退，不影响布局）
    // 点击牌池第一格（1筒）两次 → 已选牌 2 张
    await tester.tap(find.byType(PoolTileCell).first);
    await tester.pump();
    await tester.tap(find.byType(PoolTileCell).first);
    await tester.pump();

    expect(find.textContaining('已选牌 2 张', findRichText: true), findsOneWidget);
    // 2 张 = 3n+2（推断碰/杠过 4 组），自动进入待出牌（打牌建议）模式
    expect(find.text('已上牌 · 待出牌'), findsOneWidget);

    // 录入后出现情境开关（自摸默认开）
    expect(find.text('自摸'), findsOneWidget);
  });

  testWidgets('n 向听量化展示与进张列表', (WidgetTester tester) async {
    // 123筒 789条 4筒 7筒 1条 4条 中 白白（13 张，三向听，shanten_test 已验证）
    await pumpPortrait(
      tester,
      KaWuXingApp(prefill: prefillOf([
        0, 1, 2, // 123筒
        3, 6, // 4筒 7筒
        9, 12, // 1条 4条
        15, 16, 17, // 789条
        18, // 中
        20, 20, // 白白
      ])),
    );

    expect(find.text('已出牌 · 待上牌'), findsOneWidget);
    expect(find.text('未听牌 · 3 向听'), findsOneWidget);
    expect(find.textContaining('进张'), findsWidgets);
  });

  testWidgets('听牌卡片展示番型与结构（术语用"将"）', (WidgetTester tester) async {
    // 123筒 789筒 4筒 6筒 123条 55条（13 张，听 5筒 卡五星）
    await pumpPortrait(
      tester,
      KaWuXingApp(prefill: prefillOf([
        0, 1, 2, 6, 7, 8, // 筒 123/789
        3, 5, // 4筒 6筒
        9, 10, 11, 13, 13, // 123条 55条
      ])),
    );

    expect(find.text('已出牌 · 待上牌'), findsOneWidget);
    expect(find.text('听牌'), findsOneWidget);
    expect(find.textContaining('卡五星 ×2'), findsOneWidget);
    expect(find.textContaining('将 '), findsWidgets);
    expect(find.textContaining('雀头'), findsNothing);
  });

  testWidgets('设置页规则速览', (WidgetTester tester) async {
    await pumpPortrait(tester, const KaWuXingApp());

    // 切到设置 Tab（非选中槽位只显示图标；氛围底图是无限动画，不能 pumpAndSettle）
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('规则速览'), findsOneWidget);
    expect(find.textContaining('卡张夹 5'), findsOneWidget); // 固定定义速览
    expect(find.textContaining('只能自摸'), findsOneWidget);
  });

  testWidgets('规则页牌例以牌面图片展示', (WidgetTester tester) async {
    await pumpPortrait(tester, const KaWuXingApp());

    // 切到规则 Tab
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump(const Duration(milliseconds: 600));

    // 「胡牌结构」位于列表顶部无需滚动，且带牌例图（牌例渲染验证够用）
    await tester.tap(find.text('胡牌结构'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('牌例'), findsOneWidget);
    // 牌面图片渲染（MiniTile），而非纯文字牌例
    expect(find.byType(MiniTile), findsWidgets);
    expect(find.textContaining('作将'), findsOneWidget); // 牌例说明
  });
}
