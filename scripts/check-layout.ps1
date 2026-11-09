#requires -Version 7.4
<#
.SYNOPSIS
    校验仓库顶层结构：只允许 README 里声明过的条目，且必需条目一个不少。
.DESCRIPTION
    白名单与 README「🧱 仓库结构」一节必须同步修改；新增顶层条目时两处一起改。
    以工作区为准（而非 git ls-files），这样提交前也能拦住未跟踪的新目录。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

# 顶层白名单（与 README「🧱 仓库结构」一致）
$allowed = @(
    '.gitattributes', '.gitignore', '.github', '.githooks',
    'AGENTS.md', 'DECISIONS.md', 'LICENSE', 'LICENSE-OFL.txt', 'MANIFEST.md',
    'README.md', 'TASKS.md', 'docs', 'files', 'fonts', 'scripts', 'src', 'tools'
)
$required = @('README.md', 'AGENTS.md', 'DECISIONS.md', 'TASKS.md', 'MANIFEST.md',
    'src', 'files', 'fonts', 'tools', 'scripts', 'docs')

# 构建产物与本地缓存不属于仓库结构
$ignored = @('dist', '_zhcn-backup', '.git', '.venv')

$top = @(Get-ChildItem -LiteralPath $root -Force |
    Where-Object { $ignored -notcontains $_.Name } |
    ForEach-Object { $_.Name } | Sort-Object -Unique)

$errors = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $top) {
    if ($allowed -notcontains $entry) {
        $errors.Add("未登记在 README 的顶层条目：$entry（新增顶层条目须同步 README 与 scripts/check-layout.ps1）")
    }
}
foreach ($entry in $required) {
    if ($top -notcontains $entry) { $errors.Add("缺少必需顶层条目：$entry") }
}

if ($errors.Count -eq 0) {
    Write-Host "  ✓ 顶层结构合规（$($top.Count) 项）" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
