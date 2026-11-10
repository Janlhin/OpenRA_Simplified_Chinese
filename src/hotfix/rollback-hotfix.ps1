<#
.SYNOPSIS
    还原引擎热修复：把 apply-hotfix.ps1 替换过的两个 DLL 恢复成官方原版。
.DESCRIPTION
    从 *.orig-20261109 备份还原，并校验还原后的哈希与官方原版一致。
    上游 OpenRA 修复该缺陷并发布新版本后，可以直接删掉 hotfix 目录，不必再还原。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File rollback-hotfix.ps1
    powershell -ExecutionPolicy Bypass -File rollback-hotfix.ps1 -Target "D:\Games\OpenRA"
#>
[CmdletBinding()]
param(
    [string]$Target = 'C:\Program Files\OpenRA (playtest)'
)

$ErrorActionPreference = 'Stop'

$files = @(
    @{ Name = 'OpenRA.Game.dll';        Original = '4182e606f7da23095d649406c5eb65840888d6b548849f6a9b9d0b8ff8003597'; Patched = '105e0003cccadd44c4bd711a1920a8d0f3329504b2c2403281392d89b67d9948' }
    @{ Name = 'OpenRA.Mods.Common.dll'; Original = '1cf381887df9b52ddfdf6d9fc5f8ab613a9b928ff145103cd3297af5c08cab38'; Patched = '1faf14403e0c65ed83be1d7efc7b7ac1a3ffb1462c5934e5ab1ddd92e22cd1ea' }
)

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

function Get-Sha256([string]$path) {
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
}

$restored = 0
foreach ($f in $files) {
    $dst = Join-Path $Target $f.Name
    $bak = $dst + '.orig-20261109'

    if (-not (Test-Path -LiteralPath $bak)) {
        Write-Host ('[跳过] 没有备份：' + (Split-Path -Leaf $bak)) -ForegroundColor Yellow
        continue
    }
    if (-not (Test-Path -LiteralPath $dst)) {
        throw ('在目标目录找不到 ' + $f.Name + '，请用 -Target 指定你的 OpenRA 安装目录')
    }

    Copy-Item -LiteralPath $bak -Destination $dst -Force
    $after = Get-Sha256 $dst
    if ($after -ne $f.Original) {
        throw ($f.Name + ' 还原后哈希与官方原版不一致，请手动核对')
    }
    Write-Host ('[还原] ' + $f.Name + '  ' + $after) -ForegroundColor Green
    $restored++
}

Write-Host ''
if ($restored -gt 0) {
    Write-Host ('已还原 ' + $restored + ' 个文件为官方原版。') -ForegroundColor Green
}
else {
    Write-Host '没有可还原的备份（可能从未应用过热修）。' -ForegroundColor DarkGray
}

Write-Host ''
Read-Host '按回车关闭' | Out-Null
