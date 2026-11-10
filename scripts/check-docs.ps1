#requires -Version 7.4
<#
.SYNOPSIS
    校验五个治理文档的结构与必填字段，以及「规则单一载体」「不得双格式并存」。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Read-Text([string]$relative) {
    $p = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $p)) { throw "缺少文档：$relative" }
    return [System.IO.File]::ReadAllText($p)
}

function Get-Blocks {
    param([string[]]$Lines, [string]$Pattern)
    $blocks = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match $Pattern) {
            if ($null -ne $current) { $blocks.Add($current) }
            $current = [pscustomobject]@{ Title = $line; Body = [System.Collections.Generic.List[string]]::new() }
        }
        elseif ($null -ne $current) {
            $current.Body.Add($line)
        }
    }
    if ($null -ne $current) { $blocks.Add($current) }
    return $blocks
}

# 1) 五个文档必须存在
foreach ($doc in 'README.md', 'AGENTS.md', 'DECISIONS.md', 'TASKS.md', 'MANIFEST.md') {
    if (-not (Test-Path -LiteralPath (Join-Path $root $doc))) {
        $errors.Add("缺少五个必需文档之一：$doc")
    }
}

# 2) AGENTS.md ≤150 行，且必须引用验收入口
$agentsPath = Join-Path $root 'AGENTS.md'
if (Test-Path -LiteralPath $agentsPath) {
    $agentsLines = Get-Content -LiteralPath $agentsPath -Encoding utf8
    if ($agentsLines.Count -gt 150) {
        $errors.Add("AGENTS.md 有 $($agentsLines.Count) 行，超过 150 行上限（应拆分为独立文档并改为链接）")
    }
    if (-not ($agentsLines -match 'scripts/verify\.ps1')) {
        $errors.Add('AGENTS.md 未指出唯一验收入口 scripts/verify.ps1')
    }
}

# 3) 不得存在第二份规则载体
foreach ($carrier in '.cursorrules', 'CLAUDE.md', '.github/copilot-instructions.md') {
    $p = Join-Path $root $carrier
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $lines = @(Get-Content -LiteralPath $p -Encoding utf8 | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
    if ($lines.Count -gt 5 -or -not ($lines -match 'AGENTS\.md')) {
        $errors.Add("$carrier 违反规则单一载体：应只保留一行指向 AGENTS.md（当前 $($lines.Count) 行有效内容）")
    }
}

# 4) 不得同名 .md / .adoc 并存
$tracked = & git -C $root -c core.quotepath=false ls-files
foreach ($adoc in ($tracked | Where-Object { $_ -match '\.(adoc|asciidoc)$' })) {
    $md = [System.IO.Path]::ChangeExtension($adoc, '.md')
    if ($tracked -contains $md) {
        $errors.Add("$adoc 与 $md 同名并存：文档必须单一格式")
    }
}

# 5) DECISIONS.md 条目字段
$decisions = Get-Content -LiteralPath (Join-Path $root 'DECISIONS.md') -Encoding utf8
$decisionBlocks = Get-Blocks -Lines $decisions -Pattern '^###\s+D-'
if ($decisionBlocks.Count -eq 0) { $errors.Add('DECISIONS.md 没有任何 `### D-` 条目') }
foreach ($b in $decisionBlocks) {
    $text = ($b.Body -join "`n")
    foreach ($field in '决策', '背景', '被采纳', '被否决', '影响', '复审') {
        if ($text -notmatch "\*\*$field") {
            $errors.Add("DECISIONS.md 条目字段缺失：$($b.Title) 少了「$field」")
        }
    }
}

# 6) TASKS.md 条目字段 + 完成判据
$tasks = Get-Content -LiteralPath (Join-Path $root 'TASKS.md') -Encoding utf8
$taskBlocks = Get-Blocks -Lines $tasks -Pattern '^###\s+T-'
if ($taskBlocks.Count -eq 0) { $errors.Add('TASKS.md 没有任何 `### T-` 条目') }
foreach ($b in $taskBlocks) {
    $text = ($b.Body -join "`n")
    foreach ($field in '问题', '方法', '完成判据') {
        if ($text -notmatch "\*\*$field\*\*") {
            $errors.Add("TASKS.md 条目字段缺失：$($b.Title) 少了「$field」")
        }
    }
    if ($text -notmatch '退出码') {
        $errors.Add("TASKS.md 完成判据不可机器判定（未写退出码）：$($b.Title)")
    }
}
if (-not ($tasks -match '当前未决议清单')) {
    $errors.Add('TASKS.md 末尾缺少「当前未决议清单」')
}

# 7) MANIFEST.md 表格字段与哈希
#    主登记表 7 列；附表（如原版哈希对照）2 列，只做格式检查。
$manifestLines = Get-Content -LiteralPath (Join-Path $root 'MANIFEST.md') -Encoding utf8
$rows = @()
foreach ($line in ($manifestLines | Where-Object { $_ -match '^\|\s' -and $_ -notmatch '^\|\s*-+' -and $_ -notmatch '^\|\s*名称\s*\|' })) {
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -eq 2) { continue }   # 辅助表（哈希对照等），不参与登记校验
    $rows += ,$cells
}
if ($rows.Count -eq 0) { $errors.Add('MANIFEST.md 没有任何登记条目') }
foreach ($cells in $rows) {
    if ($cells.Count -ne 7) {
        $errors.Add("MANIFEST.md 表格列数应为 7，实际 $($cells.Count)：$($cells -join ' | ')")
        continue
    }
    $sha = $cells[3].Trim('`')
    $license = $cells[5]
    $bundled = $cells[6]
    if ([string]::IsNullOrWhiteSpace($license) -or $license -eq '—') {
        $errors.Add("MANIFEST.md 许可结论为空：$($cells[0])")
    }
    if ($bundled -eq '是' -and $sha -notmatch '^[0-9a-fA-F]{64}$') {
        $errors.Add("MANIFEST.md 随包制品缺少合法 SHA256：$($cells[0])")
    }
}

# 8) README 必填字段（技术栈 / 验收 / 已知限制）
$readme = Read-Text 'README.md'
foreach ($kw in '技术栈', '验收', '已知限制') {
    if ($readme -notmatch $kw) { $errors.Add("README.md 缺少必填内容：$kw") }
}

if ($errors.Count -eq 0) {
    Write-Host "  ✓ 五个文档结构完整（AGENTS $(($agentsLines).Count) 行，D-$($decisionBlocks.Count) / T-$($taskBlocks.Count) / MANIFEST $($rows.Count) 条）" -ForegroundColor DarkGreen
    exit 0
}

foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
exit 1
