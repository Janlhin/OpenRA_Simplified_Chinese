<#
    OpenRA 简体中文补丁 · 适配官方稳定版 release-20250330
    安装 / 还原 / 校验，全部在本机完成，不联网。

    用法：
      .\setup.ps1                    交互菜单
      .\setup.ps1 -Target "D:\OpenRA" -Mode Install
      .\setup.ps1 -Mode Restore
      .\setup.ps1 -Mode Verify
      .\setup.ps1 -Mode Install -DryRun   只预览，不写任何文件
#>
[CmdletBinding()]
param(
    [string] $Target,
    [ValidateSet('Menu', 'Install', 'Restore', 'Verify')]
    [string] $Mode = 'Menu',
    [switch] $DryRun,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$PkgRoot  = $PSScriptRoot
$FilesRoot = Join-Path $PkgRoot 'files'
$ManifestPath = Join-Path $PkgRoot 'bin\manifest.json'
$Stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')

function Get-Sha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
}

function Write-Title([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 62) -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 62) -ForegroundColor DarkGray
}

function Find-OpenRA {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'OpenRA'),
        (Join-Path $env:ProgramFiles 'OpenRA (playtest)'),
        (Join-Path ${env:ProgramFiles(x86)} 'OpenRA'),
        (Join-Path $env:LOCALAPPDATA 'Programs\OpenRA'),
        'D:\OpenRA', 'D:\Games\OpenRA', 'C:\OpenRA',
        (Join-Path $env:USERPROFILE 'Desktop\OpenRA')
    )
    foreach ($c in $candidates) {
        if ($null -eq $c) { continue }
        if (Test-Path -LiteralPath (Join-Path $c 'mods\ra\mod.yaml')) { return $c }
    }
    return $null
}

function Get-EngineVersion([string]$Root) {
    $vf = Join-Path $Root 'VERSION'
    if (Test-Path -LiteralPath $vf) {
        return (Get-Content -LiteralPath $vf -TotalCount 1).Trim()
    }
    return '(未知)'
}

function Assert-Target([string]$Root) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root 'mods\ra\mod.yaml'))) {
        throw "目标目录不像 OpenRA 安装目录：$Root（找不到 mods\ra\mod.yaml）"
    }
}

function Resolve-Target([string]$Given) {
    if ($Given) {
        if (-not (Test-Path -LiteralPath $Given)) { throw "目录不存在：$Given" }
        Assert-Target $Given
        return (Resolve-Path -LiteralPath $Given).Path
    }
    $auto = Find-OpenRA
    while ($true) {
        $hint = '请输入 OpenRA 安装目录（例如 D:\OpenRA）'
        if ($auto) { $hint = "检测到 $auto`n  直接回车使用它，或输入其它路径" }
        $input_ = Read-Host $hint
        if ($input_) { $auto = $input_.Trim('"').Trim("'") }
        if (-not $auto) { continue }
        if (-not (Test-Path -LiteralPath $auto)) { Write-Host "  目录不存在，请重试" -ForegroundColor Yellow; $auto = $null; continue }
        try { Assert-Target $auto; return (Resolve-Path -LiteralPath $auto).Path }
        catch { Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow; $auto = $null }
    }
}

$FontNames = @('NotoSansSC-Regular.ttf', 'NotoSansSC-Bold.ttf')

function Get-PayloadFiles {
    $list = @(
        Get-ChildItem -LiteralPath $FilesRoot -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($FilesRoot.Length).TrimStart('\')
            [pscustomobject]@{ Rel = $rel; Source = $_.FullName; Sha = (Get-Sha $_.FullName) }
        }
    )
    # 仓库检出场景：字体不入库（仓库约定「字体只放 fonts/」），回落到上一级 fonts/
    foreach ($n in $FontNames) {
        $rel = "mods\common\$n"
        if (Test-Path -LiteralPath (Join-Path $FilesRoot $rel)) { continue }
        $alt = Join-Path (Split-Path -Parent $PkgRoot) "fonts\$n"
        if (-not (Test-Path -LiteralPath $alt)) {
            throw "缺少中文字体 $n，且未在上级 fonts/ 找到。请改用 Releases 里的完整 zip。"
        }
        $list += [pscustomobject]@{ Rel = $rel; Source = $alt; Sha = (Get-Sha $alt) }
    }
    $list
}

