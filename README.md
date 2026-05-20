# Autorefresh
# 联想笔记本刷新率自动化切换

## 功能

- 电池供电 → 自动切 60Hz（省电）
- 接通电源 → 自动切 165Hz（流畅）

## 当前系统状态

截至 2026-05-07 检查，系统当前只有一个已启用的事件触发任务：

- 任务名：`\事件查看器任务\离电来电自动刷新率切换`
- 触发器：`Microsoft-Windows-Kernel-Power` / `EventID=105`，并带有解锁触发器
- 执行动作：`pwsh -NoProfile -WindowStyle Hidden -File "C:\Users\Ryle_\scripts\AutoRefreshRate-Trigger.ps1"`
- 最近运行：2026/5/7 12:20:09，结果 `0`
- 当前未发现 `\AutoRefreshRate` 轮询任务

当前 `C:\Users\Ryle_\scripts\*.ps1` 与本仓库 `G:\Autorefresh\scripts\*.ps1` 的脚本内容一致，但系统任务实际调用的是 `C:\Users\Ryle_\scripts` 下的副本。

## 安装

下面是仓库脚本的安装入口。注意：当前系统状态并不是由这一步完整体现；系统里没有发现它会创建的 `AutoRefreshRate` 轮询任务。

```powershell
.\scripts\Install-AutoRefreshRate.ps1
```

当前生效的事件任务位于 `\事件查看器任务\离电来电自动刷新率切换`，执行 `C:\Users\Ryle_\scripts\AutoRefreshRate-Trigger.ps1`。如果要按仓库路径重建事件触发任务，可使用：

```powershell
schtasks /Create /TN "\事件查看器任务\离电来电自动刷新率切换" /SC ONEVENT /EC System /MO "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=105]]" /TR "pwsh -NoProfile -WindowStyle Hidden -File \"G:\Autorefresh\scripts\AutoRefreshRate-Trigger.ps1\"" /F
```

## 使用

当前系统通过事件触发任务实现插拔电源自动切换。没有轮询兜底任务。

手动测试：
```powershell
.\scripts\test-refresh-rate.ps1        # 交互式测试（10秒安全回滚）
.\scripts\Set-RefreshRate.ps1 -Hz 60   # 直接切换到指定刷新率
```

## 卸载

```powershell
schtasks /Delete /TN "\事件查看器任务\离电来电自动刷新率切换" /F
```

## 文档

详见 `docs/联想刷新率自动化全流程.md`
