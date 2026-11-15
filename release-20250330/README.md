# release-20250330 适配包（v2.0）

本目录是把本项目（上游 1.6.1，只适配 `playtest-20261026`）的译文**重新适配到 OpenRA 官方稳定版 `release-20250330`** 的成品载荷。

| 想看什么 | 去哪 |
|---|---|
| 怎么装、怎么卸、常见问题 | `安装说明.md` |
| 为什么能适配、改了哪些、校验记录 | `适配说明.md` |
| 还剩哪些没翻 | `未译条目清单.csv`（224 条） |
| 入口脚本 | `setup.ps1`（安装 / 还原 / 校验） |
| 逐文件校验清单 | `bin/manifest.json` |

## 关于字体

仓库约定「字体只放 `fonts/`」，所以本目录**不重复存放**字体文件。`setup.ps1` 先找 `files/mods/common/`，找不到就自动回落到仓库根的 `../fonts/`。

完整的独立发布包（自带字体、自带纯 CMD 入口）见 Releases 资产：

```
OpenRA_Simplified_Chinese-2.0-release20250330.zip
```

## 快速用法

```powershell
pwsh -File setup.ps1 -Target "D:\OpenRA" -Mode Install   # 安装
pwsh -File setup.ps1 -Target "D:\OpenRA" -Mode Verify    # 校验（退出码 0 = 完好）
pwsh -File setup.ps1 -Mode Restore                       # 还原英文
```

## 范围与边界

- **只对 `release-20250330` 生效**；装到 playtest 版请改用 1.6.1 那版，两套不要混用。
- 载荷 = 197 个文本文件（含 127 份地名图的 `rules.yaml`）+ 2 个字体，共 199 项，逐文件哈希在 `bin/manifest.json`。
- 不改 `.dll`、不改 `map.yaml`、不改美术音频，因此不携带 `hotfix/`（那个热修只修 playtest 的字形线程崩溃，稳定版无此缺陷）。
- **关卡名仍是英文**：在 `map.yaml` 里，改它会改变地图 UID、破坏联机一致性，故**故意不碰**。
- **战役简报已全部中文化**：127 张有简报的地图把正文内联进各自的 `rules.yaml`（`rules.yaml` 不参与地图 UID，不影响联机与旧录像）。另 13 张是 1.6.1 线独有地图，稳定版无对应目录。
  唯一未验证的是**渲染**：1.6.1 线出过中文简报触发的字形线程崩溃（OpenRA#22716），稳定版是否同样受影响尚未实机确认；异常时 `-Mode Restore` 零残留回退。
- 仓库内零 `.bat` / `.cmd`（CI 守卫），批处理入口只在发布 zip 内生成。
