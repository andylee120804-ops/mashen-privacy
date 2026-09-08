# 道具素材（props/）

祈福流程动画用的道具 PNG，与 `deities/` 同款画风（Q版 chibi 国风，Pollinations FLUX 生成 + rembg 抠透明背景）。

## 素材清单

| 文件 | 用途 | 生成尺寸 | seed |
|------|------|----------|------|
| worshipper_bow1.png | 磕头帧1：站立（背面跪姿） | 512×512 | 211 |
| worshipper_bow2.png | 磕头帧2：半弯腰（背面45°） | 512×512 | 212 |
| worshipper_bow3.png | 磕头帧3：伏地叩首（背面全趴） | 512×512 | 213 |
| incense_burner.png | 香炉（含三炷点燃的香） | 512×448 | 202 |
| muyu.png | 电子木鱼（点击敲击主体 + 入口图标） | 512×512 | 程序化渲染「方案2 寺庙描金」，见下 |
| qiu_art.png | 求签页签筒画面素材（用户参考图抠透明底直用） | 272×483 | 抠图，非 AI，见下 |

## 生成流程

```bash
# 1. 文生图（输出 .jpg 到 props/）
node scripts/gen-props.mjs

# 2. 抠透明背景（输出 .png）
python scripts/remove-bg-props.py
```

- rembg 首次运行会下载 u2net 模型（~176MB）到 `~/.u2net/`。
- 单独生成某张：`node scripts/gen-props.mjs worshipper_bow1`。
- 3 帧磕头序列由 WorshipperView 按 bowProgress 切帧播放。

## muyu.png（程序化渲染，非 AI 生成）

用户提供参考轮廓（黑底白线条木鱼，`scripts/屏幕截图 2026-09-02 231551.png`），
由 `scripts/render-muyu-variants.py` 提取剪影后参数化上色（v1 童趣 / v2 寺庙描金 / v3 琥珀轻木），
线上采用「方案 2 寺庙描金」。调整配色/描边/金缘/鳞弧后重跑脚本即可再出方案。

## qiu_art.png（用户参考图抠图直用，非 AI 生成）

求签页签筒舞台画面 = 用户提供的参考图本体
（`scripts/屏幕截图 2026-09-02 234642.png`，白底红金签筒插画），
由 `scripts/remove-bg-qiu-ref.py` 四边洪水填充 + 边缘抗锯齿抠成透明 PNG。
QiuQian 页以 `Image($rawfile('props/qiu_art.png'))` 整图展示，动画（俯身/摇摆/出签）做在整图上。
换图：替换源截图后重跑 `python scripts/remove-bg-qiu-ref.py` 并覆盖本文件（保持 272×483 比例即可）。

## 画风约束

- 与财神一致：Q-version chibi cartoon Chinese style, big head small body, vibrant saturated colors, digital painting。
- 米色纯背景（便于 rembg 抠图）。
- 改 seed 可重抽风格，但同一素材固定 seed 保证可复现。
