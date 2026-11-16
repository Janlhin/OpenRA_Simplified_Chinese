# 工程校验自查表（COMPLIANCE）

本仓库是**纯文本载荷 + PowerShell/Python 工具链**的项目：与前端工程绑定的检查项
（TS / ESLint / Stylelint / Vitest 等）在这里不适用，表中以 ➖ 标注并写明理由。

本文件回答三个问题：每条工程约束**落在哪个文件**、**由哪条命令拦住**、**还有哪些没做**。

状态取值：✅ 已落地 · 🔜 待办（见 `TASKS.md`）· ➖ 不适用（附理由）

## 1. 文档层

| 条款 | 状态 | 落地位置 | 校验 |
|---|---|---|---|
| 五个文档齐全（`README` / `AGENTS` / `DECISIONS` / `TASKS` / `MANIFEST`） | ✅ | 仓库根目录 | `scripts/check-docs.ps1` |
| `AGENTS.md` ≤150 行、只放目录与入口 | ✅ | `AGENTS.md` | 同上（行数硬校验） |
| 规则单一载体（不得有第二份规则副本） | ✅ | 仅 `AGENTS.md`；无 `.cursorrules` / `CLAUDE.md` | `scripts/check-docs.ps1` |
| 文档格式全 `.md`，不得同名 `.adoc` 并存 | ✅ | 全部文档 | 同上 |
| 文档内部锚点与外链可达 | ✅ | 全部 `.md` | `python tools/check_links.py .` |
| 删改必须说明理由（新增/修改/删除） | ✅ | 提交信息约定 + `DECISIONS.md` | 人工审查（无自动判据） |
| 文档只增不减 → 定期清理 | ✅ | 每两周或迭代末一次深度清理，产出独立 `chore:` 提交 | `TASKS.md` T-009；`check-docs.ps1` 对超阈值文档告警 |
| 命令片段由 CI 实跑（`codedown`） | ➖ | 本仓库命令片段集中在 `AGENTS.md` 表格与 `README`，已由 CI 直接执行同一条命令，无需再从 Markdown 抽取 | — |

## 2. 校验链（L1–L2）

| 条款 | 状态 | 落地位置 | 校验 |
|---|---|---|---|
| 版本控制 + 分支保护 | ✅ | Git / `main` | 仓库设置 |
| 静态检查、可机器判定的格式规则 | ✅ | `tools/lint_ftl.py`、`tools/struct_check_maps.py` | `scripts/verify.ps1` |
| 载荷与清单逐字节一致 | ✅ | `tools/verify_manifest.py` | 同上 |
| 生成物不得手写（`安装说明.txt`、README 附录） | ✅ | `tools/build_install_txt.py --check`、`build_readme_inventory.py --check` | 同上 |
| 资源覆盖（每个汉字都有字形） | ✅ | `tools/check_font_coverage.py` | 同上（全量模式） |
| 发布包自校验 | ✅ | `tools/build_release.py --verify` | 同上（全量模式） |
| 单一验收入口 | ✅ | `scripts/verify.ps1` | 本地钩子与 CI 都只调它 |
| 校验「快 → 慢」排序 | ✅ | `-Fast` 跳过字形覆盖与打包校验 | `scripts/verify.ps1 -Fast` |
| TypeScript `strict` / ESLint / Prettier / Stylelint / Vitest | ➖ | 本仓库无 TS/JS 源码，脚本为 PowerShell + Python | — |
| 前端运行时 schema 校验（Zod） | ➖ | 无 Web 运行时；外部输入边界是游戏文件，已由 `verify_manifest.py` 与安装器校验覆盖 | — |
| `knip` / `jscpd` 依赖与重复代码检查 | ➖ | 无 npm 依赖树；死脚本由定期清理节点处理 | — |

## 3. 脚本执行基线

| 条款 | 状态 | 落地位置 | 校验 |
|---|---|---|---|
| 禁止 `cmd` / `.bat`，统一 `pwsh` | ✅ | `AGENTS.md` §2、`src/setup.ps1` | `scripts/check-scripts.ps1` + CI |
| 仓库内 `.bat` / `.cmd` 数量为 0 | ✅ | 同上 | 同上 |
| 发布包内现场生成的纯 CMD 入口 | ➖ 已登记豁免 | 玩家侧存在没有 PowerShell 的机器，双击即装是真实需求（D-010 / D-011）；仓库本身仍零 `.bat` / `.cmd`，模板纯 ASCII、不调用 PS 宿主、只进 zip 不入库 | `scripts/check-scripts.ps1`（模板数 = 3、纯 ASCII、无 PS 宿主、哈希同源）+ `tools/build_release.py --verify` |
| 脚本语法与编码基线 | ✅ | 全部 `.ps1` 以 PowerShell AST 解析；`.ps1` 统一 CRLF（`.gitattributes`） | `scripts/check-scripts.ps1` |
| Git 钩子为 `pwsh` 薄壳 | ✅ | `.githooks/pre-commit`、`.githooks/commit-msg` | `scripts/install-hooks.ps1` |

## 4. 工作方式

