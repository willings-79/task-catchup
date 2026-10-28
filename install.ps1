#requires -Version 5.1
<#
task-catchup 一键安装（下载解压后在本文件所在目录运行）：
  powershell -ExecutionPolicy Bypass -File install.ps1
做什么：把技能装进已检测到的 agent 技能目录（ZCode/Claude Code/Codex/通用 .agents），并写入防丢规则。
参数：-NoRules 不写规则；-ApplyExisting 顺带批量修补存量任务；-Undo 卸载本安装器写入的内容；支持 -WhatIf 预演。
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$NoRules,
  [switch]$ApplyExisting,
  [switch]$Undo
)
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'task-catchup\skills\task-catchup'
if (-not (Test-Path (Join-Path $src 'SKILL.md'))) {
  throw "未找到技能目录 $src —— 请在解压后的包根目录（install.ps1 所在目录）运行。"
}

$markerStart = '<!-- task-catchup:start -->'
$ruleText = @'
<!-- task-catchup:start -->
创建定时任务规则：Windows 计划任务必须启用"错过补跑"——优先用本机技能 task-catchup 的 New-CatchupTask.ps1；手工时 PowerShell 用 New-ScheduledTaskSettingsSet -StartWhenAvailable（配合 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries）；schtasks 必须走 /XML 且含 <StartWhenAvailable>true</StartWhenAvailable>。用户表达"太旧的不补"时用 -MaxDelayHours N（24=只补一天内的）。Linux 用 systemd timer Persistent=true 或 anacron，不用裸 cron。调度时间=最早执行时间，错过在下次登录/唤醒立即补跑一次。
<!-- task-catchup:end -->
'@

$skillTargets = @(
  @{ Dir = Join-Path $env:USERPROFILE '.zcode\skills';  Label = 'ZCode 用户技能（自动发现，无需市场 UI）' },
  @{ Dir = Join-Path $env:USERPROFILE '.agents\skills'; Label = '通用技能目录（ZCode 等多 agent 共享读取）' },
  @{ Dir = Join-Path $env:USERPROFILE '.claude\skills'; Label = 'Claude Code' },
  @{ Dir = Join-Path $env:USERPROFILE '.codex\skills';  Label = 'Codex（按官方技能目录约定，未实测）' }
)
$ruleTargets = @(
  @{ File = Join-Path $env:USERPROFILE '.zcode\AGENTS.md';  Label = 'ZCode 用户指令' },
  @{ File = Join-Path $env:USERPROFILE '.codex\AGENTS.md';  Label = 'Codex 全局指令' },
  @{ File = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'; Label = 'Claude Code 全局指令' }
)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if ($Undo) {
  foreach ($t in $skillTargets) {
    $dst = Join-Path $t.Dir 'task-catchup'
    if ($PSCmdlet.ShouldProcess($dst, '删除技能目录')) {
      Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
      "removed: $dst"
    }
  }
  foreach ($t in $ruleTargets) {
    if (Test-Path $t.File) {
      $content = [IO.File]::ReadAllText($t.File)
      if ($content.Contains($markerStart)) {
        if ($PSCmdlet.ShouldProcess($t.File, '移除规则块')) {
          $clean = [regex]::Replace($content, [regex]::Escape($markerStart) + '(?s).*?<!-- task-catchup:end -->\r?\n?', '')
          [IO.File]::WriteAllText($t.File, $clean, $utf8NoBom)
          "rules removed: $($t.Label)"
        }
      }
    }
  }
  'UNDO DONE'
  return
}

"== 安装技能 =="
foreach ($t in $skillTargets) {
  $dst = Join-Path $t.Dir 'task-catchup'
  if ($PSCmdlet.ShouldProcess($dst, '复制技能目录')) {
    New-Item -ItemType Directory -Force -Path $t.Dir | Out-Null
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $src $dst -Recurse -Force
    "installed: $($t.Label) -> $dst"
  }
}

if (-not $NoRules) {
  "== 写入规则（防丢口径，带标记可随时移除）=="
  foreach ($t in $ruleTargets) {
    $exists = Test-Path $t.File
    if ($exists -and ([IO.File]::ReadAllText($t.File)).Contains($markerStart)) {
      "skip（已有规则）: $($t.Label)"
      continue
    }
    if ($PSCmdlet.ShouldProcess($t.File, '追加规则块')) {
      if ($exists) {
        $cur = [IO.File]::ReadAllText($t.File)
        [IO.File]::WriteAllText($t.File, $cur.TrimEnd() + "`r`n`r`n" + $ruleText + "`r`n", $utf8NoBom)
      } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $t.File) | Out-Null
        [IO.File]::WriteAllText($t.File, $ruleText + "`r`n", $utf8NoBom)
      }
      "rules written: $($t.Label) -> $($t.File)"
    }
  }
}

$enable = Join-Path $PSScriptRoot 'task-catchup\skills\task-catchup\scripts\Enable-TaskCatchup.ps1'
"`n== 存量任务检查 =="
& $enable
if ($ApplyExisting -and $PSCmdlet.ShouldProcess('存量计划任务', '批量开启补跑')) {
  & $enable -Apply
}

"`n== 完成 =="
'新开会话后，对任意已装 agent 说「帮我建个每天 9 点的定时任务」即可；ZCode 用户也可在 插件市场→Discover→+ 添加 GitHub 仓库 willings-79/task-catchup 直接安装。'
'卸载：powershell -File install.ps1 -Undo'
