# Autorefresh
# 联想笔记本刷新率自动化切换

## 功能

- 电池供电 → 自动切 60Hz（省电）
- 接通电源 → 自动切 165Hz（流畅）

## 安装

```powershell
.\scripts\Install-AutoRefreshRate.ps1
```

然后在任务计划程序中手动创建一个事件触发任务（插拔秒切）：

```powershell
schtasks /Create /TN "离电来电自动刷新率切换" /SC ONEVENT /EC System /MO "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=105]]" /TR "pwsh -NoProfile -WindowStyle Hidden -File G:\Autorefresh\scripts\AutoRefreshRate-Trigger.ps1" /F
```

## 使用

安装后无需手动操作。插拔电源自动切换。

手动测试：
```powershell
.\scripts\test-refresh-rate.ps1        # 交互式测试（10秒安全回滚）
.\scripts\Set-RefreshRate.ps1 -Hz 60   # 直接切换到指定刷新率
```

## 卸载

```powershell
Unregister-ScheduledTask -TaskName 'AutoRefreshRate'
Unregister-ScheduledTask -TaskName '离电来电自动刷新率切换'
```

## 文档

详见 `docs/联想刷新率自动化全流程.md`
