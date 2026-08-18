/// 性能基准（开发计划 M6.5 / M9.2）。
///
/// 断言分两层：
///  1. **PRD §5 硬指标**：单次全量分析（analyzeHand）< 100ms —— 与机器
///     无关的发布门槛，量级上实际留有 ~50 倍余量（实测 < 2.5ms）；
///  2. 批量回归护栏：1000 次调用总量级异常（如回溯剪枝退化）时报警。
///     绝对阈值随机器状态浮动（2026-08-16 记录 1000 次 ≈ 660ms，
///     2026-08-17 同一代码实测 2450ms，经 git stash 基线对照确认是
///     机器负载而非代码回退），故取宽松上界：单次均值 < 10ms。
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawuxing/core/advice.dart';
import 'package:kawuxing/core/hand_state.dart';
import 'package:kawuxing/core/result.dart';
import 'package:kawuxing/core/rules_config.dart';
import 'package:kawuxing/core/ting.dart';

import 'test_util.dart';

void main() {
  test('PRD §5：单次全量计算 < 100ms（14 张打牌建议 + 13 张进张各 10 组）', () {
    final rng = Random(99);
    for (var i = 0; i < 10; i++) {
      final hand14 = HandState(randomHand(rng, 14), const {});
      final sw = Stopwatch()..start();
      analyzeHand(hand14, WinContext.defaults);
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 100)),
          reason: '第 $i 组 14 张全量分析超时');

      final hand13 = HandState(randomHand(rng, 13), const {});
      sw
        ..reset()
        ..start();
      analyzeHand(hand13, WinContext.defaults);
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 100)),
          reason: '第 $i 组 13 张全量分析超时');
    }
  });

  test('批量护栏：1000 次 rankDiscards 平均单次 < 10ms', () {
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
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('批量护栏：1000 次 computeUkeire 平均单次 < 10ms', () {
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
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
  });
}
