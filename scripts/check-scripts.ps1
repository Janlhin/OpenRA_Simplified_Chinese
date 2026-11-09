#requires -Version 7.4
<#
.SYNOPSIS
    脚本执行基线：禁止 .bat/.cmd；所有 .ps1 必须能被 PowerShell 解析；files/ 内不得出现字体。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

$tracked = & git -C $root ls-files
if ($LASTEXITCODE -ne 0) { Write-Host '  ✗ git ls-files 失败' -ForegroundColor Red; exit 1 }

# 1) 禁止 .bat / .cmd
$legacy = @($tracked | Where-Object { $_ -match '\.(bat|cmd)$' })
if ($legacy.Count -gt 0) {
    foreach ($f in $legacy) { $errors.Add("禁止的脚本类型（Windows 侧一律 .ps1）：$f") }
}

# 2) .ps1 语法解析（扫工作区，未提交的新脚本也要被拦住）
$ps1 = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch '[\\/]dist[\\/]' })
$parseFailures = 0
foreach ($file in $ps1) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $parseFailures++
        $rel = $file.FullName.Substring($root.Length + 1)
        $first = $parseErrors[0]
        $errors.Add("PowerShell 语法错误：$rel 第 $($first.Extent.StartLineNumber) 行 — $($first.Message)")
    }
}

# 3) files/ 内不得出现字体
$fontsInPayload = @(Get-ChildItem -LiteralPath (Join-Path $root 'files') -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.ttf', '.ttc', '.otf' })
foreach ($f in $fontsInPayload) {
    $errors.Add("files/ 内出现字体文件：$($f.FullName.Substring($root.Length + 1))（字体只放 fonts/）")
}

if ($errors.Count -eq 0) {
    Write-Host "  ✓ 脚本基线合规（$($ps1.Count) 个 .ps1 解析通过，零 .bat/.cmd，files/ 无字体）" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
