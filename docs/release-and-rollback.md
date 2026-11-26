# 发布、安装、回滚与版本兼容说明

> 本仓是 **OpenRA 简体中文汉化补丁**，不是 OpenRA 游戏本体工程。本文只覆盖汉化载荷的
> 安装、卸载、回滚、版本兼容与校验和；上游编译、地图与引擎逻辑不在本仓范围。
> 每个文件属于哪一类、载荷怎么构成，见 [`ANATOMY.md`](ANATOMY.md)；维护者怎么重建、
> 怎么发版，见 [`MAINTAINING.md`](MAINTAINING.md)。

## 1. 发布物清单

仓库里每条产品线各占一个目录，真相源是该线 `bin/manifest.json`：

| 产品线 | 载荷目录 | 目标引擎 | 清单 |
|---|---|---|---|
| playtest 线（默认） | `playtest-20261026/files/` + `fonts/` | `playtest-20261026` | [`playtest-20261026/bin/manifest.json`](../playtest-20261026/bin/manifest.json) |
| 稳定版线 | `release-20250330/files/` + `fonts/` | `release-20250330` | `release-20250330/bin/manifest.json` |

成品分发包由 `tools/build_release.py` 确定性构建为 `dist/*.zip`（不入库），包内布局与
打包白名单见 [`MAINTAINING.md`](MAINTAINING.md)「发布包里放什么」。

## 2. 安装

玩家侧图文步骤见 [`playtest-20261026/安装说明.md`](../playtest-20261026/安装说明.md)
与 [`../README.md`](../README.md)「三分钟装好」。入口：

- Windows PowerShell：`src/setup.ps1`（只做参数转发，业务逻辑在
  [`src/install.ps1`](../src/install.ps1)）。
- 纯 CMD 路线：`setup.bat` / `setup.cmd`（打包时由模板现场生成，自带安装 / 还原 / 卸载校验）。
- 手动安装：按安装说明把 `files/` 与 `fonts/` 放到对应引擎目录。

安装器先备份将被覆盖的同名文件，再写入载荷并做 SHA-256 复读校验；任何一步失败即中止。

## 3. 卸载与回滚

- 卸载：`src/install.ps1 -Uninstall`（或 CMD 入口的还原项），按备份逐字节还原原版文件。
- 回滚到上一版：卸载当前补丁后，从对应 GitHub Release 取上一版 zip 重新安装。
- 补丁只向引擎目录放覆盖文件，不改可执行文件；地图 `map.yaml` 不纳入载荷（避免改变地图
  UID、破坏联机与录像兼容性，原理见 [`ANATOMY.md`](ANATOMY.md)）。

## 4. 版本兼容

- 版本号规则与两条产品线的统一版号约定见 [`VERSIONING.md`](VERSIONING.md)；
  版本真相源是各线 `bin/manifest.json` 的 `version` / `releaseDate`。
- **引擎升级后旧载荷不能直接套用**：键名对不上时引擎不回退英文，会把键名直接画到界面上；
  迁移到新版英文目录的流程见 [`MAINTAINING.md`](MAINTAINING.md)「引擎升级」。
- 字体随包分发（Noto Sans SC Regular/Bold）；包内缺失才回退系统字体。
- 未核对的引擎版本 / 平台兼容性不写「兼容」结论。

## 5. 校验和

本仓**不另建根目录 `SHA256SUMS.txt`**：载荷与字体的 size + SHA256 已登记在各线
`bin/manifest.json` 的 `files[]` 与 `font.bundled[]` 中，作为唯一校验和载体，避免两处漂移。

- 离线校验（纯标准库）：[`../tools/verify_manifest.py`](../tools/verify_manifest.py)
  逐字节比对 `files/` 与清单一致，并守住「字体不进 `files/`」的授权红线。
- 打包自校验：`tools/build_release.py --verify` 在解压出的包上复查入口齐全、清单一致、
  载荷与字体哈希对得上、`files/` 无多余文件。
- 唯一验收入口（串起全部本地检查）：[`../scripts/verify.ps1`](../scripts/verify.ps1)。

## 6. 既有等价载体（不重复造）

| Tier C 职责 | 本仓既有载体 | 处置 |
|---|---|---|
| 发布/安装/卸载/回滚/兼容说明 | 本文 + `README.md` + 各线 `安装说明.md` + `MAINTAINING.md` | 已落地 |
| 发布前检查清单 | [`release-checklist.md`](release-checklist.md) + `scripts/pre-release.ps1` 七项自检 | 已落地 |
| 变更记录 | 根 [`../CHANGELOG.md`](../CHANGELOG.md)（Unreleased）+ [`../docs/CHANGELOG.md`](CHANGELOG.md)（版本史） | 已落地 |
| 发布物哈希校验 | `manifest.json` + `tools/verify_manifest.py` | 既有，不另建 `SHA256SUMS` 与第二套校验脚本 |
| 发布门禁 CI | [`.github/workflows/validate.yml`](../.github/workflows/validate.yml) | 既有，不另建 `release-check.yml` 重复跑同一条链 |
