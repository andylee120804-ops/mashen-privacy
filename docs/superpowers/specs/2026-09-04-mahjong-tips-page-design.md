# 麻将技巧页（知识/教程入口）设计

> 2026-09-04 · HarmonyOS ArkTS · mashen-app
> 目标：新增「麻将技巧」知识/教程页，内容为通用打法的技巧与知识，可经「界面定制」开关为底部 Tab 或从「我的」页功能入口进入。

## 1. 需求与决策

用户确认的三个决策：

1. **玩法口径**：通用打法，不限定国标/川麻/广麻等地方规则 —— 只写所有打法通用的知识（牌张构成、基本牌型、动作术语、舍牌/搭子/防守/听牌效率原则、公认牌理口诀、心态），避开番种与和牌条件的分歧细节。
2. **页面结构**：百科式分区阅读（与财神百科 EncyclopediaPage 同款交互，已过审核验证）—— 顶部段内分区切换 → 卡片列表 → 点开详情覆层阅读。
3. **首版内容量**：精简版 4 分区 × 2~3 篇 ≈ 10 篇，每篇 100~200 字要点式；内容初稿由开发撰写后供用户审改。

## 2. 信息架构（4 分区 · 10 篇）

| 分区 | 篇目 | 内容口径 |
|---|---|---|
| 入门认知 | ① 一副麻将的构成 | 主牌 136 张：万/条/筒各 1-9 ×4 = 108；东南西北风 ×4 = 16；中发白 ×4 = 12。花牌与百搭按玩法另计 |
| 入门认知 | ② 胡牌基本型 | 顺子（同花色连续三张）、刻子（三张相同：碰/暗刻/杠）、将（对子）。胡牌 = 若干组（顺/刻）+ 一对将；特殊牌型（七对、十三幺等）按玩法存在 |
| 入门认知 | ③ 动作与术语表 | 摸/打/吃（上家）/碰（任意家）/杠（明杠/暗杠/加杠）、听牌、自摸、点炮/放炮、荒庄/流局 等通用术语 |
| 打法技巧 | ④ 单张去留 | 孤张早处理、字牌单张先走（靠不上牌的字牌价值低）、幺九/边张 vs 中张的价值差异 |
| 打法技巧 | ⑤ 搭子好形优先 | 两面搭（如 23、56）> 坎张搭（35、57）> 边张搭（12、89）；金三银七；保留进张数多的形 |
| 打法技巧 | ⑥ 拆搭与喂牌原则 | 拆熟不拆生、拆边留中；下家能吃/碰时避免喂牌；出牌顺序（先字牌后中张等常见次序） |
| 防守与听牌 | ⑦ 防守与读牌 | 跟熟张、看河/杠判断危险张、宁可不胡不点大炮；从出牌反推手牌（连续拆搭=换听、留字牌反常等） |
| 防守与听牌 | ⑧ 听牌效率与多面听 | 两面搭与对子叠连张的宽听；可胡张数优先，宽听不改窄听 |
| 口诀与心态 | ⑨ 常用牌理口诀 | 公认通用口诀（金三银七、打熟不打生、孤张字牌幺九先走、牌回头可留等） |
| 口诀与心态 | ⑩ 牌桌心态 | 不贪不赌、连输减速连赢别飘、长局保持注意力（不涉规则分歧） |

牌例一律用**汉字牌名**（如"二万 三万 四万 = 顺子"）标注；文章装饰图标用 🀄🀅 等已验证麻将字形或高频通用 emoji（🎯🎓🧘 等），**不用麻将字形作正文**（规避个别设备字形缺失成豆腐块的风险——即使个别装饰图标异常也不影响阅读）。

## 3. 数据模型（新文件 `entry/src/main/ets/model/MahjongTipsContent.ets`）

仿现有 `model/CultureContent.ets`，但详情内容改为**结构化块**（分点技巧比单段长文更易读）：

```ts
/** 详情内容块：h=小标题 p=段落 b=要点(渲染 ·) t=小贴士(金框) */
interface TipBlock { kind: 'h' | 'p' | 'b' | 't'; text: string }

interface TipsArticle {
  id: string      // 'a1'.. 稳定键，ForEach key
  icon: string    // 装饰 emoji（🀄 等已验证字形）
  title: string
  summary: string // 列表卡一行摘要
  blocks: TipBlock[]  // 有序
}

interface TipsSection {
  id: string        // 'basics' | 'play' | 'defense' | 'mindset'
  title: string     // 入门认知 / 打法技巧 / 防守与听牌 / 口诀与心态
  subtitle: string  // 分区头下一行小字说明
  articles: TipsArticle[]
}

export const TIPS_SECTIONS: TipsSection[] = [ ... ]  // 4 区静态内容
```

