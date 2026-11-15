<#
.SYNOPSIS
    可选引擎热修复：修复 playtest-20261026 下中文战役简报导致的闪退。
.DESCRIPTION
    - 仅在你自己安装的 OpenRA 目录内替换两个引擎程序集，不改游戏逻辑与美术音频。
    - 替换前校验目标 DLL 的 SHA256：只接受「官方原版」或「已打过补丁」两种状态，
      其它一律中止，避免覆盖到别的引擎版本。
    - 首次替换前把原版备份为 *.orig-20261109，rollback-hotfix.ps1 可一键还原。
    - 需要管理员权限（写入 Program Files）。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File apply-hotfix.ps1
    powershell -ExecutionPolicy Bypass -File apply-hotfix.ps1 -Target "D:\Games\OpenRA"
#>
[CmdletBinding()]
param(
    [string]$Target = 'C:\Program Files\OpenRA (playtest)'
)

$ErrorActionPreference = 'Stop'

# 官方原版 / 已打补丁的 SHA256
$files = @(
    @{ Name = 'OpenRA.Game.dll';        Original = '4182e606f7da23095d649406c5eb65840888d6b548849f6a9b9d0b8ff8003597'; Patched = '105e0003cccadd44c4bd711a1920a8d0f3329504b2c2403281392d89b67d9948' }
    @{ Name = 'OpenRA.Mods.Common.dll'; Original = '1cf381887df9b52ddfdf6d9fc5f8ab613a9b928ff145103cd3297af5c08cab38'; Patched = '1faf14403e0c65ed83be1d7efc7b7ac1a3ffb1462c5934e5ab1ddd92e22cd1ea' }
)

$here = Split-Path -Parent $PSCommandPath

function Test-TargetWritable([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return $false }
    $probe = Join-Path $dir ('.cn-write-test-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($probe, 'x')
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

# 只有目标目录不可写（如 Program Files）才需要提权；自建目录直接跑即可
if (-not (Test-TargetWritable $Target)) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host '正在请求管理员权限，请在 UAC 窗口点「是」...'
        $exe = (Get-Process -Id $PID).Path
        Start-Process -FilePath $exe -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'),
            '-Target', ('"' + $Target + '"')
        )
        exit
    }
}

function Get-Sha256([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}

Write-Host ''
Write-Host ('目标目录：' + $Target) -ForegroundColor Cyan
Write-Host ''

$applied = 0
$skipped = 0

foreach ($f in $files) {
    $src = Join-Path $here $f.Name
    $dst = Join-Path $Target $f.Name
    $bak = $dst + '.orig-20261109'

    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host ('[跳过] 热修文件缺失：' + $f.Name) -ForegroundColor Yellow
        continue
    }
    if (-not (Test-Path -LiteralPath $dst)) {
        throw ('在目标目录找不到 ' + $f.Name + '，请用 -Target 指定你的 OpenRA 安装目录')
    }

    $current = Get-Sha256 $dst
    if ($current -eq $f.Patched) {
        Write-Host ('[已应用] ' + $f.Name + ' 已是热修版本，跳过') -ForegroundColor DarkGray
        $skipped++
        continue
    }
    if ($current -ne $f.Original) {
        throw ($f.Name + ' 的哈希既不是官方原版也不是热修版本（可能是别的引擎版本或已被改动），已中止，未做任何修改')
    }

    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $dst -Destination $bak -Force
        Write-Host ('[备份] ' + $f.Name + ' -> ' + (Split-Path -Leaf $bak))
    }

    Copy-Item -LiteralPath $src -Destination $dst -Force
    $after = Get-Sha256 $dst
    if ($after -ne $f.Patched) {
        throw ($f.Name + ' 覆盖后哈希校验失败，请从 ' + (Split-Path -Leaf $bak) + ' 还原')
    }
    Write-Host ('[完成] ' + $f.Name + '  ' + $after) -ForegroundColor Green
    $applied++
}

Write-Host ''
if ($applied -gt 0) {
    Write-Host ('热修复已应用（' + $applied + ' 个文件）。现在可以启动游戏进「战役」验证。') -ForegroundColor Green
}
else {
    Write-Host '没有需要修改的文件。' -ForegroundColor DarkGray
}
if ($skipped -gt 0) {
    Write-Host ('其中 ' + $skipped + ' 个此前已经打过热修。') -ForegroundColor DarkGray
}
Write-Host '想还原：运行同目录的 rollback-hotfix.ps1' -ForegroundColor DarkGray

Write-Host ''
Read-Host '按回车关闭' | Out-Null
