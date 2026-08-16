import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/advice.dart';
import '../../core/fan.dart';
import '../../core/feedback.dart';
import '../../core/hand_state.dart';
import '../../core/result.dart';
import '../../core/rules_config.dart';
import '../../core/ting.dart';
import '../../core/tile.dart';
import '../../core/win.dart';
import '../../design_system/design_system.dart';
import 'widgets.dart';

/// 主页：标题栏 → 牌池玻璃卡（顶）→ 手牌玻璃卡（中）→ 结果区（下）。
///
/// 结果区是 (手牌, 情境) 的纯函数渲染：每次输入全量重算（v0.2 起由
/// analyzeHand 提供向听数 / 进张 / 全分解番型 / 建议）。手牌是"待出牌"
/// 还是"待上牌"由张数自动判定（3n+2 / 3n+1），无需手动切换。
class CalculatorPage extends StatefulWidget {
  /// 初始暗牌计数（调试/视觉测试用，正常启动为 null）。
  final Uint8List? initialCounts;

  const CalculatorPage({super.key, this.initialCounts});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  late final Uint8List _counts = _initCounts();
  final List<Uint8List> _undoStack = [];
  WinContext _ctx = const WinContext(selfDraw: true); // 默认自摸：展示完整番型潜力
  final Set<int> _honorMelds = {};

  Uint8List _initCounts() {
    final c = Uint8List(kTileKindCount);
    final init = widget.initialCounts;
    if (init != null) {
      for (var t = 0; t < kTileKindCount && t < init.length; t++) {
        c[t] = init[t] > 4 ? 4 : init[t];
      }
    }
    return c;
  }

  int get _total {
    var s = 0;
    for (final v in _counts) {
      s += v;
    }
    return s;
  }

  void _add(int t) {
    if (_counts[t] >= 4) return;
    AppFeedback.tap();
    setState(() {
      _pushUndo();
      _counts[t]++;
    });
  }

  void _remove(int t) {
    if (_counts[t] == 0) return;
    setState(() {
      _pushUndo();
      _counts[t]--;
    });
  }

