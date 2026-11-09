# OpenRA 本地化（l10n）路线图

> 状态：**草案 v1** ｜ 编写日期：2026-11-04 ｜ 维护：本仓库维护者
> 本文档记录**评估结论与待办事项**。它不代表上游 OpenRA 或汉化组已承诺参与或接受。

## 摘要（English summary for upstream / partners）

This document records an evaluation of adding first-class localization support to the
OpenRA engine, and the work items required to get there.

**Current state (verified by reading `OpenRA/OpenRA` @ `bleed`):** OpenRA already uses a
key-based text system — strings live in Fluent `.ftl` files, referenced by key from code and
chrome layouts. What is missing is the *language dimension*: `Manifest.FluentCulture` is
hardcoded to `"en"` (with an upstream `TODO` acknowledging this), there is no language
setting, a missing key renders the raw key instead of falling back to English, and
`WidgetUtils.WrapText` only breaks lines at ASCII spaces — which never fires for Chinese.

**Goal:** reach the ergonomics of a modern i18n layer — runtime language switching, per-key
fallback to a base language, and correct CJK text layout — without depending on upstream
accepting the change.

**Rough sizing:** a usable core (P0 + P1) is roughly 9–15 person-days; the full experience
(P2) roughly 13–22. The reference implementation to measure against is the Han localization
group's engine fork (`CastleJing/ca_engine`, branch `ca-engine/1.09`), whose diff touches six
engine files plus one new type.

**Sequencing matters more than volume:** a one-page design note that a knowledgeable OpenRA
developer reviews in 15 minutes is worth far more than a large unreviewed patch.

---

## 一、目标

让 OpenRA 的中文本地化从「覆盖文本补丁」演进为「引擎内置语言支持」，达到 OpenSave 项目的使用体验：

- 玩家可在设置中切换语言，改动即时生效；
- 缺键回退到基准语言，而不是把 key 显示在界面上；
- 中文排版正确（断行、行高、字重），无需手工插入换行符；
- 语言资源与引擎解耦，更新引擎时不丢失译文。

## 二、现状核查

以下结论均来自对 `OpenRA/OpenRA`（`bleed` 分支）源码的直接阅读，非推测。

| 事实 | 出处 |
|---|---|
| 文本体现在是 Fluent `.ftl`，按 mod 分散加载 | `mods/ra/mod.yaml` 的 `FluentMessages:` 段 |
| 语言文化硬编码为 `en`，上游自留 TODO | `OpenRA.Game/Manifest.cs`：`// TODO: This should be controlled by a user-selected translation bundle!` |
| 设置中无语言选项 | `OpenRA.Game/Settings.cs`（`GameSettings` 无 `Language` 字段） |
| 查找失败返回 key 本身，不回退英文 | `FluentProvider.GetMessage` → `FluentBundle.GetMessage` 中 `message = key` |
| 断行只认 ASCII 空格，中文整段不切 | `OpenRA.Mods.Common/Widgets/WidgetUtils.cs` 的 `WrapText` |
| 换行默认关闭 | `LabelWidget.WordWrap = false` |
| 地图可携带自己的 Fluent 文本 | `Map.FluentMessageDefinitions`（map.yaml 内 base64） |
| 上游已公告「未来版本将支持本地化」 | 官方 playtest-20260222 说明 |

**结论**：OpenRA 已有完整的「抽 key」体系，缺的是「语言维度」「回退语义」「排版适配」三件事。

## 三、参考实现对照

汉化组在 `CastleJing/ca_engine`（分支 `ca-engine/1.09`）已实现一套完整方案，其改动面是我们估算工程量的基准。

**引擎侧（6 个文件 + 1 个新类型）**

