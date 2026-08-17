# AGENTS.md · 卡五星听牌器

面向 AI 代理（与人类协作者）的项目工作指南。改动前先读相关文档。

## 项目是什么

湖北三人麻将「卡五星」的**单机听牌器** App：录入手牌 → 即时计算听牌 /
打牌建议 / 番型。Flutter (stable 3.44 / Dart 3.12)，目标 Android 8+，
竖屏，无网络依赖。**Flutter 工程即仓库根目录**（2026-08-16 起从 app/
上移，为 git 开源做准备）；`library/` 存放项目文档（不参与构建）。

**当前阶段**（2026-08-16）：v0.2 算法深化主体已完成——M6 向听数引擎
（shanten/decompose + 11 万组对拍护栏）、M7 全 14 番型（含碰碰胡）/情境开关/
字牌碰杠标记、M8.1/8.2 UI 接入（n 向听徽标、任意向听进张列表、
多分解番型、损失 ×N 番提示），122 例测试全绿。规则已全部裁决固定
（卡五星=4/6 卡张夹 5 筒条同计；屁胡只能自摸），**RulesConfig 与
shared_preferences 已整体移除**。**剩余：8.3 碰杠时机建议、
8.4 已见牌标记（P1）、M9 回归发布与 M10 黑暗模式**，任务分解见
[开发计划 §3](./docs/03-开发计划.md)，算法规格见
[技术方案 §4](./library/01-技术方案设计.md)（§4.0 有现状与目标差距表），
算法结果如何接入 UI 见技术方案 §5.2 的接口契约。

## 文档地图（按需阅读）

**随仓库分发（library/，长期有效）**：

| 文档 | 内容 |
|---|---|
| **[library/02-UI设计规范.md](./library/02-UI设计规范.md)** | **设计系统：光照规则/色彩令牌/组件规范/滚动物理/资产规范/性能预算。任何 UI 改动前必读** |
| [library/01-技术方案设计.md](./library/01-技术方案设计.md) | 架构、算法（胡牌判定/听牌枚举/向听数/番型）、测试策略 |
| [library/03-卡五星规则.md](./library/03-卡五星规则.md) | 规则事实来源（番型总表、行牌规则），规则页数据整理自此 |

**本地归档（docs/，已 gitignore 不随仓库分发）**：

| 文档 | 内容 |
|---|---|
| [docs/03-开发计划.md](./docs/03-开发计划.md) | 里程碑与任务拆分（M6-M10 进行中/待办的活跃文档） |
| [docs/01-产品需求说明.md](./docs/01-产品需求说明.md) | PRD：v0.1 时期需求与验收标准（历史参考，当前作用有限） |

## 工程结构与关键约束

```
lib/
├── core/                  # 纯 Dart 算法层（UI 只消费 result.dart 的 analyzeHand）：
│   ├── tile.dart          #   牌编码（21 种）
│   ├── hand_state.dart    #   手牌状态（副露省录推断、剩余张数）
│   ├── rules_config.dart  #   WinContext（情境）；规则已全部裁决固定，无配置
│   ├── win.dart           #   decompose 全分解枚举（WinStructure）
│   ├── shanten.dart       #   向听数（标准型回溯 + 七对定制，公式坑见文件注释）
│   ├── fan.dart           #   全 14 番型 + "不计"互斥 + 情境
│   ├── ting.dart          #   进张泛化 computeUkeire + WinWithFan
│   ├── advice.dart        #   打牌建议排序 (shanten, 进张, 番型加权)
│   ├── result.dart        #   analyzeHand 总入口
│   ├── engine.dart        #   v0.1 布尔版引擎（保留作对拍基准，UI 已不引用）
│   └── feedback.dart      #   触感开关
├── design_system/         # 设计系统（见 04 规范），业务侧经 barrel 引入：
│                          #   import 'package:kawuxing/design_system/design_system.dart';
├── features/
│   ├── calculator/        # 主页：牌池 + 手牌 + 情境开关 + 结果区（业务文案勿动，widget 测试依赖）
│   ├── rules/             # 规则速查：搜索 + 弹层详情（牌面图片牌例）
│   ├── settings/          # 设置：动态底图/触感（状态在 DashboardShell）
│   └── shell/             # 三 Tab 外壳（IndexedStack 保活 + 悬浮底栏）
└── main.dart              # 预填调试通道见文件头注释
```

**不变式（改坏即测试红）：**

1. 计算正确性是生命线：`core/` 算法判定结果不许改，除非有对拍/穷举
   测试证明（`test/core/cross_check_test.dart` 的 11 万组对拍是护栏；
   `engine.dart` 旧路径保留做对拍基准，同样不许动）；
2. 主页业务文案（`已选牌 X 张`、`已上牌 · 待出牌`、`已出牌 · 待上牌`
   等）与 `PoolTileCell` 类名被 `test/widget_test.dart` 引用；
3. 全局光照方向固定左上→右下（规范 §2），新组件不得违背（黑暗模式
   亦不例外，见开发计划 M10）；
4. Flutter 3.44 的 `Color.r/g/b/a` 是 0~1 归一化值（规范 §3 的前车之鉴）。

## 验证命令（每次改动后，仓库根目录直接执行）

```bash
flutter analyze   # 0 issue 才算过
flutter test      # 全绿（含滚动物理、颜色语义回归测试）
flutter build apk --debug   # 需要实机验证时（gradlew 在 android/）
```

实机：模拟器 `emulator-5554`，包名 `dev.kawuxing.kawuxing`，
调试预填：`adb shell am start -n dev.kawuxing.kawuxing/.MainActivity --es prefill "0,0,0,1,2,3,4,5,6,7,8,8,8"`。
视觉验收用裁剪放大截图逐像素核对，不信全屏截图的粗描述。