function Invoke-Install([string]$Root) {
    Write-Title '安装汉化补丁'
    $ver = Get-EngineVersion $Root
    Write-Host "  目标目录 : $Root"
    Write-Host "  引擎版本 : $ver"
    if ($ver -ne 'release-20250330' -and -not $Force) {
        Write-Host ''
        Write-Host "  ⚠ 本补丁只针对官方稳定版 release-20250330 比对制作。" -ForegroundColor Yellow
        Write-Host "    当前版本是 $ver，可能导致文字对不上或功能异常。" -ForegroundColor Yellow
        $ans = Read-Host '  仍然继续？输入 Y 继续，其它键返回'
        if ($ans.Trim().ToUpper() -ne 'Y') { Write-Host '  已取消。' -ForegroundColor Yellow; return }
    }

    if (Get-Process -Name 'RedAlert', 'TiberianDawn', 'Dune2000', 'OpenRA.Server' -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host "  ⚠ 检测到 OpenRA 正在运行，请先完全关闭游戏再安装。" -ForegroundColor Red
        return
    }

    $payload = @(Get-PayloadFiles)
    $backupDir = Join-Path $Root ("_cn_backup\{0}" -f $Stamp)
    $entries = New-Object System.Collections.ArrayList

    foreach ($p in $payload) {
        $dst = Join-Path $Root $p.Rel
        $existed = Test-Path -LiteralPath $dst
        $shaBefore = ''
        if ($existed) {
            $shaBefore = Get-Sha $dst
            if (-not $DryRun) {
                $bk = Join-Path $backupDir $p.Rel
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bk) | Out-Null
                Copy-Item -LiteralPath $dst -Destination $bk -Force
            }
        }
        [void]$entries.Add([pscustomobject]@{
            path = $p.Rel; existedBefore = $existed; sha256Before = $shaBefore; sha256After = $p.Sha
        })
        if ($DryRun) {
            $tag = '覆盖'
            if (-not $existed) { $tag = '新增' }
            Write-Host ("  [预览] {0}  {1}" -f $tag, $p.Rel)
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
            Copy-Item -LiteralPath $p.Source -Destination $dst -Force
        }
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host ("  预览完成：共 {0} 个文件，未写入任何内容。" -f $payload.Count) -ForegroundColor Green
        return
    }

    $record = [pscustomobject]@{
        stamp        = $Stamp
        engineVersion = (Get-EngineVersion $Root)
        installedAt  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        target       = $Root
        files        = $entries
    }
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backupDir 'backup.json') -Encoding UTF8

    Write-Host ''
    Write-Host ("  完成：{0} 个文件已就位（其中新增 {1} 个、覆盖 {2} 个）。" -f `
        $payload.Count, ($entries | Where-Object { -not $_.existedBefore }).Count, ($entries | Where-Object { $_.existedBefore }).Count) -ForegroundColor Green
    Write-Host "  原文件备份在：$backupDir" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  现在启动游戏即可看到中文界面。想还原英文，重跑本脚本选 2。' -ForegroundColor Cyan
}

function Get-LatestBackup([string]$Root) {
    $bkRoot = Join-Path $Root '_cn_backup'
    if (-not (Test-Path -LiteralPath $bkRoot)) { return $null }
    $dirs = Get-ChildItem -LiteralPath $bkRoot -Directory | Sort-Object Name -Descending
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath (Join-Path $d.FullName 'backup.json')) { return $d.FullName }
    }
    return $null
}

function Invoke-Restore([string]$Root) {
    Write-Title '还原英文'
    if (Get-Process -Name 'RedAlert', 'TiberianDawn', 'Dune2000', 'OpenRA.Server' -ErrorAction SilentlyContinue) {
        Write-Host '  ⚠ 检测到 OpenRA 正在运行，请先关闭游戏。' -ForegroundColor Red
        return
    }
    $bk = Get-LatestBackup $Root
    if (-not $bk) {
        Write-Host '  没有找到本补丁的备份记录，无法自动还原。' -ForegroundColor Yellow
        Write-Host '  可重新安装官方安装包覆盖，或手动把 mods 目录恢复原状。' -ForegroundColor DarkGray
        return
    }
    Write-Host "  使用备份：$bk"
    $rec = Get-Content -LiteralPath (Join-Path $bk 'backup.json') -Raw | ConvertFrom-Json
    $restored = 0; $removed = 0
    foreach ($f in $rec.files) {
        $dst = Join-Path $Root $f.path
        if ($f.existedBefore) {
            $src = Join-Path $bk $f.path
            if (Test-Path -LiteralPath $src) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
                Copy-Item -LiteralPath $src -Destination $dst -Force
                $restored++
            }
        } else {
            if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force; $removed++ }
        }
    }
    Write-Host ''
    Write-Host ("  完成：恢复 {0} 个原文件，删除 {1} 个新增文件。" -f $restored, $removed) -ForegroundColor Green
    Write-Host '  备份目录保留未删，确认无误后可自行删除。' -ForegroundColor DarkGray
}

function Invoke-Verify([string]$Root) {
    Write-Title '校验安装状态'
    if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "缺少 bin\manifest.json，请重新解压发布包" }
    $man = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $ok = 0; $missing = 0; $changed = 0
    foreach ($f in $man.files) {
        $dst = Join-Path $Root $f.path
        if (-not (Test-Path -LiteralPath $dst)) { $missing++; continue }
        if ((Get-Sha $dst) -eq $f.sha256) { $ok++ } else { $changed++ }
    }
    Write-Host ("  目标目录 : {0}" -f $Root)
    Write-Host ("  引擎版本 : {0}" -f (Get-EngineVersion $Root))
    Write-Host ("  载荷总数 : {0}" -f $man.files.Count)
    Write-Host ("  已安装且完好 : {0}" -f $ok) -ForegroundColor Green
    if ($missing -gt 0) { Write-Host ("  文件缺失 : {0}" -f $missing) -ForegroundColor Yellow }
    if ($changed -gt 0) { Write-Host ("  与补丁不一致（原版或已被改动） : {0}" -f $changed) -ForegroundColor Yellow }
    $bk = Get-LatestBackup $Root
    if ($bk) { Write-Host ("  最近备份 : {0}" -f $bk) -ForegroundColor DarkGray }
    Write-Host ''
    if ($missing -eq 0 -and $changed -eq 0) {
        Write-Host '  结论：补丁完整在位（退出码 0）。' -ForegroundColor Green
        exit 0
    } else {
        Write-Host '  结论：补丁未装全或被改动（退出码 1）。' -ForegroundColor Yellow
        exit 1
    }
}

function Show-Menu {
    Write-Title 'OpenRA 简体中文补丁 · 适配稳定版 release-20250330'
    Write-Host '   1  安装中文补丁'
    Write-Host '   2  还原英文（用备份恢复）'
    Write-Host '   3  校验安装状态'
    Write-Host '   0  退出'
    Write-Host ''
}

# ---------------- 入口 ----------------
if (-not (Test-Path -LiteralPath $FilesRoot)) { throw "发布包不完整，缺少 files 目录" }

try {
    if ($Mode -eq 'Menu') {
        while ($true) {
            Show-Menu
            $choice = Read-Host '请输入数字'
            switch ($choice.Trim()) {
                '1' { $t = Resolve-Target $Target; Invoke-Install $t; Read-Host '按回车返回菜单' | Out-Null }
                '2' { $t = Resolve-Target $Target; Invoke-Restore $t; Read-Host '按回车返回菜单' | Out-Null }
                '3' { $t = Resolve-Target $Target; Invoke-Verify $t; Read-Host '按回车返回菜单' | Out-Null }
                '0' { return }
                default { }
            }
        }
    }
    $t = Resolve-Target $Target
    switch ($Mode) {
        'Install' { Invoke-Install $t }
        'Restore' { Invoke-Restore $t }
        'Verify'  { Invoke-Verify $t }
    }
}
catch {
    Write-Host ''
    Write-Host ("  出错了：{0}" -f $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception.Message -like '*denied*' -or $_.Exception.Message -like '*拒绝*') {
        Write-Host '  目标在 Program Files 下时，请右键脚本选「使用 PowerShell 运行」并以管理员身份执行。' -ForegroundColor Yellow
    }
    exit 1
}
