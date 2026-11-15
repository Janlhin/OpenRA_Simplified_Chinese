#requires -Version 7.4
<#
.SYNOPSIS
    校验版本号：SemVer 2.0.0 合法性、两条产品线统一版号、三处一致，以及在 tag 上时 tag 与版本一致。
.DESCRIPTION
    仓库里每条产品线各占一个目录（`playtest-YYYYMMDD/`、`release-YYYYMMDD/`），
    每条的真相源是 `bin/manifest.json` 的 `version`；**两条线必须是同一个版本号**
    （统一版号，方便管理：2.0.0 同时指两条线这一次的发布）。
    派生值：`docs/CHANGELOG.md` 顶层标题、各线 `安装说明.md` 首行。规则见 docs/VERSIONING.md。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

$semver = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)?(?:\+[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)?$'

# 1) 各条产品线：目录名 = 目标引擎，目录里的 bin/manifest.json 是这一条的真相源
$lineDirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(playtest|release)-\d{8}$' } |
    Sort-Object Name)

if ($lineDirs.Count -eq 0) {
    $errors.Add('仓库根下找不到任何产品线目录（应为 playtest-YYYYMMDD/ 或 release-YYYYMMDD/）')
}

$lines = @()
foreach ($dir in $lineDirs) {
    $lineManifest = Join-Path $dir.FullName 'bin/manifest.json'
    if (-not (Test-Path -LiteralPath $lineManifest)) {
        $errors.Add("$($dir.Name)/bin/manifest.json: 该产品线缺少清单")
        continue
    }
    $m = Get-Content -LiteralPath $lineManifest -Raw -Encoding utf8 | ConvertFrom-Json
    $lineVersion = [string]$m.version
    $lineDate = [string]$m.releaseDate

    if ($lineVersion -notmatch $semver) {
        $errors.Add("$($dir.Name)/bin/manifest.json: version '$lineVersion' 不是合法 SemVer 2.0.0（不存在两位号，2.0 只能写 2.0.0）")
    }
    # 目录名必须与 engineVersion 对应，防止错标引擎
    if ([string]$m.engineVersion -ne $dir.Name) {
        $errors.Add("$($dir.Name)/bin/manifest.json: engineVersion '$($m.engineVersion)' 与目录名 '$($dir.Name)' 不一致")
    }
    # 两条线的清单必须同 schema（同一套安装器只认这一份）
    if (-not $m.releaseDate -or -not $m.font -or -not $m.files) {
        $errors.Add("$($dir.Name)/bin/manifest.json: 缺少 releaseDate / font / files")
    }
    # 各线安装说明首行版本号
    $doc = Join-Path $dir.FullName '安装说明.md'
    if (-not (Test-Path -LiteralPath $doc)) {
        $errors.Add("$($dir.Name)/安装说明.md: 文件不存在")
    }
    else {
        $titleLine = Get-Content -LiteralPath $doc -Encoding utf8 -TotalCount 1
        # 首行里出现的第一处三段版本号即为该线的声明版本（标题措辞不限，可带引擎说明）
        if ($titleLine -match '(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)') {
            if ($Matches[1] -ne $lineVersion) {
                $errors.Add("$($dir.Name)/安装说明.md: 首行版本 $($Matches[1]) 与该线 manifest 的 $lineVersion 不一致")
            }
        }
        else {
            $errors.Add("$($dir.Name)/安装说明.md: 首行未找到版本号：'$titleLine'")
        }
    }

    $lines += [pscustomobject]@{ Line = $dir.Name; Version = $lineVersion; Date = $lineDate }
}

# 2) 统一版号：所有线必须是同一个 version / releaseDate
$version = $null
$releaseDate = $null
if ($lines.Count -gt 0) {
    $version = $lines[0].Version
    $releaseDate = $lines[0].Date
    foreach ($line in $lines) {
        if ($line.Version -ne $version) {
            $errors.Add("统一版号被破坏：$($line.Line) 写的是 $($line.Version)，$($lines[0].Line) 写的是 $version")
        }
        if ($line.Date -ne $releaseDate) {
            $errors.Add("统一发布日被破坏：$($line.Line) 写的是 $($line.Date)，$($lines[0].Line) 写的是 $releaseDate")
        }
    }
}

# 3) CHANGELOG 顶层条目
$changelogPath = Join-Path $root 'docs/CHANGELOG.md'
$heading = Get-Content -LiteralPath $changelogPath -Encoding utf8 |
    Where-Object { $_ -match '^##\s+\S' } | Select-Object -First 1

if (-not $heading) {
    $errors.Add('docs/CHANGELOG.md: 找不到顶层版本条目（形如 `## 2.0.0 — 2026-11-15`）')
}
elseif ($heading -match '^##\s+(\S+)\s+—\s+(\d{4}-\d{2}-\d{2})') {
    $clVersion = $Matches[1]
    $clDate = $Matches[2]
    if ($clVersion -ne $version) {
        $errors.Add("docs/CHANGELOG.md: 顶层版本 $clVersion 与各线 manifest 的 $version 不一致")
    }
    if ($releaseDate -and $clDate -ne $releaseDate) {
        $errors.Add("docs/CHANGELOG.md: 日期 $clDate 与 manifest.releaseDate $releaseDate 不一致")
    }
}
else {
    $errors.Add("docs/CHANGELOG.md: 顶层标题格式不合规：'$heading'（应为 `## X.Y.Z — YYYY-MM-DD`）")
}

# 4) tag 与版本：统一版号之后一个 tag 只对应一个版本号，不存在"分包另记"的例外
Push-Location $root
try {
    $tag = & git describe --tags --exact-match 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) {
        $tag = $tag.Trim()
        if ($tag -ne "v$version") {
            $errors.Add("当前 HEAD 的 tag 是 $tag，与统一版号 v$version 不一致（tag 已推送不得修改，改版本号发新 tag）")
        }
    }
}
finally { Pop-Location }

if ($errors.Count -eq 0) {
    $lineList = ($lines | ForEach-Object { "$($_.Line)=$($_.Version)" }) -join '、'
    Write-Host "  ✓ 统一版号 $version（$releaseDate）：$lineList" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
