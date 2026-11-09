#requires -Version 7.4
<#
.SYNOPSIS
    唯一验收入口：编排全部校验并汇总结果。
.DESCRIPTION
    本地钩子、CI 与文档里出现的校验命令都只调用本脚本，避免同一份检查清单在多处各写一遍。
    -Fast  跳过「字形覆盖」与「发布包自校验」两项慢检查，供 pre-commit 使用。
.EXAMPLE
    pwsh -NoLogo -NoProfile -File scripts/verify.ps1
    pwsh -NoLogo -NoProfile -File scripts/verify.ps1 -Fast
#>
[CmdletBinding()]
param([switch]$Fast)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

# Python 解释器优先级：仓库内 .venv → 环境变量 PYTHON → PATH 上的 python/python3
$candidates = @(
    (Join-Path $root '.venv/Scripts/python.exe'),
    (Join-Path $root '.venv/bin/python')
)
$python = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $python = $c; break }
}
if (-not $python -and $env:PYTHON) { $python = $env:PYTHON }
if (-not $python) { $python = (Get-Command python -ErrorAction SilentlyContinue)?.Source }
if (-not $python) { $python = (Get-Command python3 -ErrorAction SilentlyContinue)?.Source }
if (-not $python) {
    Write-Host '  ✗ 找不到 python / python3，无法运行载荷校验' -ForegroundColor Red
    exit 1
}
Write-Host "  python: $python" -ForegroundColor DarkGray

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Host ''
    Write-Host "▶ $Name" -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $true
    $detail = 'ok'
    try { & $Action }
    catch {
        $ok = $false
        $detail = $_.Exception.Message
        Write-Host "  ✗ $Name 失败：$detail" -ForegroundColor Red
    }
    finally { $sw.Stop() }

    $results.Add([pscustomobject]@{
            Name = $Name
            Ok   = $ok
            Ms   = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            Detail = $detail
        })
}

function Step-Pwsh([string]$relative) {
    Invoke-Step -Name $relative -Action {
        & pwsh -NoLogo -NoProfile -File (Join-Path $root $relative)
        if ($LASTEXITCODE -ne 0) { throw "退出码 $LASTEXITCODE" }
    }
}

function Step-Python([string]$script, [string[]]$argv = @()) {
    $name = "python $script $($argv -join ' ')".Trim()
    Invoke-Step -Name $name -Action {
        & $python (Join-Path $root $script) @argv
        if ($LASTEXITCODE -ne 0) { throw "退出码 $LASTEXITCODE" }
    }
}

# ---------- 快速检查 ----------
Step-Pwsh 'scripts/check-versions.ps1'
Step-Pwsh 'scripts/check-docs.ps1'
Step-Pwsh 'scripts/check-layout.ps1'
Step-Pwsh 'scripts/check-scripts.ps1'
Step-Python 'tools/verify_manifest.py'
Step-Python 'tools/lint_ftl.py' @('files/mods')
Step-Python 'tools/struct_check_maps.py' @('files/mods')
Step-Python 'tools/check_links.py' @('.')
Step-Python 'tools/build_install_txt.py' @('--check')
Step-Python 'tools/build_readme_inventory.py' @('--check')

# ---------- 慢检查（-Fast 跳过） ----------
if (-not $Fast) {
    Step-Python 'tools/check_font_coverage.py'
    Step-Python 'tools/build_release.py' @('--verify')
}
else {
    Write-Host ''
    Write-Host '（快速模式：跳过 字形覆盖 / 发布包自校验）' -ForegroundColor DarkGray
}

# ---------- 汇总 ----------
$failed = @($results | Where-Object { -not $_.Ok })
$passed = @($results | Where-Object { $_.Ok })
$total = [math]::Round((($results | Measure-Object -Property Ms -Sum).Sum), 1)

Write-Host ''
Write-Host ('─' * 56) -ForegroundColor DarkGray
foreach ($r in $results) {
    $mark = if ($r.Ok) { '✓' } else { '✗' }
    $color = if ($r.Ok) { 'DarkGreen' } else { 'Red' }
    Write-Host ("  {0} {1}  ({2}s)" -f $mark, $r.Name, $r.Ms) -ForegroundColor $color
}
Write-Host ('─' * 56) -ForegroundColor DarkGray
if ($failed.Count -eq 0) {
    Write-Host "  $($passed.Count) 项通过 · 用时 ${total}s" -ForegroundColor Green
    exit 0
}
Write-Host "  $($passed.Count) 项通过 · $($failed.Count) 项失败 · 用时 ${total}s" -ForegroundColor Red
exit 1
