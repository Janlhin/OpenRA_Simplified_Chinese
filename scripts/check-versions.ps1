#requires -Version 7.4
<#
.SYNOPSIS
    校验版本号：SemVer 2.0.0 合法性 + 三处一致性 +（在 tag 上时）tag 与版本一致。
.DESCRIPTION
    单一真相是 src/manifest.json 的 version；docs/CHANGELOG.md 顶层标题与
    src/安装说明.md 首行为派生值。规则见 docs/VERSIONING.md。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

$semver = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)?(?:\+[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)?$'

# 1) 真相源
$manifestPath = Join-Path $root 'src/manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
$version = [string]$manifest.version
$releaseDate = [string]$manifest.releaseDate

if ($version -notmatch $semver) {
    $errors.Add("src/manifest.json: version '$version' 不是合法 SemVer 2.0.0")
}

# 2) CHANGELOG 顶层条目
$changelogPath = Join-Path $root 'docs/CHANGELOG.md'
$heading = Get-Content -LiteralPath $changelogPath -Encoding utf8 |
    Where-Object { $_ -match '^##\s+\S' } | Select-Object -First 1

if (-not $heading) {
    $errors.Add('docs/CHANGELOG.md: 找不到顶层版本条目（形如 `## 1.6.0 — 2026-11-04`）')
}
elseif ($heading -match '^##\s+(\S+)\s+—\s+(\d{4}-\d{2}-\d{2})') {
    $clVersion = $Matches[1]
    $clDate = $Matches[2]
    if ($clVersion -ne $version) {
        $errors.Add("docs/CHANGELOG.md: 顶层版本 $clVersion 与 manifest 的 $version 不一致")
    }
    if ($releaseDate -and $clDate -ne $releaseDate) {
        $errors.Add("docs/CHANGELOG.md: 日期 $clDate 与 manifest.releaseDate $releaseDate 不一致")
    }
}
else {
    $errors.Add("docs/CHANGELOG.md: 顶层标题格式不合规：'$heading'（应为 `## X.Y.Z — YYYY-MM-DD`）")
}

# 3) 安装说明首行标题
$installDocPath = Join-Path $root 'src/安装说明.md'
$titleLine = Get-Content -LiteralPath $installDocPath -Encoding utf8 -TotalCount 1
if ($titleLine -match '(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\s*$') {
    $docVersion = $Matches[1]
    if ($docVersion -ne $version) {
        $errors.Add("src/安装说明.md: 首行版本 $docVersion 与 manifest 的 $version 不一致")
    }
}
else {
    $errors.Add("src/安装说明.md: 首行未找到版本号：'$titleLine'")
}

# 4) tag 与版本（仅在 tag 指向 HEAD 时校验）
Push-Location $root
try {
    $tag = & git describe --tags --exact-match 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) {
        $tag = $tag.Trim()
        if ($tag -ne "v$version") {
            $errors.Add("当前 HEAD 的 tag 是 $tag，与 v$version 不一致（tag 已推送不得修改，改版本号发新 tag）")
        }
    }
}
finally { Pop-Location }

if ($errors.Count -eq 0) {
    Write-Host "  ✓ 版本号 $version（$releaseDate）三处一致" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