内容为纯静态常量，不涉及 VM / 持久化 / 网络。

## 4. 页面结构（新文件 `entry/src/main/ets/pages/MahjongTipsPage.ets`）

结构 = EncyclopediaPage 骨架复用，**不含新交互概念**：

- `@Prop standalone: boolean`（EntryShell 独立进入=true 带返回键；Tab 模式=false）
- 标题行：`💡 麻将技巧` 20sp 金粗体（standalone 时返回键并入、标题居中 —— PageBack 组件）
- 分区切换：Text 段内 Tab（选中金底 0.12 圆角胶囊，未选米色 0.5）—— 与百科 SectionTab 同款
- 当前分区：Scroll + 文章卡片列表
  - 卡片：装饰图标（24sp）+ 标题 15sp 粗米色 + 摘要一行 0.5 米色 + 「阅读 ›」
  - 卡片底 rgba(249,202,36,0.05)、1px rgba(249,202,36,0.12) 圆角 10 —— 与百科卡一致
- 详情覆层（页面内 Stack 覆层，非 CustomDialog）：
  - 遮罩 rgba(0,0,0,0.65) 点击关闭；面板 #241f12 金边圆角 16、宽 84%
  - 头部：图标 + 标题 18sp 金粗体
  - Scroll 高度按 blocks 数自适应 `clamp(280, 120 + blocks*30, 460)`（覆层 Scroll 需定高）
  - 逐块渲染：h → 12sp 金 0.8 粗体；p → 13sp 米色 0.85 lineHeight 21~23；b → 前导 "· " 同正文样式；t → 金 0.12 底、0.6 金 1px 边、内边距块
  - 底部金色「收下」按钮（#1a1a0a 深字）关闭
- 沉浸式：全屏背景 #1a1a0a、标题行 expandSafeArea TOP、内容底 padding 28

## 5. 接入改动（改 3 处小点 + 新页 1 个，无迁移）

1. `viewmodels/EntryConfigVM.ets`
   - `ENTRY_POOL` 末尾追加 `{ id: 'tips', icon: '💡', title: '麻将技巧' }`（💡 避免与祈福固定 Tab 的 🀄 撞形）
   - `DEFAULT_ITEMS` 追加 `{ id: 'tips', enabled: false, order: 8 }`（默认 off，走「我的」页功能入口）
   - 旧用户已存配置不含 tips → initialize 的"以池为准合并"自动取 DEFAULT 兜底，**无需迁移逻辑**
   - Tab 上限 MAX_TABS=3 不变；tips 可占一个 Tab 位
2. `pages/MainTabs.ets`：`EntryContent(id)` 加 `else if (id === 'tips') { MahjongTipsPage() }`
3. `pages/EntryShell.ets`：分发加 `else if (this.entryId === 'tips') { MahjongTipsPage({ standalone: true }) }`
4. `pages/MyPage.ets`、`pages/CustomizePage.ets`：**零改动** —— tips 走常规入口，自动出现在「功能入口」行与界面定制开关列表（非 gamerecord 特例）

## 6. 样式合规（WCAG）

沿用全 App 已过审深底配色，**不引入新色**：

- 卡片/列表：正文米色实色 #fdf6e3（≥4.5）、摘要/未选 Tab rgba(253,246,227,0.5)（深底 4.93）
- 详情覆层底 #241f12（比 #1a1a0a 亮，按弹窗底单独验证）：正文 rgba(253,246,227,0.85) ≥4.5 ✓；小标题 #f9ca24（#241f12 上 ≈6.9）✓；小贴士框正文同 0.85 米色 ✓
- 图标/标题 ≥18sp 或 14sp 粗 → ≥3:1 达标（金 #f9ca24 大字号）
- 无新增半透明低 alpha 文字、无靠 textShadow 的文字

## 7. 验证

- ArkTS 编译：`node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap`（PackageHap 缺 Java 失败属已知，看 CompileArkTS Finished 即可）
- 人工路径核对：界面定制开关 tips → 底部 Tab 出现并可切换；关闭后「我的」页功能入口出现 tips；EntryShell 独立进入可返回
- 对比度按 wcag-contrast 规则自查（见 §6）

## 8. 明确不做（YAGNI）

- 不做地区规则教程（川麻/广麻/国标番种表）
- 不做已读/收藏/进度持久化
- 不做麻将字形大图/手牌可视化（正文用汉字牌名）
- 不重构 EncyclopediaPage 共用覆层（本轮只新增页，未来如需三处以上可抽公共组件）
