import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kawuxing/design_system/design_system.dart';

Widget _app({required double contentHeight}) {
  return MaterialApp(
    scrollBehavior: const GlassScrollBehavior(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          height: 400,
          width: 300,
          child: ListView(
            children: [
              SizedBox(
                  height: contentHeight,
                  width: 300,
                  child: const Text('content')),
            ],
          ),
        ),
      ),
    ),
  );
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable))
    .position;

void main() {
  testWidgets('快速 fling 到底恰好截停在边界，不越界飞行', (tester) async {
    await tester.pumpWidget(_app(contentHeight: 2000)); // 视口 400，maxExtent 1600
    final pos = _position(tester);
    expect(pos.pixels, 0);

    // 大速度甩到底：速度按剩余距离预截，终点应恰好等于 maxScrollExtent
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 10000);
    await tester.pumpAndSettle();

    expect(pos.pixels, pos.maxScrollExtent,
        reason: 'fling 应恰好停在底边界');
    expect(pos.outOfRange, isFalse);
  });

  testWidgets('拖动越界被钳制且松手弹回边界', (tester) async {
    await tester.pumpWidget(_app(contentHeight: 2000));
    final pos = _position(tester);

    // 从顶部继续向下拖（越界），位置不应低于软墙渐近极限 ~76.8px
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();

    expect(pos.pixels, greaterThanOrEqualTo(-77.0),
        reason: '越界拖动应被渐进压缩在 77px 内（软墙渐近极限）');
    expect(pos.pixels, lessThan(0), reason: '钳制区内应保持越界状态');

    await tester.pumpAndSettle();
    expect(pos.pixels, 0, reason: '松手后应弹回顶部边界');
    expect(pos.outOfRange, isFalse);
  });

  testWidgets('短列表 fling 也不越界', (tester) async {
    await tester.pumpWidget(_app(contentHeight: 200)); // 内容短于视口
    final pos = _position(tester);
    expect(pos.maxScrollExtent, 0);

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 10000);
    await tester.pumpAndSettle();

    expect(pos.pixels, 0, reason: '短内容 fling 应立即停住，不飞出');
    expect(pos.outOfRange, isFalse);
  });
}
