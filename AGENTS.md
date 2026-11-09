# AGENTS.md — 本仓库的 AI 协作入口

> 这是**目录**，不是手册。规则正文在 `docs/` 与外部规范族里，靠链接到达。
> 本文件行数上限 **150 行**；超限即视为「把正文搬进来」，必须拆到独立文档再改为链接。

## 1. 项目一句话

OpenRA（`playtest-20261026`）的简体中文文本补丁：只替换 Fluent 文案与字体，不改地图、不改引擎。

## 2. 强制命令（唯一验收入口）

| 用途 | 命令 | 通过判据 |
|---|---|---|
| 全量校验 | `pwsh -NoLogo -NoProfile -File scripts/verify.ps1` | 退出码 0 |
| 提交前快速校验 | `pwsh -NoLogo -NoProfile -File scripts/verify.ps1 -Fast` | 退出码 0 |
| 重建载荷清单 | `python tools/build_manifest.py` | `src/manifest.json` 的差异可逐条解释 |
| 打包 | `python tools/build_release.py` | 生成 `dist/*.zip` 且自校验通过 |
| 安装 Git 钩子 | `pwsh -NoLogo -NoProfile -File scripts/install-hooks.ps1` | `git config core.hooksPath` = `.githooks` |

Windows 侧脚本一律 **PowerShell 7.4+（`pwsh`）**，禁止 `cmd`、`.bat`、`.cmd`。

## 3. 禁止清单

- 🚫 修改 `files/**/map.yaml`：地图 UID 会变，联机哈希与旧录像失效
- 🚫 修改引擎 `.dll`、美术、音频：补丁只允许文本与字体
- 🚫 往 `files/` 放字体：字体只在 `fonts/`，由安装器部署
- 🚫 手写 `src/安装说明.txt`：它是 `tools/build_install_txt.py` 的生成物
- 🚫 手改 `src/manifest.json` 的哈希：用 `tools/build_manifest.py` 重算
- 🚫 新增 `.bat` / `.cmd`（含临时脚本）
- 🚫 未跑 `verify` 就声称「已完成」；把校验失败说成「环境问题」而不复现
- 🚫 破坏性 Git 操作：`reset --hard`、`push --force`、修改已发布 tag

## 4. 版本号

**SemVer 2.0.0**，规则见 [`docs/VERSIONING.md`](docs/VERSIONING.md)。
**单一真相**：`src/manifest.json` 的 `version` 字段；`docs/CHANGELOG.md` 顶层标题与 `src/安装说明.md` 首行由校验脚本比对，三者必须一致。

- 公开接口 = 发布包结构（zip 布局、`manifest.json` schema、`setup.ps1` 参数）
- 破坏接口 → 主版本；新增能力（新覆盖模块、新参数、适配新引擎）→ 次版本；译文/文案修正 → 修订号
- 已发布版本不得修改，tag 一旦推送不改；发错就发新版本

## 5. 歧义处理协议

**必须停下询问**（构造 2–4 个具体选项，并说明「不裁决我会怎么做」）：

1. 会影响地图 UID、引擎文件或联机兼容性的改动
2. 需要改发布包结构或 `setup.ps1` 参数语义
3. 同一条译文存在两种都说得通的译法，且影响术语表一致性
4. 规范条款之间冲突，或与上游 OpenRA 行为冲突
5. 删除公开文档章节 / 删除已发布能力

**不允许询问**（先自查）：目录里已有的实现、`docs/` 已写明的约定、`tools/` 已有脚本能给出的答案、能通过 `git log` 查明的事实。

## 6. 先搜寻，后自研

写任何新脚本前，按序检索：`tools/` 现有脚本 → 上游 OpenRA 仓库 → 公开包注册表。自研须在 `DECISIONS.md` 留一条，写明检索过的渠道与关键词。
引入第三方二进制/源码前，先在 [`MANIFEST.md`](MANIFEST.md) 登记来源、版本、SHA256 与**许可结论**；结论为空不算登记。

## 7. 校验冗余 vs 代码冗余

- **校验冗余**：同一缺陷至少两条独立拦截路径（本地钩子 / CI / 运行期），**只能增加不能削减**，不得因为「本地跑过了」让 CI 跳过任何一项。
- **代码冗余**：重复实现、死脚本、过期文档，按迭代末或每两周定期清理，产出独立的 `chore:` 提交。

## 8. 交付闭环

1. 改文档（若涉及行为/约定）→ 改代码 → `verify.ps1 -Fast`
2. 提交：Conventional Commits（`feat|fix|docs|refactor|perf|test|build|ci|chore|revert`），中文正文可
3. 单提交尽量 ≤ 400 行；一个提交只做一件事
4. 全量 `verify.ps1` 通过后再推送；推送后确认 CI 绿

## 9. 文档地图

| 想知道 | 去哪 |
|---|---|
| 仓库里每个文件是什么 | [`docs/ANATOMY.md`](docs/ANATOMY.md) |
| 怎么重建载荷、怎么发版 | [`docs/MAINTAINING.md`](docs/MAINTAINING.md) |
| 怎么改一句译文 | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| 版本号规则与发版清单 | [`docs/VERSIONING.md`](docs/VERSIONING.md) |
| 规范条款在本仓库如何落地 | [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) |
| 每个版本改了什么 | [`docs/CHANGELOG.md`](docs/CHANGELOG.md) |
| 决策记录 / 任务队列 / 第三方来源 | [`DECISIONS.md`](DECISIONS.md) · [`TASKS.md`](TASKS.md) · [`MANIFEST.md`](MANIFEST.md) |

> 规范族（《用 AI 做项目》七份）由维护者在仓库外持有；本仓库只通过
> [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) 的条款映射引用它，不复制正文。
