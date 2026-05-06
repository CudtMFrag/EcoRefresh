# Install-AutoRefreshRate.ps1
# 安装电源感知自动刷新率切换（离电 60Hz / 插电 165Hz）
# 用法: .\Install-AutoRefreshRate.ps1 [-BatteryHz 60] [-AcHz 165]

param(
    [int]$BatteryHz = 60,
    [int]$AcHz      = 165
)

$ErrorActionPreference = 'Stop'
$taskName      = 'AutoRefreshRate'
$switchScript  = Join-Path $PSScriptRoot 'Set-RefreshRate.ps1'
$triggerScript = Join-Path $PSScriptRoot 'AutoRefreshRate-Trigger.ps1'

# ====== 1. 检查核心脚本 ======
if (-not (Test-Path $switchScript)) {
    Write-Error "找不到 Set-RefreshRate.ps1，请确保它与本脚本在同一目录"
    Read-Host "按 Enter 退出"; exit 1
}

# ====== 2. 生成简洁触发器脚本 ======
# Set-RefreshRate 本身会检测当前 Hz，已是目标 Hz 则跳过
$triggerContent = @"
`$batteryHz = $BatteryHz
`$acHz      = $AcHz
`$switch    = '$($switchScript -replace "'","''")'

Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Seconds 1

`$onBattery = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Offline')
`$target = if (`$onBattery) { `$batteryHz } else { `$acHz }

Start-Process -FilePath pwsh -ArgumentList "-NoProfile -WindowStyle Hidden -File \`"`$switch\`" -Hz `$target" -WindowStyle Hidden -Wait
"@

Set-Content -Path $triggerScript -Value $triggerContent -Encoding UTF8
Write-Host "✓ 触发器脚本已生成: $triggerScript" -ForegroundColor Green

# ====== 3. 清理旧任务 ======
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "  卸载旧任务: $taskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# ====== 4. 创建计划任务 ======
$pwshExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $pwshExe) { $pwshExe = (Get-Command pwsh -ErrorAction Stop).Source }

$action = New-ScheduledTaskAction `
    -Execute $pwshExe `
    -Argument "-NoProfile -WindowStyle Hidden -File `"$triggerScript`""

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries:$true `
    -DontStopIfGoingOnBatteries:$true `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -Compatibility Win8

# 三个触发器: 开机 + 登录 + 每3分钟轮询
$triggers = @()
$triggers += New-ScheduledTaskTrigger -AtStartup
$triggers += New-ScheduledTaskTrigger -AtLogOn
# 无限重复: 3650 天 ≈ 10 年
$triggers += New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 3) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName $taskName `
    -Action $action -Principal $principal -Settings $settings `
    -Trigger $triggers -Force | Out-Null

Write-Host "✓ 计划任务已注册: $taskName" -ForegroundColor Green

# ====== 5. 首次同步 ======
Write-Host ""
Write-Host "  执行首次同步..." -ForegroundColor Cyan
& pwsh -NoProfile -File $triggerScript

# ====== 6. 总结 ======
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安装完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  规则 : 电池 → ${BatteryHz}Hz  /  电源 → ${AcHz}Hz" -ForegroundColor White
Write-Host "  触发 : 开机 + 登录 + 每 3 分钟轮询"              -ForegroundColor White
Write-Host ""
Write-Host "  管理:" -ForegroundColor DarkGray
Write-Host "    查看  : Get-ScheduledTask '$taskName'"           -ForegroundColor DarkGray
Write-Host "    运行  : Start-ScheduledTask '$taskName'"         -ForegroundColor DarkGray
Write-Host "    状态  : Get-ScheduledTaskInfo '$taskName'"       -ForegroundColor DarkGray
Write-Host "    卸载  : Unregister-ScheduledTask '$taskName'"    -ForegroundColor DarkGray
Write-Host ""
Read-Host "按 Enter 退出"
