# 规范落地矩阵（COMPLIANCE）

本仓库是**纯文本载荷 + PowerShell/Python 工具链**的项目，规范族中与前端工程绑定的条款不适用。
本文件把《用 AI 做项目：强制工程校验规范》（`AI_Engineering_Gate.adoc`，仓库外持有）的条款映射到本仓库的落地位置与校验方式。
条款锚点用规范原文的 `<<anchor>>` 标识；**规范正文不复制进本仓库**。

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
| 文档只增不减 → 定期清理 | 🔜 | 迭代末清理节点 | `TASKS.md` 定期节点 |
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
| 按时清理（增量 / 定期 / 阈值） | 🔜 | 定期节点；阈值清理待首次触发后补流程 |
| 借用与复制边界 | ✅ | `DECISIONS.md` D-001/D-003；术语只参考不复制 |

## 5. 版本与发布

| 条款 | 状态 | 落地位置 | 校验 |
|---|---|---|---|
| SemVer 2.0.0 正则与三处一致 | ✅ | `docs/VERSIONING.md` | `scripts/check-versions.ps1` |
| tag 与版本一致、tag 不改 | ✅ | 同上 | 同上（在 tag 上运行时校验） |
| 发布前七项检查（可复现 / 清单 / 许可 / 敏感信息 / 扫描 / 说明与回滚） | 🔜 | 部分由 `build_release.py --verify` 覆盖；VirusTotal 与签名见 `TASKS.md` | — |
| CHANGELOG 含变更 / 已知问题 / 回滚 | ✅ | `docs/CHANGELOG.md` 模板 | `scripts/check-versions.ps1`（版本+日期） |
| 制品的 SHA256 与发布说明 | ✅ | Release 正文 | 发版清单第 7 步 |

## 6. 度量与豁免

| 条款 | 状态 | 说明 |
|---|---|---|
| 提交规模告警（>400 行提示拆分） | ✅ | `.githooks/commit-msg` |
| 校验覆盖率 / 误报率看板 | ➖ | 单人维护项目，采用「CI 全绿 + 发版清单」替代度量看板 |
| AI 代码审查通道 | ➖ | 未接入；接入前须完成历史 PR 回放测误报率（规范要求） |
| 豁免流程 | ✅ | 任何跳过校验的提交必须在 `DECISIONS.md` 新增条目说明理由与补救 |

## 7. 复核方式

```bash
pwsh -NoLogo -NoProfile -File scripts/verify.ps1
```

退出码 0 表示上述 ✅ 项全部通过；➖ 项不产生检查；🔜 项见 `TASKS.md`。
