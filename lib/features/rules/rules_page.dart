import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../design_system/design_system.dart';
import '../calculator/widgets.dart' show MiniTile;

/// 牌例中的一段牌（一组相关牌，如一个顺子/刻子/对子/将），
/// 段与段之间以间隔分隔（替代文字版里的"+"号）。
class ExampleGroup {
  final List<int> tiles;

  /// 关键段（胡牌张所在顺子、暗四归一的第 4 张等）：薄荷描边 + "胡"角标。
  final bool highlight;

  const ExampleGroup(this.tiles, {this.highlight = false});
}

/// 规则条目模型（数据整理自 docs/卡五星规则.md）。
class RuleEntry {
  const RuleEntry({
    required this.category,
    required this.name,
    required this.multiplier,
    required this.desc,
    this.descItems,
    this.note,
    this.exampleTiles,
    this.exampleNote,
  });

  final String category;
  final String name;

  /// 倍数徽标（如 "×2"；基础玩法为空串）。
  final String multiplier;

  final String desc;

  /// 分条解释（详情弹层逐条换行 + 小圆点；每条"："前的词自动加粗）。
  /// [desc] 仍用于列表页的单行预览。
  final List<String>? descItems;

  /// 「不计」互斥或补充说明。
  final String? note;

  /// 牌面示例（图片段）。
  final List<ExampleGroup>? exampleTiles;

  /// 牌例补充说明（一行小字）。
  final String? exampleNote;
}

