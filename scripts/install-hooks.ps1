#requires -Version 7.4
<#
.SYNOPSIS
    安装仓库自带的 Git 钩子（core.hooksPath 指向 .githooks）。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$hooksDir = Join-Path $root '.githooks'
if (-not (Test-Path -LiteralPath $hooksDir)) {
    Write-Host "  ✗ 找不到 $hooksDir" -ForegroundColor Red
    exit 1
}

& git -C $root config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { Write-Host '  ✗ 写入 core.hooksPath 失败' -ForegroundColor Red; exit 1 }

# 类 Unix 上补可执行位；Windows 忽略
if (-not $IsWindows) {
    foreach ($h in 'pre-commit', 'commit-msg') {
        $p = Join-Path $hooksDir $h
        if (Test-Path -LiteralPath $p) { & chmod +x $p }
    }
}

$current = & git -C $root config --get core.hooksPath
Write-Host "  ✓ 钩子已启用：core.hooksPath = $current" -ForegroundColor DarkGreen
Write-Host '    pre-commit → scripts/verify.ps1 -Fast' -ForegroundColor DarkGray
Write-Host '    commit-msg → scripts/check-commit-msg.ps1' -ForegroundColor DarkGray
exit 0
