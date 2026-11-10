# 引擎热修复（可选）

> 适用引擎：**`playtest-20261026`**（OpenRA 2026-10-26 playtest）。
> 作用：修复「红警 → 战役 → 点任务」时**中文战役简报**导致的闪退。
> 性质：**可选**。不装它，汉化补丁照常工作，只是那一个界面会崩。

## 一、什么时候需要

只有满足下面两条时才需要：

1. 用的是 `playtest-20261026`；
2. 界面语言是中文，且进「战役」点任务时闪退（报错文件在 `%APPDATA%\OpenRA\Logs\exception-*.log`）。

不满足就别装——尤其是上游已经修好的版本，装了反而多余。

## 二、怎么用（纯 CMD 优先）

1. **关掉所有 OpenRA 窗口**（三个 exe 都退干净）；
2. **双击 `apply-hotfix.bat`**；如果这台机器把 `.bat` 关联改过、或被安全软件拦了，
   就双击同目录的 `apply-hotfix.cmd`——两者内容完全一样，只是扩展名不同。
3. 在 UAC 弹窗点「是」（默认目录 `C:\Program Files\OpenRA (playtest)` 需要管理员权限；
   装在自建目录里不会弹）。看到两行 `[OK]` 即成功，直接启动游戏进「战役」验证。

**这两个入口是纯批处理，完全不依赖 PowerShell。** 屏幕提示是英文：`cmd.exe` 在非 ASCII
代码页下会把中文批处理行拆坏，所以脚本刻意只用 ASCII；常用提示的中文含义：

| 屏幕提示 | 含义 |
|---|---|
| `[BACKUP] ...orig-20261109` | 已备份官方原版 |
| `[OK] OpenRA.Game.dll` | 该文件已替换为热修版，且覆盖后哈希校验通过 |
| `[SKIP] ... is already the hotfix build` | 之前已经打过，跳过 |
| `[ERROR] ... hash is neither ...` | DLL 不是官方原版也不是热修版，已中止且零文件被改动 |

装在别处的话，把目录作为第一个参数传入：

```text
apply-hotfix.bat "D:\Games\OpenRA"
apply-hotfix.cmd "D:\Games\OpenRA"
```

PowerShell 可用的机器也可以继续用原来的 `.ps1`（右键 →「使用 PowerShell 运行」，或
`powershell -ExecutionPolicy Bypass -File apply-hotfix.ps1 -Target "D:\Games\OpenRA"`）。
**两套入口行为等价、互相独立**，任选其一；`.ps1` 坏了不影响 `.bat` / `.cmd`。

> `.bat` / `.cmd` 由 `tools/build_release.py` 从 `tools/cmd-templates/*.tpl` 现场生成，
> **不进仓库**；仓库里仍然零 `.bat` / `.cmd`（见 `DECISIONS.md` D-011）。

脚本的行为：

- 先对两个 DLL 统一做 SHA256 预检，**只接受「官方原版」或「已打过热修」两种状态**，
  任何一个不合格就整体中止、零文件被改动（避免覆盖到别的引擎版本）；
- 首次替换前把原版备份为 `OpenRA.Game.dll.orig-20261109` /
  `OpenRA.Mods.Common.dll.orig-20261109`；
- 替换后再次校验哈希，用的是系统自带 `certutil.exe`，不是 PowerShell。

想还原：双击 `rollback-hotfix.bat` 或 `rollback-hotfix.cmd`（也可运行 `rollback-hotfix.ps1`），
从备份恢复并校验哈希。上游修复该缺陷后，直接删掉本目录即可，不必还原。

## 三、它改了什么

只改了两个引擎程序集，共两处，**不涉及游戏逻辑、美术、音频与任何文本**：

| 文件 | 改动 | 目的 |
|---|---|---|
| `OpenRA.Game.dll` | `Sheet.GetTexture()` / `Sheet.CommitBufferedData()` 中对可空字段的两次读取改为一次（`Nullable<T>.Value` → `GetValueOrDefault()`） | 消除 `Nullable object must have a value` |
| `OpenRA.Mods.Common.dll` | `MissionBrowserLogic.SelectMap()` 中 `new Thread(...).Start()` 改为在当前（主）线程同步调用同一个委托 | 不再在后台线程生成字形，从根上避免与渲染线程争用图集 |

对应的源码级改动（便于自行构建与审阅）：

```csharp
// OpenRA.Game/Graphics/Sheet.cs
public ITexture GetTexture()
{
    ...
    var region = dirtyRegion;                       // 读一次
    if (region != null && texture.Size == Size && Size != region.Value.Size)
    {
        texture.SetSubData(data, region.Value.X, region.Value.Y, region.Value.Width, region.Value.Height);
    }
    ...
}

// OpenRA.Mods.Common/Widgets/Logic/MissionBrowserLogic.cs
void SelectMap(MapPreview preview)
{
    ...
    // 原本：new Thread(() => { ... WrapText / Measure ... }).Start();
    // 改为在主线程直接执行同一段逻辑（删掉 new Thread(...).Start() 包装）
}
```

## 四、风险与边界

- **这两个文件来自 OpenRA（GPL-3.0）并做了本地修改**，随本补丁包分发；
  上面「它改了什么」一节即为修改说明。上游原版可在 <https://github.com/OpenRA/OpenRA> 获取。
- 部分安全软件可能对「被修改过的引擎程序集」报毒，属误报；不放心就**不要装**，
  改用英文界面同样能避开该崩溃。
- 联机与存档不受影响：热修不碰地图数据与存档目录。
- 引擎升级后本热修立即失效（哈希校验会直接中止），届时删掉本目录即可。

## 五、文件清单

| 文件 | 大小 | SHA256 |
|---|---|---|
| `OpenRA.Game.dll` | 923,136 | `105e0003cccadd44c4bd711a1920a8d0f3329504b2c2403281392d89b67d9948` |
| `OpenRA.Mods.Common.dll` | 3,655,168 | `1faf14403e0c65ed83be1d7efc7b7ac1a3ffb1462c5934e5ab1ddd92e22cd1ea` |

另有六份脚本：纯 CMD 的 `apply-hotfix.bat` / `.cmd`、`rollback-hotfix.bat` / `.cmd`
（四个文件两两同内容，由打包脚本现场生成、不进仓库），以及 PowerShell 版
`apply-hotfix.ps1` / `rollback-hotfix.ps1`。两套入口互相独立，PS1 不可用也能装。

包根目录另有主安装器的纯 CMD 入口 `setup.bat` / `setup.cmd`，它读 `bin\files.sha256`
逐文件校验 208 个文本与两个字体；详见包内 `安装说明.md`。

对应的官方原版 SHA256（脚本据此判断当前状态）：

| 文件 | SHA256 |
|---|---|
| `OpenRA.Game.dll` | `4182e606f7da23095d649406c5eb65840888d6b548849f6a9b9d0b8ff8003597` |
| `OpenRA.Mods.Common.dll` | `1cf381887df9b52ddfdf6d9fc5f8ab613a9b928ff145103cd3297af5c08cab38` |

## 六、上游进展

问题已提交上游：<https://github.com/OpenRA/OpenRA/issues/22716>
维护者确认根因是 `SpriteFont` 非线程安全（英文版仅因 ASCII 字形被主线程预缓存而不暴露），
修法方向是把字形的 sprite 更新投递回主线程。**上游修好后，本热修会随下个版本一并移除。**