| 文件 | 改动 |
|---|---|
| `OpenRA.Game/Manifest.cs` | 新增 `LocalizationPackageSections`、`GlyphPrecache`、`Translations`/`SupportLanguages`、`LanguageFontPaths`；新增 `TryResolveLanguageFontPath`、`RegisterFontsFromLanguageFileIfMissing`、`LoadCustomData` |
| `OpenRA.Game/ModData.cs` | 新增 `languages[]`、`localizationMountedPackages`、`RemountLocalizationPackages()`；启动时加载译文与按语言字体 |
| `OpenRA.Game/Settings.cs` | `PlayerSettings.Language = "en"`（BCP-47） |
| `OpenRA.Game/Game.cs` | `Translation` 静态字段、`LoadTranslation`、`Translate`、`TranslationContain`、`SwitchLanguage`、`ApplySystemLanguageOnFirstLaunch`、`UiTranslationGeneration` |
| `OpenRA.Game/FileSystem/FileSystem.cs` | 新增 `TryMountLocalizationPackage`、`Unmount`、`UnmountAll`（原版只能挂不能卸） |
| `OpenRA.Mods.Common/Widgets/WidgetUtils.cs` | `WrapText` 按语言分流，CJK 逐字断行 |
| `OpenRA.Support.Translation`（新类） | 译文表加载与查找 |

**数据侧**：`localization.yaml`、`languages/*.json5`（en/zh 各 7 个）、`fonts/{en,zh}.yaml`、`glyph-precache.txt`、字体文件。

> 注意：`localization.yaml` 与 `languages/` 目录并非 Combined Arms 原生内容，而是汉化组在
> 2026-08 的提交中新增（commit `eeff48d8`、`e598e20e`），并同步更新了 `ENGINE_VERSION`。
> 也就是说，这套机制本身就是「改引擎装架子」路线的产物，不是可直接套用到官方三模组的现成方案。

## 四、路线评估

| 路线 | 收益 | 代价 | 判断 |
|---|---|---|---|
| **A. 维持文本覆盖** | 跟官方版本走，零构建成本 | 无语言切换、无正确排版 | ✅ 现状，继续维护 |
| **B. 外挂独立 mod** | 不改引擎 | `RequiresMods` 仅是依赖检查，不构成继承；文本层无法注入基础 mod | ❌ 不可行 |
| **C. 上游 PR 提交** | 一劳永逸 | 汉化组 2020–21 的 JSON 方案被上游否决；维护者少、评审严 | ⚠️ 低概率，不作为主路径 |
| **D. 自建引擎分支** | 完整本地化体验 | 需长期跟随上游版本 rebase | 🎯 唯一被验证的完整路径 |

**当前决策**：以 **A 为交付主线**（持续维护补丁），以 **D 为探索方向**（与汉化组合作，不自行 fork 引擎），**C 仅作为可选提案**。

## 五、分阶段任务清单

### P0 — 排版修复（不依赖语言系统，对英文亦无害）

| 编号 | 任务 | 验收标准 | 估算（人日） |
|---|---|---|---|
| P0-1 | 重写 `WrapText`：引入「断行机会」判定，CJK 逐字可断、空格优先、长词兜底硬切 | 中英混排样例断行位置符合预期；英文原有行为不变 | 1–2 |
| P0-2 | 补充中文禁则（`，。、；：）` 不落行首，`（「` 不留行尾） | 标点位置断言测试通过 | 0.5–1 |
| P0-3 | 单元测试 + 前后行为对比样例 | 测试可运行，附 before/after 输出 | 0.5–1 |

**P0 验收样例**（固定宽度下应满足）：

| 输入 | 期望 |
|---|---|
| `建造基地` | 单行放得下则不换行；放不下则逐字断行，无空格参与 |
| `建造基地需要电力` | 断点落在任意两字之间，不出现行首空格 |
| `建造基地，需要电力。` | `，` `。` 不出现在行首 |
| `（建造基地）` | `）` 不出现在行首，`（` 不留在行尾 |
| `Build base now` | 断行仍发生在空格处，与改动前一致 |
| `Supercalifragilisticexpialidocious` | 超长单词不再溢出，按宽度硬切 |
| `建造基地 Build base` | 空格优先（拉丁词整体不拆），中文部分可断 |

### P1 — 语言内核（自建分支路线的前置）