const List<RuleEntry> _kRules = [
  RuleEntry(
    category: '基础玩法',
    name: '起手牌数',
    multiplier: '',
    desc: '庄家起手 14 张、闲家 13 张，庄家先出牌。'
        '因此轮到自己时手牌在 13 张（听牌判断）与 14 张（打牌决策）间切换。',
  ),
  RuleEntry(
    category: '基础玩法',
    name: '丢骰子与起牌',
    multiplier: '',
    desc: '丢骰子定庄、按点数定方位起牌：庄家 14 张、闲家 13 张。',
    descItems: [
      '定庄：首局丢骰子，点数大的做庄；之后每局由上局胡牌者做庄。',
      '定方位：骰点决定从哪家门前的牌墙起牌——159 是自己这边，'
          '2610 是右手边，3711 是对面，4812 是左手边。',
      '起牌：每人每次拿两墩（4 张），共拿 3 次；随后庄家跳牌（隔一墩）'
          '再拿 2 张凑足 14 张，闲家各自补 1 张（13 张）。',
      '开局：庄家打出第一张牌，正式开始行牌。',
    ],
  ),
  RuleEntry(
    category: '基础玩法',
    name: '行牌顺序',
    multiplier: '',
    desc: '逆时针轮流出牌；碰/杠后由碰/杠者继续出牌。',
    descItems: [
      '逆时针：上家打完轮到你，你打完轮到下家，依次轮流。',
      '碰/杠优先：任何一家打出的牌你都可以碰或杠；碰/杠之后改由你继续出牌。',
      '摸牌：轮到自己且无人碰/杠时，从牌墙摸一张，再打出一张。',
    ],
  ),
  RuleEntry(
    category: '基础玩法',
    name: '能碰能杠不能吃',
    multiplier: '',
    desc: '可以碰、可以杠，但不能吃。',
    descItems: [
      '碰：手中已有 2 张相同的牌，任何玩家打出第 3 张即可碰。',
      '杠：手中 3 张同牌可杠他人打出的第 4 张（点杠）；'
          '手中 4 张同牌可暗杠；已碰后再摸到第 4 张可补杠。',
      '不吃：上家打出的牌即使能组顺子也不能吃。',
    ],
  ),
  RuleEntry(
    category: '基础玩法',
    name: '胡牌结构',
    multiplier: '',
    desc: '标准结构：1 对将 + 4 组面子；特殊结构：七对。',
    descItems: [
      '标准结构：1 对将 + 4 组面子（顺子或刻子）。',
      '特殊结构：七对——7 个对子，需门清。',
    ],
    note: '术语见「常用术语」条目。',
    exampleTiles: [
      ExampleGroup([0, 0]), // 将 1筒1筒
      ExampleGroup([0, 1, 2]), // 123筒
      ExampleGroup([3, 4, 5]), // 456筒
      ExampleGroup([15, 16, 17]), // 789条
      ExampleGroup([18, 18, 18]), // 中中中
    ],
    exampleNote: '1筒1筒 作将，其余 4 组为面子',
  ),
  RuleEntry(
    category: '基础玩法',
    name: '常用术语',
    multiplier: '',
    desc: '将、面子、门清、卡张等本地常用叫法速览。',
    descItems: [
      '将（对将）：胡牌时那 1 对相同的牌，如 5条5条。',
      '面子：1 组顺子（3 张同花色连续，如 4筒5筒6筒）'
          '或 1 组刻子（3 张相同，如 中中中）。',
      '门清：没有碰/杠出过牌；碰、杠出去的牌不算手牌。',
      '卡张：所胡的牌正好夹在手里两张牌中间（如手里 4筒、6筒 胡 5筒）。',
    ],
  ),
  RuleEntry(
    category: '基础玩法',
    name: '杠后补牌',
    multiplier: '',
    desc: '开杠后从牌墙末尾补摸一张，再照常出牌。',
    descItems: [
      '补牌：开杠后立刻从牌墙末尾补摸一张（手牌数不变），再打出一张。',
      '杠上开花：补摸的这张正好胡牌 → 杠上开花 ×2（必须自摸）。',
      '即时结算：杠牌当场收分，不等胡牌（详见「杠牌即结」）。',
    ],
  ),
  RuleEntry(
    category: '基础玩法',
    name: '打漂',
    multiplier: '',
    desc: '开局各自选择漂分。结算时输家额外支付「胡牌者漂分 + 自己的漂分」，放大输赢。',
  ),
  RuleEntry(
    category: '基础玩法',
    name: '杠牌即结',
    multiplier: '',
    desc: '杠牌实时结算分数，不等胡牌。点杠（明杠）：收放杠者 2 倍底分。',
  ),
  RuleEntry(
    category: '基础玩法',
    name: '自摸找马',
    multiplier: '',
    desc: '自摸胡牌时从牌堆摸一张"马"，按牌点额外加分。',
  ),
  RuleEntry(
    category: '番型速查',
    name: '屁胡（平胡）',
    multiplier: '1',
    desc: '基础胡牌，只能自摸；点炮胡必须带有其他番型。',
    exampleTiles: [
      ExampleGroup([0, 1, 2]),
      ExampleGroup([3, 4, 5]),
      ExampleGroup([6, 7, 8]),
      ExampleGroup([9, 10, 11]),
      ExampleGroup([13, 13]),
    ],
    exampleNote: '无任何其他番型的基础胡牌',
  ),
  RuleEntry(
    category: '番型速查',
    name: '碰碰胡',
    multiplier: '×2',
    desc: '4 组面子全是刻子（手中的暗刻 + 碰/杠出去的刻）加一对将。',
    exampleTiles: [
      ExampleGroup([13, 13]), // 将 5条5条
      ExampleGroup([0, 0, 0]),
      ExampleGroup([2, 2, 2]),
      ExampleGroup([18, 18, 18]),
      ExampleGroup([19, 19, 19]),
    ],
    exampleNote: '碰/杠出去的刻子也算——碰满 4 组后单钓也是碰碰胡',
  ),
  RuleEntry(
    category: '番型速查',
    name: '卡五星',
    multiplier: '×2',
    desc: '手中持有 4筒+6筒，所胡牌为 5筒 且作为顺子中间张（"卡张"胡五星）。',
    note: '筒、条同计：手里 4条+6条，胡 5条 同样算卡五星 ×2。',
    exampleTiles: [
      ExampleGroup([0, 1, 2]),
      ExampleGroup([3, 4, 5], highlight: true), // 456筒：胡 5筒 为中间张
      ExampleGroup([6, 7, 8]),
      ExampleGroup([9, 10, 11]),
      ExampleGroup([18, 18]),
    ],
    exampleNote: '高亮的 4筒-5筒-6筒 顺子：手里 4筒、6筒 夹胡 5筒',
  ),
  RuleEntry(
    category: '番型速查',
    name: '杠上炮',
    multiplier: '×2',
    desc: '杠牌后打出的牌造成其他玩家点炮胡牌（胡牌方计杠上炮 ×2）。',
    exampleNote: '他人开杠后打出的牌正好是你听的牌 → 你胡牌即杠上炮 ×2',
  ),
  RuleEntry(
    category: '番型速查',
    name: '杠上开花',
    multiplier: '×2',
    desc: '杠牌后从牌墙补摸一张，恰好自摸胡牌。',
    note: '不计碰碰胡。',
    exampleTiles: [
      ExampleGroup([8, 8, 8, 8]),
    ],
    exampleNote: '开杠 9筒 后补摸一张恰好胡牌（必须自摸）',
  ),
  RuleEntry(
    category: '番型速查',
    name: '抢杠',
    multiplier: '×2',
    desc: '已碰刻子补杠时，被其他玩家抢杠胡牌（只能抢补杠，不能抢暗杠）。',
    exampleTiles: [
      ExampleGroup([11, 11, 11]),
      ExampleGroup([11], highlight: true), // 补杠的第 4 张
    ],
    exampleNote: '高亮的 3条 是他人补杠的那张，正好是你听的牌',
  ),
  RuleEntry(
    category: '番型速查',
    name: '小三元',
    multiplier: '×4',
    desc: '手牌中有中、发、白，其中 2 个为刻子，另 1 个为对子（作将）。',
    exampleTiles: [
      ExampleGroup([18, 18]),
      ExampleGroup([19, 19, 19]),
      ExampleGroup([20, 20, 20]),
      ExampleGroup([0, 1, 2]),
      ExampleGroup([12, 13, 14]),
    ],
    exampleNote: '中中 作将，发、白 为刻子',
  ),
  RuleEntry(
    category: '番型速查',
    name: '暗四归一',
    multiplier: '×4',
    desc: '某点数前 3 张在手，自摸到第 4 张胡牌（碰/杠出的不算）。',
    exampleTiles: [
      ExampleGroup([4, 4, 4]),
      ExampleGroup([4], highlight: true), // 自摸的第 4 张
    ],
    exampleNote: '高亮的 5筒 是自摸到的第 4 张',
  ),
  RuleEntry(
    category: '番型速查',
    name: '七对',
    multiplier: '×4',
    desc: '由 7 个对子组成的胡牌（需门清，碰/杠出后失效）。',
    note: '不计屁胡。',
    exampleTiles: [
      ExampleGroup([0, 0]),
      ExampleGroup([2, 2]),
      ExampleGroup([4, 4]),
      ExampleGroup([6, 6]),
      ExampleGroup([8, 8]),
      ExampleGroup([18, 18]),
      ExampleGroup([19, 19]),
    ],
  ),
  RuleEntry(
    category: '番型速查',
    name: '大三元',
    multiplier: '×8',
    desc: '手牌中中、发、白 3 个全为刻子。',
    note: '不计小三元。',
    exampleTiles: [
      ExampleGroup([18, 18, 18]),
      ExampleGroup([19, 19, 19]),
      ExampleGroup([20, 20, 20]),
      ExampleGroup([0, 1, 2]),
      ExampleGroup([13, 13]),
    ],
  ),
  RuleEntry(
    category: '番型速查',
    name: '龙七对',
    multiplier: '×16',
    desc: '七对中含 1 组 4 张同牌（"龙"必须握在手中，不能碰/杠出）。',
    note: '不计七对。',
    exampleTiles: [
      ExampleGroup([0, 0, 0, 0]),
      ExampleGroup([2, 2]),
      ExampleGroup([4, 4]),
      ExampleGroup([6, 6]),
      ExampleGroup([8, 8]),
      ExampleGroup([18, 18]),
    ],
    exampleNote: '1筒×4 握在手中算 2 个对子（一条"龙"）',
  ),
  RuleEntry(
    category: '番型速查',
    name: '三元七对',
    multiplier: '×16',
    desc: '七对中中、发、白均为对子。',
    note: '不计七对；与龙七对可叠加。',
    exampleTiles: [
      ExampleGroup([18, 18]),
      ExampleGroup([19, 19]),
      ExampleGroup([20, 20]),
      ExampleGroup([0, 0]),
      ExampleGroup([2, 2]),
      ExampleGroup([4, 4]),
      ExampleGroup([6, 6]),
    ],
  ),
  RuleEntry(
    category: '番型速查',
    name: '双龙七对',
    multiplier: '×32',
    desc: '七对中含 2 组 4 张同牌。',
    note: '不计七对、龙七对。',
    exampleTiles: [
      ExampleGroup([0, 0, 0, 0]),
      ExampleGroup([2, 2, 2, 2]),
      ExampleGroup([4, 4]),
      ExampleGroup([6, 6]),
      ExampleGroup([8, 8]),
    ],
  ),
  RuleEntry(
    category: '番型速查',
    name: '三龙七对',
    multiplier: '×64',
    desc: '七对中含 3 组 4 张同牌。',
    note: '不计七对、龙七对、双龙七对。',
    exampleTiles: [
      ExampleGroup([0, 0, 0, 0]),
      ExampleGroup([2, 2, 2, 2]),
      ExampleGroup([4, 4, 4, 4]),
      ExampleGroup([6, 6]),
    ],
  ),
];

