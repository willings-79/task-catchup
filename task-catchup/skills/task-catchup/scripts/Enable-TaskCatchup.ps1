#requires -Version 5.1
<# 批量给已有用户级计划任务开启"错过补跑"。默认 dry-run，加 -Apply 才写入。 #>
[CmdletBinding()]
param(
  [string]$Name = '*',
  [switch]$Apply,
  [switch]$IncludeVendors
)
$targets = @(Get-ScheduledTask |
  Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskName -like $Name -and -not $_.Settings.StartWhenAvailable })

if (-not $targets) { 'Nothing to change: all matched user tasks already have catch-up enabled (or none matched).'; return }

$applied = 0; $failed = 0; $skippedVendors = 0
foreach ($t in $targets) {
  $label = '{0}{1}' -f $t.TaskPath, $t.TaskName
  if (-not $IncludeVendors -and $t.TaskName -match '(?i)updater|update|logontask') {
    "[skip vendor]  $label（第三方更新类任务默认跳过；确要包含加 -IncludeVendors）"
    $skippedVendors++
    continue
  }
  try {
    if ($Apply) {
      $t.Settings.StartWhenAvailable = $true
      $t | Set-ScheduledTask -ErrorAction Stop | Out-Null
      "[APPLIED]      $label"
      $applied++
    } else {
      "[would enable] $label"
    }
  } catch {
    "[FAILED]       $label -> $($_.Exception.Message)"
    $failed++
  }
}

if ($Apply) {
  "Summary: applied=$applied failed=$failed skipped-vendor=$skippedVendors"
} else {
  "Summary: would change $($targets.Count) task(s) (dry run: re-run with -Apply to write changes; -IncludeVendors 包含第三方更新类)"
}
if ($failed -gt 0) { exit 1 }
