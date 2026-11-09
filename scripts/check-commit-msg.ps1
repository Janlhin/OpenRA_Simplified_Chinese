#requires -Version 7.4
<#
.SYNOPSIS
    提交信息门禁：Conventional Commits + 禁止无信息量标题 + 提交规模提示。
.NOTES
    由 .githooks/commit-msg 调用，参数是 Git 传入的消息文件路径。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MessageFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$raw = Get-Content -LiteralPath $MessageFile -Encoding utf8
$lines = @($raw | Where-Object { -not $_.TrimStart().StartsWith('#') })
while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[-1])) {
    $lines = @($lines[0..($lines.Count - 2)])
}
if ($lines.Count -eq 0) { exit 0 }   # merge / 空消息交给 Git 自己处理

$subject = $lines[0].Trim()
if ($subject -match '^(Merge |Revert |fixup! |squash! )') { exit 0 }

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$pattern = '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\([^)]+\))?!?:\s+\S.*$'
if ($subject -notmatch $pattern) {
    $errors.Add('标题不符合 Conventional Commits：<type>(<scope>): <说明>（type 取 feat/fix/docs/style/refactor/perf/test/build/ci/chore）')
}

$vague = @('update', 'updates', 'fix bug', 'bugfix', 'changes', 'wip', '小改动', '修改', '更新', '修复一下')
if ($vague -contains $subject.ToLowerInvariant()) {
    $errors.Add("标题没有信息量：'$subject'（写清改了什么、为什么）")
}

$subjectLen = $subject.Length
if ($subjectLen -gt 100) {
    $errors.Add("标题过长（$subjectLen 字符），建议 ≤72")
}
elseif ($subjectLen -gt 72) {
    $warnings.Add("标题 $subjectLen 字符，超过建议的 72")
}

# 提交规模提示（仅警告）
Push-Location $root
try {
    $numstat = & git diff --cached --numstat 2>$null
    if ($LASTEXITCODE -eq 0 -and $numstat) {
        $changed = 0
        foreach ($line in $numstat) {
            $parts = $line -split "`t"
            if ($parts.Count -ge 2 -and $parts[0] -match '^\d+$') { $changed += [int]$parts[0] }
            if ($parts.Count -ge 2 -and $parts[1] -match '^\d+$') { $changed += [int]$parts[1] }
        }
        if ($changed -gt 400) {
            $warnings.Add("本次提交改动 $changed 行（>400），考虑拆成多个原子提交（清单类大批量变更可忽略）")
        }
    }
}
finally { Pop-Location }

foreach ($w in $warnings) { Write-Host "  ! $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "  ✗ $e" -ForegroundColor Red }
if ($errors.Count -gt 0) { exit 1 }
exit 0
