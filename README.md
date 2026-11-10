<div align="center">

# 🎮 OpenRA 简体中文汉化补丁

**红警 · 泰伯利亚黎明 · 沙丘 2000 —— 界面、单位、任务、简报，一次全中文**

[![validate](https://github.com/Janlhin/OpenRA_Simplified_Chinese/actions/workflows/validate.yml/badge.svg)](https://github.com/Janlhin/OpenRA_Simplified_Chinese/actions/workflows/validate.yml)
[![release](https://img.shields.io/github/v/release/Janlhin/OpenRA_Simplified_Chinese?label=release&color=2ea44f)](https://github.com/Janlhin/OpenRA_Simplified_Chinese/releases)
[![license](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)
![platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)

</div>

> 🧩 非官方社区作品，与 OpenRA 项目无隶属关系。适配引擎 **`playtest-20261026`**。

---

## ✨ 它做了什么

| | 内容 |
|---|---|
| 🖥️ **界面** | 主菜单、设置六大页、单人 / 遭遇战 / 多人房间、服务器列表、观战、录像、地图编辑器 |
| 🪖 **单位与建筑** | 三个阵营的名称、说明、武器与技能提示（含超级武器） |
| 🎯 **任务** | 任务目标、任务内对话、**140 份战役简报**、16 个战役分组名 |
| ⌨️ **快捷键** | 设置 → 快捷键页的全部条目 |
| 💿 **内容安装器** | 安装向导的 20 条下载源名称、光盘提示 |
| 🐞 **作弊面板** | 上游把 `Debug` 更名为 `Cheats` 后的整套新文案 |

**三个"不做"**，避免踩坑：

- 🚫 **不碰 `map.yaml`** —— 地图 UID 会变，联机对不上、旧录像读不了
- 🚫 **不改游戏逻辑** —— 只换文本，不动 `.dll`、不动美术音频
- 🚫 **不联网** —— 安装、校验、还原全部本地完成

## 📥 三分钟装好

1. ⬇️ 到 **[Releases](https://github.com/Janlhin/OpenRA_Simplified_Chinese/releases)** 下载最新的 `OpenRA_Simplified_Chinese-x.y.z.zip`
2. 📂 解压到一个**英文路径**下，例如 `D:\OpenRA_CN`
3. 🛑 **关闭 OpenRA**
4. 🖱️ **右键 `setup.ps1` → 使用 PowerShell 运行** → 菜单输入 `1` → 回车
5. 🔧 **（可选）** 进「战役」点任务闪退的话：双击 `hotfix\apply-hotfix.bat`（Windows 下 `.ps1` 双击只会用记事本打开）

> 装在 `C:\Program Files` 会弹一次 UAC；引擎版本不匹配会先警告再询问。

命令行等价用法：

```bat
setup.ps1 -Target "C:\Program Files\OpenRA (playtest)"   :: 指定目录
setup.ps1 -DryRun        :: 只预览，不写任何文件
setup.ps1 -Uninstall     :: 还原英文
setup.ps1 -Verify        :: 校验是否卸干净
setup.ps1 -FontPath "D:\你的字体.ttf"   :: 换字体
```

## 🧩 包里有什么

解压后**顶层 10 项**，连子目录共 225 个文件：

```text
OpenRA_Simplified_Chinese\
├─ 🖱️ setup.ps1                  ← 右键 → 使用 PowerShell 运行
├─ 📖 README.md                  ← 逐文件说明（含 208 行清单）
├─ 📄 安装说明.txt / .md           ← PS1 装 / AI 装 / 手动装 / 排查 / 可选热修
├─ ⚖️ LICENSE / LICENSE-OFL.txt   ← 补丁 GPL、字体 OFL
├─ 📦 bin\  install.ps1 · manifest.json
├─ 🔤 fonts\ NotoSansSC-Regular.ttf · -Bold.ttf
├─ 🔧 hotfix\                     ← 可选：引擎热修（仅 playtest-20261026）
│                                  ← apply-hotfix.bat / .ps1（应用）、rollback 同理
└─ 📚 files\mods\                 ← 208 个中文文本（覆盖到游戏 mods\）
```

每个文件干什么、能不能删、属于哪一类，见 **[`src/PACKAGE-README.md`](src/PACKAGE-README.md)**
（它就是打进 zip 的那份 `README.md`，附全部 208 个载荷的清单与大小）。

## 🗺️ 覆盖范围

| 模块 | 状态 |
|---|---|
| 红色警戒 (ra) 界面 / 单位 / 战役 | ✅ 已汉化 |
| 泰伯利亚黎明 (cnc) 界面 / 单位 / 战役 | ✅ 已汉化 |
| 沙丘 2000 (d2k) 界面 / 单位 / 战役 | ✅ 已汉化 |
| 内容安装向导与「内容管理」 | ✅ 已汉化 |
| 地图元数据里的地图标题（`Allies 01` 等） | ❌ **故意不翻**（见下） |

> ❓ 为什么任务列表里的关卡名还是英文：
> 地图 UID = `SHA1(map.yaml + *.bin + *.lua + map.png)`。改 `map.yaml` 会让打了补丁的玩家与
> 没打补丁的玩家**地图哈希不一致**，旧录像也会读不出来。`.ftl` 不参与 UID 计算，所以译文不影响联机。

## 🧱 仓库结构

```text
.
├─ 📄 README.md                       你正在看的
├─ 🤖 AGENTS.md                       AI 协作入口（目录，≤150 行）
├─ 🧾 DECISIONS.md                    决策日志（含被否决方案与理由）
├─ 📋 TASKS.md                       任务队列（含可机器判定的完成判据）
├─ 📦 MANIFEST.md                    第三方字体/源码的来源、SHA256 与许可
├─ ⚖️ LICENSE · LICENSE-OFL.txt       补丁 GPL-3.0 / 字体 SIL OFL 1.1
├─ 📦 src\                            打包源（进 zip 的就是这里）
│   ├─ setup.ps1 · install.ps1 · manifest.json
│   ├─ PACKAGE-README.md              包内 README 的源文件
│   ├─ hotfix\                        可选引擎热修（apply / rollback / 两个 DLL）
│   └─ 安装说明.txt · 安装说明.md
├─ 📚 files\mods\                     208 个载荷（覆盖树）
├─ 🔤 fonts\                          Noto Sans SC 两个字重
├─ 🛠️ tools\                          校验、载荷重建、打包、文档生成
├─ 🧪 scripts\                        唯一验收入口 verify.ps1 与各项守卫
├─ 🪝 .githooks\                      pre-commit / commit-msg 薄壳
├─ 📘 docs\                           ANATOMY · MAINTAINING · CONTRIBUTING · CHANGELOG
│   ├─ VERSIONING.md · COMPLIANCE.md  版本号规则 / 规范落地矩阵
│   └─ archive\rasc-ref\              译名对齐的历史资料（已归档）
└─ ⚙️ .github\                        CI 与 issue / PR 模板
```

| 想了解 | 去哪看 |
|---|---|
| 🗂️ 每个文件是什么、载荷怎么构成 | [`docs/ANATOMY.md`](docs/ANATOMY.md) |
| 🔧 怎么重建载荷、怎么发版、CI 有哪些门禁 | [`docs/MAINTAINING.md`](docs/MAINTAINING.md) |
| ✍️ 想改一句译文 | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| 🕒 每个版本改了什么 | [`docs/CHANGELOG.md`](docs/CHANGELOG.md) |
| 🔢 版本号怎么定、怎么发版 | [`docs/VERSIONING.md`](docs/VERSIONING.md) |
| 🧭 工程规范条款在本仓库如何落地 | [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) |
| 🌐 引擎侧本地化（多语言）的现状、路线与待办 | [`docs/LOCALIZATION-ROADMAP.md`](docs/LOCALIZATION-ROADMAP.md) |
| 🧾 为什么这样设计、否决过什么 | [`DECISIONS.md`](DECISIONS.md) |
| 📋 还有哪些事没做、怎样算做完 | [`TASKS.md`](TASKS.md) |
| 📦 第三方字体与源码的来源与许可 | [`MANIFEST.md`](MANIFEST.md) |
| 🤖 AI 协作者先读哪 | [`AGENTS.md`](AGENTS.md) |

## 🧪 技术栈与验收

| 项 | 值 |
|---|---|
| 运行时 | PowerShell **7.4+**（`pwsh`）；Python **3.11+**（`fonttools`） |
| 数据格式 | Fluent `.ftl`、YAML、JSON；无编译产物 |
| 目标平台 | Windows 10 / 11（安装器）；校验脚本跨平台 |
| 第三方来源 | 见 [`MANIFEST.md`](MANIFEST.md) |

**验收标准（可机器判定）**：以下命令退出码为 `0`。

```powershell
pwsh -NoLogo -NoProfile -File scripts/verify.ps1        # 全量
pwsh -NoLogo -NoProfile -File scripts/verify.ps1 -Fast  # 提交前快检
```

检查项只在 `scripts/verify.ps1` 维护一份：载荷与 `manifest.json` 逐字节一致、Fluent 规范、
地图文案结构、文档链接与锚点、生成物（`安装说明.txt`、README 附录）未被手改、字形覆盖、
发布包自校验、版本号三处一致、五个治理文档字段完整。CI 调用的也是同一条命令。

首次参与贡献：建本地校验环境并装钩子。

```powershell
uv venv .venv                                                    # 或 python -m venv .venv
uv pip install --python .venv\Scripts\python.exe fonttools        # 字形覆盖检查需要
pwsh -NoLogo -NoProfile -File scripts/install-hooks.ps1
```

`scripts/verify.ps1` 的解释器优先级：仓库内 `.venv` → `PYTHON` 环境变量 → PATH 上的 `python`/`python3`。

## ❓ 常见问题

<details>
<summary>🀄 界面还是英文 / 有方块？</summary>

英文 → 文本没覆盖成功，检查是否多套了一层 `mods\mods`；
方块 → 字体没生效，`mods\common\` 下应当有 `NotoSansSC-Regular.ttf` 与 `-Bold.ttf`。
完整排查见 [`src/安装说明.md`](src/安装说明.md)。
</details>

<details>
<summary>🔁 卸载了但还是中文？</summary>

1.5.2 之前确实会这样：卸载可能挑中"重复安装留下的译文快照"。现在会自动跳过这类备份，
并用最早那份真正的英文快照还原。重跑 `setup.ps1` → `2` 即可；也可
`setup.ps1 -Uninstall -Backup <备份目录名>` 指定。
</details>

<details>
<summary>🌐 会影响联机或存档吗？</summary>

不改地图数据，联机兼容；存档在 `%APPDATA%\OpenRA`，补丁不碰。
但服务器若装了文件校验插件，理论上可能判定为改文件。
</details>

<details>
<summary>🛡️ 杀毒软件报毒？</summary>

安装器是未签名的脚本，部分杀软会提示。不放心就走 `安装说明` 里的**手动安装**，效果完全一样。
</details>

<details>
<summary>🐞 进「战役」点任务就闪退？</summary>

这是**上游引擎缺陷**，不是汉化的问题：`playtest-20261026` 在中文文本首次上屏时会在后台线程生成字形，
与渲染线程争用同一份图集。已上报 <https://github.com/OpenRA/OpenRA/issues/22716>，里面有复现步骤、根因分析与修法建议。

**1.6.1 起包内附带可选热修**：关掉游戏后**双击 `hotfix\apply-hotfix.bat`**（Windows 下 `.ps1` 双击只会用
记事本打开，所以包里备了这个转发入口），在 UAC 弹窗点「是」；脚本会校验哈希、备份原版再覆盖，
`hotfix\rollback-hotfix.bat` 可一键还原。不想装热修也行：卸载补丁改用英文界面即可避开；上游修复后本热修会随下个版本移除。
</details>

<details>
<summary>🎚️ 战役界面「难度」是灰的、点不动？</summary>

部分任务本身没有难度选项（上游设计，如红警 01、10b 与苏军 01/02a/02b），不是汉化造成的；换一个有难度的任务即可。
</details>

## ⚠️ 已知限制

- 🐞 **上游引擎缺陷**：`playtest-20261026` 下中文战役简报会触发崩溃（见下方「常见问题」）。1.6.1 起包内附带**可选引擎热修** `hotfix\`；上游修复后该热修会随下个版本移除。已上报 [#22716](https://github.com/OpenRA/OpenRA/issues/22716)
- 🔤 字体用的是 **Noto Sans SC 全量字形**（约 20 MB），比系统黑体占空间，但换来"不依赖本机字体"
- 📐 字号观感：Noto 的行高与原 `FreeSans` 不同，个别 UI 缩放档位可能略挤，可在 `mod.yaml` 的 `Fonts:` 微调
- 🪟 只提供 Windows 脚本；Linux / macOS 可手动覆盖 `files/` 并把 `fonts/` 放进 `mods/common/`
- 🧭 只适配 `playtest-20261026`；引擎升级后请先卸载旧补丁再更新

## 🛣️ 后续计划

- [x] 🎨 随包自带中文字体，不再依赖本机
- [x] 🧯 安装器可回滚、可校验、卸载能挑对备份
- [ ] 📸 补一组界面截图，放到 README 顶部
- [ ] 🖋️ 可选主题字体（霞鹜文楷），做成独立附件
- [x] 🧨 **入口全面改用 `.ps1`**：`setup.ps1` 取代 `setup.cmd`，仓库与包里已无任何 `.bat` / `.cmd`
- [x] 📜 **约定落地**：CI 守卫禁止任何 `.bat` / `.cmd`，**零例外**
- [ ] 🖱️ **恢复双击体验**：`.ps1` 双击只会打开记事本；候选 `.lnk` 垫片或单文件 exe
- [ ] 🐧 Linux / macOS 的一页式手动安装文档
- [ ] 📝 术语表统一校对（借 `docs/archive/rasc-ref` 的对齐结果）

> 有想法欢迎开 issue；计划表只代表方向，不代表排期。

## 🙏 致谢

| | 贡献 |
|---|---|
| 🎮 [OpenRA](https://www.openra.net/) 项目 | 游戏引擎与全部原始英文文案。本补丁只做翻译，不改逻辑 |
| 🇨🇳 OpenRA 汉化组（Gitee [CastleJing](https://gitee.com/CastleJing)） | 红警 [RASC](https://gitee.com/CastleJing/OpenRA_rasc) 与泰伯利亚黎明 [TDSC](https://gitee.com/CastleJing/OpenRA_tdsc) 的译法共识，本项目单位与建筑名对齐其用词 |
| 🔤 [Noto Sans SC](https://github.com/notofonts/noto-cjk) | 随包中文字体，Google / Adobe 出品，SIL OFL 1.1 |
| 🐞 所有反馈者 | 提交译文修正、报告方块字与漏翻的人，见 [`docs/CHANGELOG.md`](docs/CHANGELOG.md) |

## 📄 许可

- 本补丁：**GPL-3.0-or-later**，全文见 [`LICENSE`](LICENSE)
- 随包字体 Noto Sans SC：**SIL OFL 1.1**，全文见 [`LICENSE-OFL.txt`](LICENSE-OFL.txt)
- 原始英文文案版权归 OpenRA 项目（GPL-3.0）所有

## 💖 赞助支持

如果这个汉化补丁让你玩得更顺手，欢迎用下面的方式请作者喝杯咖啡 ☕

<div align="center">

| 微信赞赏 | 支付宝 |
|:---:|:---:|
| <img src="docs/assets/sponsor-wechat.jpg" width="220" alt="微信赞赏码" /> | <img src="docs/assets/sponsor-alipay.jpg" width="220" alt="支付宝收款码" /> |

</div>

> 扫码即可，金额随意。不想掏钱也完全没关系，点个 ⭐ Star 同样是很大的支持。

---

<div align="center">

⭐ 如果这个补丁让你玩得舒服一点，点个 Star 就是最好的支持

</div>
