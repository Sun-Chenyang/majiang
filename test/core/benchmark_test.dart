/// 性能基准（开发计划 M6.5）：随机 1000 组 14 张手牌跑全量打牌建议，
/// 总耗时 < 1s（单次 < 1ms，对 PRD"单次全量计算 < 100ms"指标留足余量）。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/advice.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/ting.dart';

import 'test_util.dart';

void main() {
  test('随机 1000 组 14 张 rankDiscards 总耗时 < 1s', () {
    final rng = Random(1000);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      rankDiscards(
        HandState(randomHand(rng, 14), const {}),
        WinContext.defaults,
      );
    }
    sw.stop();
    // ignore: avoid_print
    print('1000 次 rankDiscards 耗时 ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('随机 1000 组 13 张 computeUkeire 总耗时 < 500ms', () {
    final rng = Random(1001);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      computeUkeire(
        HandState(randomHand(rng, 13), const {}),
        WinContext.defaults,
      );
    }
    sw.stop();
    // ignore: avoid_print
    print('1000 次 computeUkeire 耗时 ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 500)));
  });
}