| 条款 | 状态 | 落地位置 |
|---|---|---|
| 文档先行（先改文档再改代码） | ✅ | `AGENTS.md` §8；`DECISIONS.md` 记录设计与否决项 |
| 原子化（可独立解释 / 回滚 / 校验） | ✅ | 提交规范 + `commit-msg` 钩子提示规模 |
| 歧义必须询问（8 种情形 → 本项目 5 种） | ✅ | `AGENTS.md` §5 |
| 先搜寻后自研 + 引入前评估 | ✅ | `AGENTS.md` §6、`MANIFEST.md` |
| 校验后即提交，不积压 | ✅ | `AGENTS.md` §8 |
| 按时清理（增量 / 定期 / 阈值） | ✅ | 增量：发现即清；定期：`TASKS.md` T-009；阈值：`check-docs.ps1` 在单文档 > 400 行或 `docs/` > 25 份时告警，触发一次清理而不是抬高阈值（`CHANGELOG.md` 是只增的发布史，不参与行数阈值） |
| 借用与复制边界 | ✅ | `DECISIONS.md` D-001/D-003；术语只参考不复制 |

## 5. 版本与发布

| 条款 | 状态 | 落地位置 | 校验 |
|---|---|---|---|
| SemVer 2.0.0 正则与三处一致 | ✅ | `docs/VERSIONING.md` | `scripts/check-versions.ps1` |
| tag 与版本一致、tag 不改 | ✅ | 同上 | 同上（在 tag 上运行时校验） |
| 发布前七项检查（可复现 / 清单 / 签名 / 许可 / 敏感信息 / 扫描 / 说明与回滚） | ✅ | `scripts/pre-release.ps1`：七项一键执行，结论归档 `dist/pre-release-*.json`；扫描先查哈希再决定上传 | 退出码 0；签名项如实记为「未验证」（D-014） |
| CHANGELOG 含变更 / 已知问题 / 回滚 | ✅ | `docs/CHANGELOG.md` 模板 | `scripts/check-versions.ps1`（版本+日期） |
| 制品的 SHA256 与发布说明 | ✅ | Release 正文 | 发版清单第 7 步 |

## 6. 度量与豁免

| 条款 | 状态 | 说明 |
|---|---|---|
| 提交规模告警（>400 行提示拆分） | ✅ | `.githooks/commit-msg` |
| 校验覆盖率 / 误报率看板 | ➖ | 单人维护项目，采用「CI 全绿 + 发版清单」替代度量看板 |
| AI 代码审查通道 | ➖ | 未接入；接入前须完成历史 PR 回放测误报率（规范要求） |
| 豁免流程 | ✅ | 任何跳过校验的提交必须在 `DECISIONS.md` 新增条目说明理由与补救 |

## 7. 校验矩阵（缺陷类型 × 拦截层）

同一类缺陷至少要两条独立路径能拦住它——本地钩子漏了，CI 还有一次；CI 绿了，发布前自检还有一次。
`➖` 表示该层**不适合**拦这类缺陷（不是豁免）。任何一行出现「只有一个 ✔」，就要补一层，而不是删掉那一列。

| 缺陷类型 | 本地钩子（`pre-commit`） | CI | 发布前自检 | 运行期 / 人工 |
|---|---|---|---|---|
| 载荷与 `manifest.json` 不一致 | ✔ `verify_manifest.py` | ✔ | ✔ 依赖与许可项 | ✔ 安装器装完自校验 |
| Fluent 违规（BOM / CRLF / 括号）、译文键缺失 | ✔ `lint_ftl.py`、`struct_check_maps.py` | ✔ | ➖ | ➖ |
| 生成物被手改（`安装说明.txt`、README 附录） | ✔ `build_install_txt.py --check`、`build_readme_inventory.py --check` | ✔ | ➖ | ➖ |
| 版本号不一致、目录名 ≠ `engineVersion` | ✔ `check-versions.ps1` | ✔ | ✔ 变更说明与回滚项 | ✔ 打 tag 前复查 |
| 顶层出现未登记条目 / 缺必需目录 | ✔ `check-layout.ps1` | ✔ | ➖ | ➖ |
| 仓库出现 `.bat` / `.cmd`、脚本语法错 | ✔ `check-scripts.ps1` | ✔ | ➖ | ➖ |
| 发布包内 CMD 入口不合规（非纯 ASCII / 调用 PS 宿主 / 模板被增删） | ✔ `check-scripts.ps1` | ✔ | ✔ 制品可复现项（`build_release.py --verify`） | ➖ |
| 字体混进 `files/` | ✔ `check-scripts.ps1` | ✔ | ✔ 依赖与许可项 | ➖ |
| 敏感信息（密钥 / 令牌 / 内嵌凭据）入库 | ✔ `check-secrets.ps1` | ✔ | ✔ 敏感信息项 | ➖ |
| 治理文档缺字段、`.md`/`.adoc` 并存、出现第二份规则载体 | ✔ `check-docs.ps1` | ✔ | ➖ | ✔ 评审 diff |
| 文档断链、锚点失效 | ✔ `check_links.py` | ✔ | ➖ | ➖ |
| 提交信息不合规、单提交 > 400 行 | ✔ `commit-msg` 钩子 | ➖ | ➖ | ✔ 评审 diff |
| 制品不可复现、缺 SHA256、扫描结论未归档 | ➖ | ✔ CI 构建 | ✔ `pre-release.ps1` | ✔ Release 说明与 `MANIFEST.md` |

## 8. 复核方式

```bash
pwsh -NoLogo -NoProfile -File scripts/verify.ps1
```

退出码 0 表示上述 ✅ 项全部通过；➖ 项不产生检查；🔜 项见 `TASKS.md`。