/// 规则速查页：搜索（GlassInputField）→ 分组列表 → 点击弹出磨砂详情抽屉。
class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RuleEntry> get _filtered => _query.isEmpty
      ? _kRules
      : _kRules
          .where((r) =>
              r.name.contains(_query) ||
              r.desc.contains(_query) ||
              r.category.contains(_query) ||
              (r.exampleNote?.contains(_query) ?? false) ||
              (r.descItems?.any((i) => i.contains(_query)) ?? false))
          .toList();

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    final basics = entries.where((e) => e.category == '基础玩法').toList();
    final fans = entries.where((e) => e.category == '番型速查').toList();

    // 头部（标题 + 搜索框）固定，仅下方规则列表滚动 ——
    // 搜索框始终可达，长列表滚动时不需要回滚到顶部
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('规则速查', style: GlassTypography.display),
                const SizedBox(height: 3),
                Text('番型倍数与牌例 · 数据来自本地规则文档',
                    style: GlassTypography.caption),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: GlassInputField(
              controller: _searchCtrl,
              hint: '搜索番型或规则，如「七对」「杠」',
              prefixIcon: Icons.search_rounded,
              onChanged: (v) => setState(() => _query = v.trim()),
              onSubmitted: (v) => FocusScope.of(context).unfocus(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 118),
              children: [
                if (entries.isEmpty)
                  _emptyResult()
                else ...[
                  if (basics.isNotEmpty) ...[
                    _sectionTitle('基础玩法', GlassColors.iceBlue),
                    for (final e in basics) _ruleTile(e, GlassColors.iceBlue),
                    const SizedBox(height: 10),
                  ],
                  if (fans.isNotEmpty) ...[
                    _sectionTitle('番型速查', GlassColors.mint),
                    for (final e in fans) _ruleTile(e, GlassColors.mint),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyResult() {
    return GlassCard(
      frost: false,
      tintStrength: 0.45,
      shadow: false,
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 34, color: GlassColors.textTertiary),
          const SizedBox(height: 10),
          Text('没有匹配「$_query」的规则', style: GlassTypography.body),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: GlassLight.begin,
                end: GlassLight.end,
                colors: [accent.lighten(0.2), accent],
              ),
              borderRadius: BorderRadius.circular(GlassRadius.pill),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: GlassTypography.titleSm),
        ],
      ),
    );
  }

  Widget _ruleTile(RuleEntry e, Color accent) {
    return GlassCard(
      frost: false,
      tintStrength: 0.5,
      shadow: false,
      radius: 16,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(e, accent),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GlassColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(e.desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GlassTypography.caption),
                ],
              ),
            ),
            if (e.multiplier.isNotEmpty) ...[
              const SizedBox(width: 10),
              _multiplierBadge(e.multiplier, accent),
            ] else ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: GlassColors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }

  /// 倍数徽标：薄荷系对角渐变小凸起。
  Widget _multiplierBadge(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: GlassLight.begin,
          end: GlassLight.end,
          colors: [accent.lighten(0.24), accent.darken(0.08)],
        ),
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        boxShadow: GlassShadow.chip(accent),
      ),
      child: Text(text,
          style: const TextStyle(
              color: GlassColors.textOnAccent,
              fontSize: 12.5,
              fontWeight: FontWeight.w700)),
    );
  }

  void _openDetail(RuleEntry e, Color accent) {
    AppFeedback.tap();
    showGlassModalBottomSheet(
      context,
      title: e.name,
      accent: accent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (e.multiplier.isNotEmpty)
              Center(
                child: _multiplierBadge(
                    e.multiplier == '1' ? '基准番' : '${e.multiplier} 番', accent),
              ),
            const SizedBox(height: 12),
            if (e.descItems != null) _bulletList(e.descItems!) else
              Text(e.desc, style: GlassTypography.body),
            if (e.exampleTiles != null || e.exampleNote != null) ...[
              const SizedBox(height: 12),
              _exampleCard(e),
            ],
            if (e.note != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                frost: false,
                surfaceTint: GlassColors.warning,
                tintStrength: 0.14,
                shadow: false,
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: GlassColors.warningDeep),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.note!,
                          style: GlassTypography.caption.copyWith(
                              color: GlassColors.warningDeep,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 分条解释：每条一行 + 前置小圆点；条内"："前的词加粗。
  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 小圆点：与首行文字视觉居中对齐（body 14px 行高 1.55）
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: GlassColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _bulletText(items[i])),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bulletText(String item) {
    final idx = item.indexOf('：');
    if (idx <= 0 || idx > 8) return Text(item, style: GlassTypography.body);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: item.substring(0, idx + 1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: item.substring(idx + 1)),
        ],
      ),
      style: GlassTypography.body,
    );
  }

  /// 牌例卡：薄荷染色薄玻璃，牌面图片展示（段间以间隔分隔，关键段高亮）。
  Widget _exampleCard(RuleEntry e) {
    return GlassCard(
      frost: false,
      surfaceTint: GlassColors.mint,
      tintStrength: 0.13,
      shadow: false,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style_rounded,
                  size: 15, color: GlassColors.mintDeep),
              const SizedBox(width: 6),
              Text('牌例',
                  style: GlassTypography.caption.copyWith(
                      color: GlassColors.mintDeep,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (e.exampleTiles != null) ...[
            const SizedBox(height: 8),
            // 段与段之间用间隔分隔（替代文字版牌例的"+"号）
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final g in e.exampleTiles!) _exampleGroup(g),
              ],
            ),
          ],
          if (e.exampleNote != null) ...[
            const SizedBox(height: 8),
            Text(e.exampleNote!, style: GlassTypography.caption),
          ],
        ],
      ),
    );
  }

  /// 牌例段：组内小牌紧挨，关键段加薄荷描边与"胡"角标。
  Widget _exampleGroup(ExampleGroup g) {
    final group = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (final t in g.tiles) MiniTile(tile: t, width: 24),
      ],
    );
    if (!g.highlight) return group;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            border: Border.all(
                color: GlassColors.mint.withValues(alpha: 0.85), width: 1.6),
            borderRadius: BorderRadius.circular(7),
          ),
          child: group,
        ),
        Positioned(
          top: -7,
          right: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: GlassLight.begin,
                end: GlassLight.end,
                colors: [
                  GlassColors.mint.lighten(0.22),
                  GlassColors.mint.darken(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(GlassRadius.pill),
              boxShadow: GlassShadow.chip(GlassColors.mint),
            ),
            child: const Text('胡',
                style: TextStyle(
                    color: GlassColors.textOnAccent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
