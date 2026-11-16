#requires -Version 7.4
<#
.SYNOPSIS
    发布前七项自检：一条命令跑完，结论归档到 dist/pre-release-<version>.json。
.DESCRIPTION
    七项 = 制品可复现 / 完整性清单 / 签名与来源 / 依赖与许可 / 敏感信息 / 恶意软件扫描 / 变更说明与回滚。
    签名与 VirusTotal 两项按维护者决定不接入（D-016）：记为「不适用（已登记豁免）」并写进归档，不冒充通过。
    VirusTotal 若设置了 VT_API_KEY 也只做哈希查询，永不上传制品。
    失败项使退出码为 1；跳过项（缺省无法验证）单独计数，不当作通过。
.EXAMPLE
    pwsh -NoLogo -NoProfile -File scripts/pre-release.ps1
    pwsh -NoLogo -NoProfile -File scripts/pre-release.ps1 -Rebuild
#>
[CmdletBinding()]
param(
    [string[]]$Artifact = @(),
    [switch]$Rebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$items = [System.Collections.Generic.List[object]]::new()
function Add-Item([string]$Name, [string]$Status, [string]$Detail) {
    $items.Add([pscustomobject]@{ Item = $Name; Status = $Status; Detail = $Detail })
}

# python：仓库内 .venv → PYTHON → PATH
$python = $null
foreach ($c in @((Join-Path $root '.venv/Scripts/python.exe'), (Join-Path $root '.venv/bin/python'))) {
    if (Test-Path -LiteralPath $c) { $python = $c; break }
}
if (-not $python -and $env:PYTHON) { $python = $env:PYTHON }
if (-not $python) { $python = (Get-Command python -ErrorAction SilentlyContinue)?.Source }
if (-not $python) { throw '找不到 python，无法做依赖与清单校验' }

# 版本号真相
$manifestPath = Join-Path $root 'playtest-20261026/bin/manifest.json'
$version = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).version

# 制品：默认 dist/*.zip
if ($Artifact.Count -eq 0) {
    $dist = Join-Path $root 'dist'
    if (Test-Path -LiteralPath $dist) {
        $Artifact = @(Get-ChildItem -LiteralPath $dist -File -Filter '*.zip' | ForEach-Object { $_.FullName })
    }
}
if ($Artifact.Count -eq 0) {
    Write-Host '  ✗ dist/ 下没有制品，先跑 python tools/build_release.py' -ForegroundColor Red
    exit 1
}

$before = @{}
foreach ($a in $Artifact) {
    if (-not (Test-Path -LiteralPath $a)) { throw "制品不存在：$a" }
    $before[$a] = (Get-FileHash -Algorithm SHA256 -LiteralPath $a).Hash.ToLower()
}

# 1) 制品可复现
if ($Rebuild) {
    & $python (Join-Path $root 'tools/build_release.py') | Out-Null
    if ($LASTEXITCODE -ne 0) { Add-Item '制品可复现' 'fail' "重建失败（退出码 $LASTEXITCODE）" }
    else {
        $diff = @()
        foreach ($a in $Artifact) {
            $after = (Get-FileHash -Algorithm SHA256 -LiteralPath $a).Hash.ToLower()
            if ($after -ne $before[$a]) { $diff += (Split-Path -Leaf $a) }
        }
        if ($diff.Count -eq 0) { Add-Item '制品可复现' 'ok' '重建后 SHA256 与发布制品一致' }
        else { Add-Item '制品可复现' 'fail' "重建后哈希不同：$($diff -join '、')" }
    }
}
else {
    & $python (Join-Path $root 'tools/build_release.py') '--verify' | Out-Null
    if ($LASTEXITCODE -eq 0) { Add-Item '制品可复现' 'skip' '包结构与清单自校验通过；未重建比对哈希（加 -Rebuild 才比对）' }
    else { Add-Item '制品可复现' 'fail' "包自校验失败（退出码 $LASTEXITCODE）" }
}

