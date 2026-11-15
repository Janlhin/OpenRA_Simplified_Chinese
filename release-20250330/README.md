# release-20250330 适配包（v2.0.0）

本目录是本项目的**第二条产品线**的成品载荷：把 1.6.1 线的译文重新适配到 OpenRA 官方稳定版 `release-20250330`。
两条线共用同一套安装器（`src/setup.ps1` 转发 → `src/install.ps1` 业务），本目录只放「这条线装什么」。

| 想看什么 | 去哪 |
|---|---|
| 怎么装、怎么卸、常见问题 | `安装说明.md` |
| 为什么能适配、改了哪些、校验记录 | `适配说明.md` |
| 还剩哪些没翻（234 条，带归类） | `未译条目清单.csv` |
| 逐文件真相（size / SHA-256 / 字体 / 目标引擎） | `bin/manifest.json` |
| 载荷 | `files/`（197 个文本文件） |

## 怎么出包

仓库里**不放**这条线的安装器副本：安装器统一来自 `src/`，打包时由流水线组装（含纯 CMD 双入口与 `bin/files.sha256`）：

```powershell
python tools/build_release.py --profile release-20250330 --verify
# 产出 dist/OpenRA_Simplified_Chinese-2.0.0-release20250330.zip（含字体、setup.ps1 / setup.bat / setup.cmd）
```

不要直接拿 `files/` 手工覆盖游戏目录：字体在仓库根 `fonts/`，`mod.yaml` 已改写字体名，缺字体就会满屏方块。

## 范围与边界

- **只对 `release-20250330` 生效**；装到 playtest 版请改用 1.6.1 那版，两套不要混用。
- 载荷 = 197 个文本文件（含 127 份地图的 `rules.yaml`）+ 2 个字体，共 199 项，逐文件哈希在 `bin/manifest.json`。
- 不改 `.dll`、不改 `map.yaml`、不改美术音频，因此不携带 `hotfix/`（那个热修只修 playtest 的字形线程崩溃，稳定版无此缺陷）。
- **关卡名仍是英文**：在 `map.yaml` 里，改它会改变地图 UID、破坏联机一致性，故**故意不碰**。
- **战役简报已全部中文化**：127 张有简报的地图把正文内联进各自的 `rules.yaml`（`rules.yaml` 不参与地图 UID，不影响联机与旧录像）。另 13 张是 1.6.1 线独有地图，稳定版无对应目录。
  唯一未验证的是**渲染**：1.6.1 线出过中文简报触发的字形线程崩溃（OpenRA#22716），稳定版是否同样受影响尚未实机确认；异常时 `-Uninstall` 零残留回退。
- 仓库内零 `.bat` / `.cmd`（CI 守卫），批处理入口只在发布 zip 内生成。
