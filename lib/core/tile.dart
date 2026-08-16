/// 牌种编码与工具。
///
/// 牌种编码 t ∈ [0, 20]：
///   0..8  = 1..9 筒（TONG）
///   9..17 = 1..9 条（TIAO）
///   18 = 中, 19 = 发, 20 = 白（ZI）
library;

const int kTileKindCount = 21;

/// 全部牌种，按 筒 → 条 → 字 顺序（稳定排序用）。
const List<int> kAllTiles = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, //
  9, 10, 11, 12, 13, 14, 15, 16, 17, //
  18, 19, 20,
];

const List<int> kTongTiles = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const List<int> kTiaoTiles = [9, 10, 11, 12, 13, 14, 15, 16, 17];
const List<int> kHonorTiles = [18, 19, 20];

/// 五筒（"五星"），卡五星番型的关键牌。
const int kWuXing = 4;

bool isHonor(int t) => t >= 18;

/// 牌面显示名：如 "5筒"、"1条"、"中"。
String tileName(int t) {
  if (t <= 8) return '${t + 1}筒';
  if (t <= 17) return '${t - 8}条';
  return const ['中', '发', '白'][t - 18];
}

/// 牌面图片资源路径（assets/tiles/，含 2.0x/3.0x 变体）。
String tileAsset(int t) {
  if (t <= 8) return 'assets/tiles/tong_${t + 1}.png';
  if (t <= 17) return 'assets/tiles/tiao_${t - 8}.png';
  return 'assets/tiles/${const ['zhong', 'fa', 'bai'][t - 18]}.png';
}

/// 图案显示缩放：切图"尺寸=图案尺寸"，宽高比各异的图案 contain 到
/// 统一内容框后视觉大小略有差异（如"发"为近方形 1.03，比瘦长字牌显小），
/// 此表按牌种微调放大倍数，其余为 1.0。
double tilePatternScale(int t) {
  if (t == 19) return 1.22; // 发（发财）：近方形 → 放大补齐视觉重量
  return 1.0;
}