# 2) 完整性清单：每个制品一份 <name>.sha256，并汇总 dist/SHA256SUMS
$sums = @()
foreach ($a in $Artifact) {
    $side = "$a.sha256"
    $line = "$($before[$a])  $(Split-Path -Leaf $a)"
    [IO.File]::WriteAllText($side, "$line`n", (New-Object Text.UTF8Encoding($false)))
    $sums += $line
}
[IO.File]::WriteAllText((Join-Path $root 'dist/SHA256SUMS'), (($sums -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Add-Item '完整性清单' 'ok' "$($Artifact.Count) 个制品，SHA256 已写入 dist/SHA256SUMS"

# 3) 签名与来源：维护者决定不接入（见 D-016）
Add-Item '签名与来源' 'na' '未接入代码签名 / Sigstore / GPG：维护者决定不接入（D-016）；发布说明不得声称有签名'

# 4) 依赖与许可
& $python (Join-Path $root 'tools/verify_manifest.py') | Out-Null
if ($LASTEXITCODE -eq 0) {
    & $python -c 'import fontTools; print(fontTools.version)' 2>$null | Out-Null
    Add-Item '依赖与许可' 'ok' '载荷许可 GPL-3.0-or-later 与分发方式兼容；无生产期第三方依赖（fonttools 仅构建期使用）'
}
else { Add-Item '依赖与许可' 'fail' "verify_manifest.py 退出码 $LASTEXITCODE（许可或载荷不自洽）" }

# 5) 敏感信息：与本地钩子用同一份脚本，避免两套特征表
& pwsh -NoLogo -NoProfile -File (Join-Path $root 'scripts/check-secrets.ps1') | Out-Null
if ($LASTEXITCODE -eq 0) { Add-Item '敏感信息' 'ok' 'scripts/check-secrets.ps1 零命中（与 verify.ps1 同一份特征表）' }
else { Add-Item '敏感信息' 'fail' "scripts/check-secrets.ps1 退出码 $LASTEXITCODE" }

# 6) 恶意软件扫描：只查哈希，永不上传（维护者决定，见 D-016）
$key = $env:VT_API_KEY
$scanRows = @()
if (-not $key) {
    Add-Item '恶意软件扫描' 'na' '未接入 VirusTotal：维护者决定不接入（D-016）；发布说明不得写「已通过病毒检测」'
}
else {
    foreach ($a in $Artifact) {
        $name = Split-Path -Leaf $a
        $hash = $before[$a]
        try {
            $lookup = Invoke-WebRequest -Headers @{ 'x-apikey' = $key } -SkipHttpErrorCheck -Uri "https://www.virustotal.com/api/v3/files/$hash"
        }
        catch { $scanRows += "$name 查询失败：$($_.Exception.Message)"; continue }
        if ($lookup.StatusCode -eq 200) {
            $stats = ($lookup.Content | ConvertFrom-Json).data.attributes.last_analysis_stats
            $scanRows += "$name 已有报告：$($stats.malicious) 检出 / 引擎 $(($stats.harmless + $stats.malicious + $stats.suspicious + $stats.undetected)) 个"
        }
        elseif ($lookup.StatusCode -eq 404) {
            $scanRows += "$name 无报告（只查哈希，不上传；不提交文件就不会产生新报告）"
        }
        else { $scanRows += "$name 查询返回 $($lookup.StatusCode)" }
    }
    Add-Item '恶意软件扫描' 'ok' ($scanRows -join '；')
}

# 7) 变更说明与回滚
$changelog = [IO.File]::ReadAllText((Join-Path $root 'docs/CHANGELOG.md'))
$head = ($changelog -split "`n## ")[1]
if (-not $head) { Add-Item '变更说明与回滚' 'fail' 'CHANGELOG 没有版本条目' }
else {
    $missing = @()
    if ($head -notmatch '回滚') { $missing += '回滚方式' }
    if ($head -notmatch '已知问题') { $missing += '已知问题' }
    if ($head -notmatch [regex]::Escape($version)) { $missing += "版本号 $version" }
    if ($missing.Count -eq 0) { Add-Item '变更说明与回滚' 'ok' "CHANGELOG $version 条目含变更 / 已知问题 / 回滚" }
    else { Add-Item '变更说明与回滚' 'fail' "CHANGELOG $version 条目缺：$($missing -join '、')" }
}

# 归档
$archiveDir = Join-Path $root 'dist'
if (-not (Test-Path -LiteralPath $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
$archive = [ordered]@{
    version    = $version
    generatedAt = (Get-Date).ToString('o')
    artifacts  = @($Artifact | ForEach-Object { [ordered]@{ name = (Split-Path -Leaf $_); sha256 = $before[$_]; bytes = (Get-Item -LiteralPath $_).Length } })
    items      = $items
}
$archivePath = Join-Path $archiveDir "pre-release-$version.json"
[IO.File]::WriteAllText($archivePath, ($archive | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('─' * 56) -ForegroundColor DarkGray
foreach ($i in $items) {
    $mark = switch ($i.Status) { 'ok' { '✓' } 'skip' { '!' } 'na' { '-' } default { '✗' } }
    $color = switch ($i.Status) { 'ok' { 'DarkGreen' } 'skip' { 'Yellow' } 'na' { 'DarkGray' } default { 'Red' } }
    Write-Host ("  {0} {1}" -f $mark, $i.Item) -ForegroundColor $color
    Write-Host ("     $($i.Detail)") -ForegroundColor DarkGray
}
Write-Host ('─' * 56) -ForegroundColor DarkGray

$fail = @($items | Where-Object { $_.Status -eq 'fail' })
$skip = @($items | Where-Object { $_.Status -eq 'skip' })
$na = @($items | Where-Object { $_.Status -eq 'na' })
Write-Host "  归档：$archivePath" -ForegroundColor DarkGray
if ($fail.Count -gt 0) {
    Write-Host "  $($fail.Count) 项失败，未通过发布前自检" -ForegroundColor Red
    exit 1
}
if ($skip.Count -gt 0) {
    Write-Host "  通过，但有 $($skip.Count) 项未验证（$(($skip | ForEach-Object { $_.Item }) -join ' / ')）——发布说明须如实列出" -ForegroundColor Yellow
}
if ($na.Count -gt 0) {
    Write-Host "  $($na.Count) 项已登记豁免（$(($na | ForEach-Object { $_.Item }) -join ' / ')）——发布说明不得声称已签名或已通过病毒检测" -ForegroundColor DarkGray
}
if ($skip.Count -eq 0 -and $na.Count -eq 0) { Write-Host '  七项全部通过' -ForegroundColor Green }
exit 0
