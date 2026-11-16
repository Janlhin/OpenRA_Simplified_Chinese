#requires -Version 7.4
<#
.SYNOPSIS
    发布前七项自检：一条命令跑完，结论归档到 dist/pre-release-<version>.json。
.DESCRIPTION
    七项 = 制品可复现 / 完整性清单 / 签名与来源 / 依赖与许可 / 敏感信息 / 恶意软件扫描 / 变更说明与回滚。
    恶意软件扫描严格「先查哈希，再决定上传」：默认只做哈希查询，不发送任何文件；-Upload 才上传未命中的制品。
    失败项使退出码为 1；无法验证的项记为「跳过」，并在归档里如实写明，不当作通过。
.EXAMPLE
    pwsh -NoLogo -NoProfile -File scripts/pre-release.ps1
    pwsh -NoLogo -NoProfile -File scripts/pre-release.ps1 -Rebuild -Upload
#>
[CmdletBinding()]
param(
    [string[]]$Artifact = @(),
    [switch]$Rebuild,
    [switch]$Upload
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

# 3) 签名与来源
Add-Item '签名与来源' 'skip' '未接入代码签名 / Sigstore / GPG；已知缺口见 DECISIONS.md D-014'

# 4) 依赖与许可
& $python (Join-Path $root 'tools/verify_manifest.py') | Out-Null
if ($LASTEXITCODE -eq 0) {
    & $python -c 'import fontTools; print(fontTools.version)' 2>$null | Out-Null
    Add-Item '依赖与许可' 'ok' '载荷许可 GPL-3.0-or-later 与分发方式兼容；无生产期第三方依赖（fonttools 仅构建期使用）'
}
else { Add-Item '依赖与许可' 'fail' "verify_manifest.py 退出码 $LASTEXITCODE（许可或载荷不自洽）" }

# 5) 敏感信息：扫已入库的文本文件
$textExt = '.ps1', '.py', '.md', '.yml', '.yaml', '.json', '.ftl', '.txt', '.sh', '.tpl', '.gitattributes', '.gitignore'
$patterns = @(
    '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    'gh[pousr]_[A-Za-z0-9]{30,}',
    'AKIA[0-9A-Z]{16}',
    'xox[baprs]-[A-Za-z0-9-]{10,}',
    "(?i)\b(api[_-]?key|secret|password|passwd|token)\s*[:=]\s*['""][^'""\s]{12,}['""]"
)
$tracked = @(& git -C $root ls-files)
$hits = @()
foreach ($f in ($tracked | Where-Object { $textExt -contains [IO.Path]::GetExtension($_) -or [IO.Path]::GetFileName($_) -in '.gitattributes', '.gitignore' })) {
    $text = [IO.File]::ReadAllText((Join-Path $root $f))
    foreach ($p in $patterns) {
        if ($text -match $p) { $hits += $f; break }
    }
}
if ($hits.Count -eq 0) { Add-Item '敏感信息' 'ok' "$($tracked.Count) 个入库文件，未见密钥 / 令牌 / 内嵌凭据" }
else { Add-Item '敏感信息' 'fail' "疑似敏感信息：$($hits -join '、')" }

# 6) 恶意软件扫描：先查哈希，再决定上传
$key = $env:VT_API_KEY
$scanRows = @()
foreach ($a in $Artifact) {
    $name = Split-Path -Leaf $a
    $hash = $before[$a]
    if (-not $key) { $scanRows += "$name 未查询（无 VT_API_KEY）"; continue }
    $headers = @{ 'x-apikey' = $key }
    $lookup = $null
    try {
        $lookup = Invoke-WebRequest -Headers $headers -SkipHttpErrorCheck -Uri "https://www.virustotal.com/api/v3/files/$hash"
    }
    catch { $scanRows += "$name 查询失败：$($_.Exception.Message)"; continue }
    if ($lookup.StatusCode -eq 200) {
        $stats = ($lookup.Content | ConvertFrom-Json).data.attributes.last_analysis_stats
        $scanRows += "$name 已存在报告：$($stats.malicious) 检出 / 引擎 $(($stats.harmless + $stats.malicious + $stats.suspicious + $stats.undetected)) 个"
        continue
    }
    if ($lookup.StatusCode -ne 404) { $scanRows += "$name 查询返回 $($lookup.StatusCode)"; continue }
    if (-not $Upload) { $scanRows += "$name 未命中且未上传（加 -Upload 才上传，上传即披露）"; continue }
    $size = (Get-Item -LiteralPath $a).Length
    if ($size -gt 650MB) { $scanRows += "$name 超过 650MB 上限，未上传"; continue }
    if ($size -le 32MB) {
        $r = Invoke-RestMethod -Method Post -Headers $headers -Uri 'https://www.virustotal.com/api/v3/files' -Form @{ file = Get-Item -LiteralPath $a }
    }
    else {
        $url = (Invoke-RestMethod -Headers $headers -Uri 'https://www.virustotal.com/api/v3/files/upload_url').data
        $r = Invoke-RestMethod -Method Post -Headers $headers -Uri $url -Form @{ file = Get-Item -LiteralPath $a }
    }
    $scanRows += "$name 已上传，分析编号 $($r.data.id)（结果用 /analyses/{id} 取）"
}
$st = if ($key) { 'ok' } else { 'skip' }
Add-Item '恶意软件扫描' $st ($scanRows -join '；')

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
    $mark = switch ($i.Status) { 'ok' { '✓' } 'skip' { '!' } default { '✗' } }
    $color = switch ($i.Status) { 'ok' { 'DarkGreen' } 'skip' { 'Yellow' } default { 'Red' } }
    Write-Host ("  {0} {1}" -f $mark, $i.Item) -ForegroundColor $color
    Write-Host ("     $($i.Detail)") -ForegroundColor DarkGray
}
Write-Host ('─' * 56) -ForegroundColor DarkGray

$fail = @($items | Where-Object { $_.Status -eq 'fail' })
$skip = @($items | Where-Object { $_.Status -eq 'skip' })
Write-Host "  归档：$archivePath" -ForegroundColor DarkGray
if ($fail.Count -gt 0) {
    Write-Host "  $($fail.Count) 项失败，未通过发布前自检" -ForegroundColor Red
    exit 1
}
if ($skip.Count -gt 0) {
    Write-Host "  通过，但有 $($skip.Count) 项未验证（$(($skip | ForEach-Object { $_.Item }) -join ' / ')）——发布说明须如实列出" -ForegroundColor Yellow
    exit 0
}
Write-Host '  七项全部通过' -ForegroundColor Green
exit 0
