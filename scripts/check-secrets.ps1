#requires -Version 7.4
<#
.SYNOPSIS
    敏感信息扫描：入库文本文件里不得出现密钥、令牌、内嵌凭据。
.DESCRIPTION
    只扫 git ls-files 里登记的文本文件（二进制与 dist/ 不参与），命中任何一条特征即退出码 1。
    特征表是单一的：本地钩子（verify）与发布前自检（pre-release）都调用本脚本，不各写一份。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tracked = @(& git -C $root ls-files)
if ($LASTEXITCODE -ne 0) { Write-Host '  ✗ git ls-files 失败' -ForegroundColor Red; exit 1 }

$textExt = '.ps1', '.py', '.md', '.yml', '.yaml', '.json', '.ftl', '.txt', '.sh', '.tpl', '.adoc'
$patterns = @(
    '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    'gh[pousr]_[A-Za-z0-9]{30,}',
    'AKIA[0-9A-Z]{16}',
    'xox[baprs]-[A-Za-z0-9-]{10,}',
    "(?i)\b(api[_-]?key|secret|password|passwd|token)\s*[:=]\s*['""][^'""\s]{12,}['""]"
)

$hits = @()
$scanned = 0
foreach ($f in $tracked) {
    $name = [IO.Path]::GetFileName($f)
    if (-not ($textExt -contains [IO.Path]::GetExtension($f))) {
        if ($name -ne '.gitattributes' -and $name -ne '.gitignore') { continue }
    }
    $path = Join-Path $root $f
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $scanned++
    $text = [IO.File]::ReadAllText($path)
    foreach ($p in $patterns) {
        if ($text -match $p) { $hits += $f; break }
    }
}

if ($hits.Count -eq 0) {
    Write-Host "  ✓ 敏感信息扫描通过（$scanned 个入库文本文件，零命中）" -ForegroundColor DarkGreen
    exit 0
}
foreach ($h in $hits) { Write-Host "  ✗ 疑似敏感信息：$h" -ForegroundColor Red }
exit 1