| 编号 | 任务 | 验收标准 | 估算（人日） |
|---|---|---|---|
| P1-1 | `Translation` 类：加载译文表、按 key 查询、支持占位符 | 单元测试覆盖 | 2–3 |
| P1-2 | `Game.Translate` 取代直接调用 `FluentProvider` | 全量替换且行为等价 | 1–2 |
| P1-3 | `Settings.Player.Language` + 设置页语言下拉 | 切换后持久化 | 1–2 |
| P1-4 | `FileSystem` 挂载/卸载 + `ModData.RemountLocalizationPackages()` | 切换语言后资源正确替换 | 2–3 |
| P1-5 | 缓存失效机制（`CachedTransform` 全链路） | 切换后界面无旧文本残留 | 2–3 |

### P2 — 体验完善

| 编号 | 任务 | 验收标准 | 估算（人日） |
|---|---|---|---|
| P2-1 | 按语言字体 + 中文行高/字距调校 | 四档 UI 缩放下观感正常 | 2–4 |
| P2-2 | 字形预热（消除首次打开界面卡顿） | 首开无明显卡顿 | 1–2 |
| P2-3 | 缺键回退基准语言 | 未翻译键显示英文原文而非 key | 1–2 |
| P2-4 | 地图级译文与录像兼容 | 旧录像可回放 | 2–3 |

**核心合计**：P0 约 2–4 人日；P0+P1 约 9–15 人日；全量约 13–22 人日（估算，含返工；不含控件逐个适配的时间黑洞）。

## 六、协作与评审流程

采用三闸口，避免先写后推翻：

| 闸口 | 交付物 | 把关人 | 时长 | 目的 |
|---|---|---|---|---|
| ① 设计 | 改动清单：文件、理由、风险、兼容影响 | 懂 OpenRA 的开发者 | 10–15 分钟 | 防止方向性错误 |
| ② 实现 | 可编译分支 + 单元测试 + 前后对比 | CI 自动 | — | 防止实现错误 |
| ③ 验收 | 真机截图、联机一局、录像回放 | 玩家/开发者 | 30 分钟 | 防止「代码对但游戏坏」 |

原则：闸口①必须先于编码，且交付物须在 15 分钟内可读完。

## 七、风险登记

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 上游不接受 | 高 | 汉化组同类方案曾被否决 | 不把上游作为主路径 |
| 控件布局适配无底洞 | 高 | 中文宽度与英文差异大，需逐个控件调整 | 排入 P2，按 UI 模块分批 |
| 联机文本一致性 | 中 | 服务器下发的是 key 还是已翻译文本，影响协议 | 闸口①必须给出结论 |
| 引擎版本跟随 | 中 | 自建分支需持续 rebase | 与 A 主线并行，不互相阻塞 |
| 排版观感主观 | 低 | 中文行高与 FreeSans 不同 | 已在现有补丁中随包字体缓解 |

## 八、未决问题

1. **联机协议**：服务器广播的是消息 key 还是客户端本地化后的文本？需实测确认。
2. **语言资源分发形态**：随 mod 内置、随引擎、还是独立包？三种对升级成本影响不同。
3. **术语表归属**：单位/建筑译名以汉化组 RASC/TDSC 为准的既有约定如何长期维护。
4. **合作形式**：与汉化组是「互相参考」还是「共用一套实现」，需与对方确认。

## 九、附录：关键文件索引

| 用途 | 路径 |
|---|---|
| 断行实现 | `OpenRA.Mods.Common/Widgets/WidgetUtils.cs` → `WrapText` |
| 字体度量 | `OpenRA.Game/Graphics/SpriteFont.cs` → `Measure` / `DrawText` |
| 文案加载 | `OpenRA.Game/FluentProvider.cs` |
| 文案容器 | `OpenRA.Game/FluentBundle.cs` |
| manifest | `OpenRA.Game/Manifest.cs` |
| 设置 | `OpenRA.Game/Settings.cs` |
| 文件系统 | `OpenRA.Game/FileSystem/FileSystem.cs` |
| 参考实现 | `gitee.com/CastleJing/ca_engine`（分支 `ca-engine/1.09`） |

## 十、变更记录

| 日期 | 变更 |
|---|---|
| 2026-11-04 | 初稿：现状核查、参考实现对照、四条路线评估、P0/P1/P2 任务清单、三闸口流程、风险与未决问题 |
