# 版本号规则（SemVer 2.0.0）

> 规则来源：[语义化版本 2.0.0 官方中文版](https://semver.org/lang/zh-CN/)（CC BY 3.0）。
> 本文只写**本仓库可执行、可校验**的部分，条文冲突时以官方版本为准。

## 1. 单一真相

| 位置 | 角色 |
|---|---|
| `src/manifest.json` → `version` | **唯一真相**，安装器与打包脚本读它 |
| `docs/CHANGELOG.md` 顶层 `## X.Y.Z` | 派生：必须与上者一致 |
| `src/安装说明.md` 首行标题 | 派生：必须与上者一致 |
| Git tag `vX.Y.Z` | 派生：`v` 是 tag 前缀，不是版本号本身 |

三者不一致时 `scripts/check-versions.ps1` 直接失败。**不要新增 `VERSION` 文件**：多一份手写真相，必然分叉。

## 2. 本项目里的「公开接口」

版本号只对**使用者能感知的契约**负责。本项目的契约是：

1. 发布包结构：zip 顶层布局、`bin/` 与 `files/` 的映射
2. `src/manifest.json` 的 schema（字段名与含义）
3. `setup.ps1` / `install.ps1` 的参数语义
4. 支持的引擎版本（`engineVersion`）

译文内容本身**不是**接口——改一句译文永远只升修订号。

## 3. 递增判据

| 位置 | 何时递增 | 本项目的典型例子 |
|---|---|---|
| **主版本 X** | 契约发生不兼容变化 | 删改 `setup.ps1` 参数、改 `manifest.json` 字段语义、包内目录重排导致旧脚本失效 |
| **次版本 Y** | 向下兼容的新能力 | 新增汉化模块、新增 `-FontPath` 这类参数、适配新一代 playtest 引擎 |
| **修订号 Z** | 向下兼容的修正 | 译文修正、错别字、术语统一、无接口变化的构建脚本修补 |

硬性要求：

- 禁止前导零（`1.09.0` 非法）；比较必须按数值，不得按字符串（`1.9.0 < 1.10.0`）
- 已发布版本不得修改；任何改动都以新版本发行
- 弃用必经次版本：标记弃用随 `Y` 发布，下一个主版本才可移除
- `1.0.0` 之前视为初始开发；本项目已越过该线，按上表执行
- 预发布标识用于「适配中的引擎」：`1.7.0-rc.1` 表示适配尚未验证完成的候选

## 4. tag 与发布

- tag 格式 `vX.Y.Z`，与 `version` 一致；**推送后不改不删**，发错就发新修订号
- 发布包文件名 `OpenRA_Simplified_Chinese-X.Y.Z.zip`
- GitHub Release 标题与 tag 一致；正文必须包含：**变更 / 已知问题 / 回滚方式**

## 5. CHANGELOG 格式

```markdown
## 1.7.0 — 2026-12-01

**一句话结论（本次改动的性质）。**

- 变更条目……
- **验证**：跑了哪些命令、结果如何
```

- 顶层条目版本必须等于 `manifest.json` 的 `version`
- 日期用 `YYYY-MM-DD`，与 `releaseDate` 一致（`check-versions.ps1` 一并校验）
- 未发布版本在标题后加 `（未发布）`，发布时去掉

## 6. 发版清单

1. 改 `src/manifest.json` 的 `version` 与 `releaseDate`（唯一手改点）
2. 在 `docs/CHANGELOG.md` 顶部加同版本条目
3. 同步 `src/安装说明.md` 首行版本号，重建 `.txt`：`python tools/build_install_txt.py`
4. `python tools/build_manifest.py` 重算载荷与字体哈希
5. `pwsh -NoLogo -NoProfile -File scripts/verify.ps1` 全绿
6. 提交 → 打 tag `vX.Y.Z` → 推送 tag → CI 从 tag 构建发布包
7. Release 正文附：变更、已知问题、回滚方式、发布包 SHA256