  void _pushUndo() {
    _undoStack.add(Uint8List.fromList(_counts));
    if (_undoStack.length > 30) _undoStack.removeAt(0);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _counts.setAll(0, _undoStack.removeLast());
    });
  }

  void _reset() {
    setState(() {
      _pushUndo();
      _counts.fillRange(0, kTileKindCount, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = analyzeHand(HandState(_counts, _honorMelds), _ctx);
    return SafeArea(
      bottom: false, // 底部安全区由外层 GlassBottomBar 区域处理
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildPoolCard(),
          const SizedBox(height: 12),
          _buildHandCard(result),
          const SizedBox(height: 12),
          Expanded(child: _buildResult(result)),
        ],
      ),
    );
  }

  // ---------------- 标题栏 ----------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('卡五星听牌器', style: GlassTypography.display),
                const SizedBox(height: 3),
                Text('筒 · 条 · 中发白 · 即时听牌与打牌建议',
                    style: GlassTypography.caption),
              ],
            ),
          ),
          SkeuoButton(
            icon: Icons.undo_rounded,
            glass: true,
            haptics: false,
            minHeight: 36,
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          const SizedBox(width: 8),
          SkeuoButton(
            icon: Icons.restart_alt_rounded,
            glass: true,
            accent: GlassColors.danger,
            haptics: false,
            minHeight: 36,
            onPressed: _total == 0 ? null : _reset,
          ),
        ],
      ),
    );
  }

  // ---------------- 牌池（置顶玻璃卡） ----------------

  Widget _buildPoolCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        radius: 22,
        blurSigma: 14,
        ambient: GlassColors.mint, // 牌池近影染薄荷，呼应顶部光斑
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 3.0;
            final cellW = (constraints.maxWidth - gap * 8) / 9;
            return Column(
              children: [
                _poolRow(kTongTiles, cellW, gap),
                const SizedBox(height: 4),
                _poolRow(kTiaoTiles, cellW, gap),
                const SizedBox(height: 4),
                _poolRow(kHonorTiles, cellW, gap, alignLeft: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _poolRow(List<int> tiles, double cellW, double gap, {bool alignLeft = false}) {
    final cells = tiles
        .map((t) => SizedBox(
              width: cellW,
              child: PoolTileCell(tile: t, count: _counts[t], onTap: () => _add(t)),
            ))
        .toList();
    if (!alignLeft) {
      return Row(
        children: [
          for (final c in cells) ...[Expanded(child: c), if (c != cells.last) SizedBox(width: gap)],
        ],
      );
    }
    return Row(children: [
      for (var i = 0; i < cells.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        cells[i],
      ],
    ]);
  }

  // ---------------- 手牌区（玻璃卡 + 凹槽托盘 + 情境开关） ----------------

  (Color, Color) _statusColors(HandAnalysis result) {
    final total = _total;
    if (total == 0) return (GlassColors.neutral, GlassColors.textSecondary);
    if (!result.validPhase) return (GlassColors.danger, GlassColors.dangerDeep);
    if (result.drawPhase) return (GlassColors.warning, GlassColors.warningDeep);
    return (GlassColors.iceBlue, GlassColors.iceDeep);
  }

  String _statusText(HandAnalysis result) {
    final total = _total;
    if (total == 0) return '待录入';
    if (!result.validPhase) return '张数有误';
    if (result.drawPhase) return '已上牌 · 待出牌';
    return '已出牌 · 待上牌';
  }

  Widget _statusPill(HandAnalysis result) {
    final (main, deep) = _statusColors(result);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // 状态胶囊：主题色 α0.20→α0.08 对角渐变，左上亮右下透
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            main.withValues(alpha: 0.20),
            main.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        border: Border.all(color: main.withValues(alpha: 0.45)),
      ),
      child: Text(
        _statusText(result),
        style: TextStyle(color: deep, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildHandCard(HandAnalysis result) {
    final total = _total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        radius: 22,
        blurSigma: 14,
        ambient: GlassColors.iceBlue, // 手牌卡近影染冰蓝
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '已选牌 $total 张',
                          style: const TextStyle(
                            color: GlassColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (result.meldCount > 0)
                          TextSpan(
                            text: ' · 碰/杠过 ${result.meldCount} 组',
                            style: const TextStyle(
                                color: GlassColors.iceDeep, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
                _statusPill(result),
              ],
            ),
            const SizedBox(height: 8),
            _handTray(),
            const SizedBox(height: 8),
            _contextRow(result),
          ],
        ),
      ),
    );
  }

  /// 手牌托盘：比卡片更深一层的浅玻璃凹槽，视觉上"嵌"进卡片。
  Widget _handTray() {
    final total = _total;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            Colors.white.withValues(alpha: 0.42), // 槽底左上：受光亮
            Colors.white.withValues(alpha: 0.16), // 槽底右下：背光暗 → 凹陷感
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: total == 0
          ? Center(
              child: Text('点击上方牌池录入手牌（已碰/杠的牌不用录入）',
                  style: GlassTypography.caption),
            )
          : Builder(builder: (context) {
              final tiles = <int>[];
              for (var t = 0; t < kTileKindCount; t++) {
                tiles.addAll(List.filled(_counts[t], t));
              }
              return Wrap(
                spacing: 3,
                runSpacing: 4,
                children: [
                  for (final t in tiles)
                    InkWell(
                      onTap: () {
                        AppFeedback.tap();
                        _remove(t);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: TileCard(tile: t, width: 34),
                    ),
                ],
              );
            }),
    );
  }

  /// 情境开关 + 字牌碰/杠标记（PRD FR4.2 / FR1.5）。
  Widget _contextRow(HandAnalysis result) {
    if (_total == 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _ctxChip('自摸', _ctx.selfDraw, (v) {
          setState(() => _ctx = _ctx.copyWith(selfDraw: v));
        }),
        // 杠上开花本身即自摸：打开时联动开启自摸，避免"开了杠上开花
        // 却因未开自摸而不生效"的困惑
        _ctxChip('杠上开花', _ctx.afterGang, (v) {
          setState(() => _ctx = v
              ? _ctx.copyWith(afterGang: true, selfDraw: true)
              : _ctx.copyWith(afterGang: false));
        }),
        _ctxChip('抢杠', _ctx.robKong, (v) {
          setState(() => _ctx = _ctx.copyWith(robKong: v));
        }),
        _ctxChip('杠上炮', _ctx.gangPao, (v) {
          setState(() => _ctx = _ctx.copyWith(gangPao: v));
        }),
        if (result.meldCount > 0) ...[
          const SizedBox(
            width: 6, height: 30,
            child: VerticalDivider(
              width: 1,
              color: Colors.white70,
            ),
          ),
          for (final t in kHonorTiles)
            _ctxChip('碰${tileName(t)}', _honorMelds.contains(t), (v) {
              setState(() {
                v ? _honorMelds.add(t) : _honorMelds.remove(t);
              });
            }),
        ],
      ],
    );
  }

  /// 拟物小开关 chip：选中态薄荷染色玻璃（左上亮右下暗，遵循全局光照）。
  Widget _ctxChip(String label, bool value, ValueChanged<bool> onChanged) {
    final (base, border, fg) = value
        ? (GlassColors.mint, GlassColors.mint.withValues(alpha: 0.65),
            GlassColors.mintDeep)
        : (Colors.white, Colors.white.withValues(alpha: 0.62),
            GlassColors.textTertiary);
    return InkWell(
      onTap: () {
        AppFeedback.tap();
        onChanged(!value);
      },
      borderRadius: BorderRadius.circular(GlassRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: GlassLight.begin,
            end: GlassLight.end,
            colors: [
              base.withValues(alpha: value ? 0.30 : 0.34),
              base.withValues(alpha: value ? 0.16 : 0.20),
            ],
          ),
          borderRadius: BorderRadius.circular(GlassRadius.pill),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---------------- 结果区 ----------------

  Widget _buildResult(HandAnalysis result) {
    if (!result.validPhase) {
      final total = _total;
      return _resultCard(
        icon: Icons.info_outline_rounded,
        color: GlassColors.danger,
        deepColor: GlassColors.dangerDeep,
        title: total == 0 ? '开始录入' : '手牌张数不对（当前 $total 张）',
        child: const Text(
          '手牌应为 待摸 3n+1 张（13/10/7/4/1）或 待打 3n+2 张（14/11/8/5/2）。\n'
          '已碰/杠出的牌不用录入：碰一组后待摸剩 10 张、待打剩 11 张。',
          style: GlassTypography.body,
        ),
      );
    }

    if (result.drawPhase) return _buildDrawResult(result);
    return _buildWaitResult(result);
  }

  /// 待摸（3n+1）：听牌判断 / n 向听进张。
  Widget _buildWaitResult(HandAnalysis result) {
    final ukeire = result.ukeire!;
    final totalRemain = ukeire.totalRemain;
    if (ukeire.shanten == 0) {
      return ListView(
        padding: _resultPadding(),
        children: [
          _badgeHeader(
            icon: Icons.check_circle_outline_rounded,
            color: GlassColors.mint,
            deepColor: GlassColors.mintDeep,
            title: '听牌',
            subtitle: '听 ${ukeire.accepted.length} 种 · 共 $totalRemain 张',
          ),
          const SizedBox(height: 8),
          for (final w in ukeire.accepted) _waitCard(w),
        ],
      );
    }
    return ListView(
      padding: _resultPadding(),
      children: [
        _badgeHeader(
          icon: Icons.arrow_circle_up_rounded,
          color: GlassColors.iceBlue,
          deepColor: GlassColors.iceDeep,
          title: '未听牌 · ${ukeire.shanten} 向听',
          subtitle: '进张 ${ukeire.accepted.length} 种 · 共 $totalRemain 张',
        ),
        const SizedBox(height: 8),
        if (ukeire.accepted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('当前无进张：手牌结构已定型或剩余张数不足。',
                style: GlassTypography.body),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in ukeire.accepted) _miniWaitChip(w, highlight: true),
            ],
          ),
      ],
    );
  }

  /// 待打（3n+2）：已胡展示 / 打牌建议。
  Widget _buildDrawResult(HandAnalysis result) {
    if (result.isWin) {
      return _resultCard(
        icon: Icons.celebration_outlined,
        color: GlassColors.lavender,
        deepColor: GlassColors.lavenderDeep,
        title: '已胡牌！',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in _dedupeWins(result.winStructures))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final h in w.score.hits)
                      FanChip(label: _fanLabel(h.type)),
                    if (w.isBest)
                      const FanChip(label: '最优 ★'),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    final advice = result.advice!;
    if (advice.options.isEmpty) {
      return const SizedBox.shrink();
    }
    final best = advice.options.first;
    return ListView.builder(
      padding: _resultPadding(),
      itemCount: advice.options.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          final tingCount = advice.options.where((o) => o.tenpai).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _badgeHeader(
                icon: Icons.lightbulb_outline_rounded,
                color: GlassColors.warning,
                deepColor: GlassColors.warningDeep,
                title: '打牌建议',
                subtitle: tingCount > 0
                    ? '$tingCount 种打法可听牌'
                    : '暂无可听牌打法，按进张排序',
              ),
              if (result.notices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(result.notices.join('\n'),
                      style: GlassTypography.caption),
                ),
            ],
          );
        }
        final opt = advice.options[i - 1];
        return _discardCard(opt,
            advice: advice,
            isBest: identical(opt, best) && opt.tenpai);
      },
    );
  }

  EdgeInsets _resultPadding() => const EdgeInsets.fromLTRB(16, 4, 16, 118);

  // ---------------- 结果区零件 ----------------

  Widget _badgeHeader({
    required IconData icon,
    required Color color,
    required Color deepColor,
    required String title,
    required String subtitle,
  }) {
    // 状态头卡：彩色薄玻璃（tint 强度仅 0.13，底图光斑可透）
    return GlassCard(
      frost: false,
      surfaceTint: color,
      tintStrength: 0.13,
      shadow: false,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: deepColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(title,
                maxLines: 2,
                style: TextStyle(
                    color: deepColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(subtitle,
                maxLines: 2,
                textAlign: TextAlign.right,
                style: GlassTypography.caption),
          ),
        ],
      ),
    );
  }

  /// 同一多分解组合按番型描述去重（排序已保证最优在前）。
  List<WinWithFan> _dedupeWins(List<WinWithFan> wins) {
    final seen = <String>{};
    final out = <WinWithFan>[];
    for (final w in wins) {
      if (seen.add(w.score.describe)) out.add(w);
    }
    return out;
  }

  Widget _waitCard(AcceptedTile w) {
    final wins = _dedupeWins(w.wins ?? const []);
    final anyBlocked = wins.isNotEmpty && wins.every((x) => !x.score.canWin);
    return GlassCard(
      frost: false,
      tintStrength: 0.5,
      shadow: false,
      radius: 16,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MiniTile(tile: w.tile, width: 34),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                child: Text(tileName(w.tile),
                    style: const TextStyle(
                        color: GlassColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              Text(
                w.remain == 0 ? '已见 4 张' : '剩 ${w.remain} 张',
                style: TextStyle(
                    color: w.remain == 0
                        ? GlassColors.textTertiary
                        : GlassColors.mintDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final win in wins)
                      for (var i = 0; i < win.score.hits.length; i++)
                        FanChip(
                          label: _fanLabel(win.score.hits[i].type,
                              best: win.isBest && i == 0),
                        ),
                  ],
                ),
              ),
            ],
          ),
          if (wins.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_structureText(wins.first.structure, w.tile),
                style: GlassTypography.caption),
          ],
          if (anyBlocked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('点炮不可胡 · 屁胡只能自摸（打开"自摸"开关查看自摸番型）',
                  style: TextStyle(
                      color: GlassColors.dangerDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  /// 番型标签文案：最优分解首个标签带 ★。
  String _fanLabel(FanType type, {bool best = false}) =>
      '${type.displayLabel}${best ? ' ★' : ''}';

  /// 牌型结构预览（FR2.3）：将 + 面子，或七对形态（术语见规则页）。
  String _structureText(WinStructure s, int winTile) {
    final winMark = winTile >= 0 ? '（胡 ${tileName(winTile)}）' : '';
    if (s.isSevenPairs) return '七对形态$winMark';
    final head = '${tileName(s.pair)}${tileName(s.pair)}';
    final melds = s.melds.map((m) => m.toString()).join(' ');
    final extra = _handMeldCount > 0 ? ' + 碰/杠 $_handMeldCount 组' : '';
    return '将 $head · $melds$extra$winMark';
  }

  int get _handMeldCount => HandState(_counts, _honorMelds).meldCount;

  Widget _miniWaitChip(AcceptedTile w, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.30),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? GlassColors.iceBlue.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniTile(tile: w.tile, width: 24),
          const SizedBox(width: 5),
          Text(
            w.remain == 0 ? '${tileName(w.tile)}·已见4' : '${tileName(w.tile)}·${w.remain}',
            style: TextStyle(
              color: highlight ? GlassColors.iceDeep : GlassColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _discardCard(DiscardOptionV2 opt,
      {required DiscardAdvice advice, required bool isBest}) {
    final (accent, accentDeep) = opt.tenpai
        ? (GlassColors.mint, GlassColors.mintDeep)
        : (GlassColors.iceBlue, GlassColors.iceDeep);
    final loss = advice.lossHints[opt.discard];
    return GlassCard(
      frost: false,
      // 推荐打法：薄荷染色玻璃 + 外发光描边突出
      surfaceTint: isBest ? accent : GlassColors.glassWhite,
      tintStrength: isBest ? 0.18 : 0.5,
      shadow: false,
      radius: 16,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (isBest) ...[
            _bestBadge(accent),
            const SizedBox(width: 6),
          ],
          Text('打', style: TextStyle(color: GlassColors.textTertiary, fontSize: 13)),
          const SizedBox(width: 6),
          MiniTile(tile: opt.discard, width: 30),
          const SizedBox(width: 6),
          SizedBox(
            width: 46,
            child: Text(tileName(opt.discard),
                style: const TextStyle(
                    color: GlassColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opt.tenpai
                      ? '听牌 · 听 ${opt.ukeire.accepted.length} 种 · 共 ${opt.totalRemain} 张'
                      : '未听 · ${opt.shanten} 向听 · 进张 ${opt.ukeire.accepted.length} 种 ${opt.totalRemain} 张',
                  style: TextStyle(
                      color: accentDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                if (opt.tenpai) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final w in opt.ukeire.accepted) _tinyTileChip(w),
                    ],
                  ),
                  if (opt.bestFanMultiplier > 1) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        FanChip(label: '最优番型 ×${opt.bestFanMultiplier}'),
                        if (loss != null)
                          FanChip(label: '损失 ×$loss 番'),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 「推荐」徽标：拟物小凸起（与 SkeuoButton 同光照语言）。
  Widget _bestBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [accent.lighten(0.24), accent.darken(0.1)],
        ),
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        boxShadow: GlassShadow.chip(accent),
      ),
      child: const Text('推荐',
          style: TextStyle(
              color: GlassColors.textOnAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _tinyTileChip(AcceptedTile w) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniTile(tile: w.tile, width: 20),
          const SizedBox(width: 3),
          Text('${w.remain}',
              style: const TextStyle(
                  color: GlassColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _resultCard({
    required IconData icon,
    required Color color,
    required Color deepColor,
    required String title,
    required Widget child,
  }) {
    return ListView(
      padding: _resultPadding(),
      children: [
        GlassCard(
          frost: false,
          surfaceTint: color,
          tintStrength: 0.12,
          shadow: false,
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: deepColor, size: 24),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: deepColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
