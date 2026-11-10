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

# 4) 纯 CMD 模板：非 ASCII 会拆坏 cmd.exe 的行解析；不得调用任何 PS 宿主；
#    模板里的 DLL 哈希必须与热修 PS1 同源（tools/build_release.py 打包时还会再查一次）
$tplDir = Join-Path $root 'tools/cmd-templates'
$tpls = @(Get-ChildItem -LiteralPath $tplDir -File -Filter '*.tpl' -ErrorAction SilentlyContinue)
if ($tpls.Count -ne 3) { $errors.Add("CMD 模板应为 3 个，实际 $($tpls.Count) 个") }
$hotfixPs1 = [System.IO.File]::ReadAllText((Join-Path $root 'src/hotfix/apply-hotfix.ps1'))
foreach ($t in $tpls) {
    $bytes = [System.IO.File]::ReadAllBytes($t.FullName)
    if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) {
        $errors.Add("CMD 模板必须是纯 ASCII：$($t.Name)（cmd.exe 会拆坏中文行）")
    }
    $text = [System.IO.File]::ReadAllText($t.FullName)
    if ($text -match '(?i)powershell|pwsh') {
        $errors.Add("CMD 模板不得调用 PS 宿主：$($t.Name)")
    }
    foreach ($m in [regex]::Matches($text, '\b[0-9a-f]{64}\b')) {
        if (-not $hotfixPs1.Contains($m.Value)) {
            $errors.Add("CMD 模板哈希与 apply-hotfix.ps1 不一致：$($t.Name) / $($m.Value)")
        }
    }
}

if ($errors.Count -eq 0) {
    Write-Host "  ✓ 脚本基线合规（$($ps1.Count) 个 .ps1 解析通过，零 .bat/.cmd，$($tpls.Count) 个纯 CMD 模板，files/ 无字体）" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
