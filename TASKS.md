# 任务队列（TASKS）

> 字段：编号 · 提出时间 · 状态 · 问题 · 方法 · 完成判据（命令 + 期望退出码）。
> **已决条目不得删除**（保留可追溯）；状态取值：`待裁决` / `待办` / `进行中` / `阻塞` / `已完成`。
> 交付说明末尾必须附「当前未决议清单」；无则写「当前无待裁决项」。

### T-001 · 2026-11-09 · 待裁决 · 战役难度禁用态的占位文案

- **问题**：无难度选项的任务（`allies-01`、`allies-10b`、`soviet-01/02a/02b` 等）里，难度下拉被禁用，但仍显示控件默认文案「普通」，玩家误以为「有难度却点不动」。英文原版同样显示灰色 `Normal`，属上游行为。
- **方法**：把 `label-missionbrowser-normal-difficulty` 的译文改为「不可用」，同时改 `files/mods/common/fluent/chrome.ftl` 与 `files/mods/cnc/fluent/chrome.ftl`，再重建 `manifest.json`。
- **裁决选项**：A 改译文为「不可用」；B 保持现状，仅在 README/FAQ 说明；C 改译文为「—」。
- **完成判据**：`pwsh -File scripts/verify.ps1` 退出码 0，且 `docs/CHANGELOG.md` 有对应条目。

### T-002 · 2026-11-09 · 阻塞 · 向 OpenRA 上游提交崩溃报告

- **问题**：`playtest-20261026` 在战役界面调用后台线程测量中文文本，触发 `Sheet.GetTexture()` 的可空竞态崩溃（详见本地分析）。需要以 issue 形式反馈上游，并表达中文汉化贡献意愿。
- **方法**：正文已备好（`桌面\OpenRA_CN_patch\openra-issue-body.md`）；待 GitHub 授权后以 API 提交。
- **阻塞原因**：本机 `gh` 令牌失效，设备码流程在非交互环境被中断。
- **完成判据**：`gh issue view <URL> --json number` 退出码 0（issue 可读），把编号回填到本条。

### T-003 · 2026-11-09 · 待办 · 评估接入 markdownlint

- **问题**：当前 Markdown 只校验链接与锚点，无格式规则（标题层级、列表缩进、行宽）。
- **方法**：引入 `markdownlint-cli2` 与 `.markdownlint-cli2.jsonc`，对现有 12 份 md 做一次基线；规则冲突的条目写进配置豁免并注明理由。
- **完成判据**：`npx markdownlint-cli2 "**/*.md"` 退出码 0，且已接入 `scripts/verify.ps1`。

### T-004 · 2026-11-09 · 待办 · 恢复 `.ps1` 的双击体验

- **问题**：Windows 双击 `.ps1` 默认用记事本打开，玩家必须先右键「使用 PowerShell 运行」。
- **方法**：候选方案 A：包内提供 `.lnk` 垫片；B：单文件 exe 启动器（需代码签名预算）；C：随包放一份 `双击安装.md` 图文。先做 C，A/B 待评估。
- **完成判据**：发布包内存在所选产物，且 `python tools/build_release.py --verify` 退出码 0。

### T-005 · 2026-11-09 · 阻塞 · 适配下一个 OpenRA playtest

- **问题**：当前只适配 `playtest-20261026`；上游发新 playtest 后键集合会变动。
- **方法**：按 `docs/MAINTAINING.md` 的「引擎升级」流程，从上游 tag 稀疏取英文基线，生成底稿与差异报告，补译后重建载荷。
- **阻塞原因**：等待上游发布。
- **完成判据**：`python tools/verify_manifest.py` 与 `python tools/check_yaml_fluent_refs.py` 退出码 0，`src/manifest.json` 的 `engineVersion` 已更新。

### T-006 · 2026-11-09 · 待办 · 术语表统一校对

- **问题**：单位/建筑名对齐 RASC/TDSC 的口径尚未固化成表，新增译文靠人工记忆。
- **方法**：以 `docs/archive/rasc-ref/` 为输入，产出 `docs/GLOSSARY.md`（英文 → 简中 → 出处），并在 `CONTRIBUTING.md` 引用。
- **完成判据**：`docs/GLOSSARY.md` 存在且 `pwsh -File scripts/check-docs.ps1` 退出码 0。

---

**当前未决议清单**：T-001（需在 A/B/C 中裁决）。
