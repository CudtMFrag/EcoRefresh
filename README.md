# Autorefresh
# 联想笔记本刷新率自动化切换

## 功能

- 电池供电 → 自动切 60Hz（省电）
- 接通电源 → 自动切 165Hz（流畅）

## 架构

```
计划任务 → wscript.exe → AutoRefreshRate-Trigger.vbs → pwsh → Set-RefreshRate.ps1
  (事件触发)     ↑ GUI 子系统, 不闪窗           SW_HIDE(0)    单文件, 手动/自动双模式
```

- **零闪烁**：`wscript.exe` 是 GUI 子系统，不创建控制台窗口；`WSH.Run(..., 0)` = SW_HIDE，子进程 pwsh 从 `CreateProcess` 阶段即隐藏
- **单脚本**：`Set-RefreshRate.ps1` 合并了电源检测 + Win32 API 切换，无路径依赖

## 当前系统状态

| 属性 | 值 |
|---|---|
| 任务路径 | `\事件查看器任务\离电来电自动刷新率切换` |
| 操作 | `wscript.exe "G:\Autorefresh\scripts\AutoRefreshRate-Trigger.vbs"` |
| 触发器 | Kernel-Power 105, SessionUnlock, Kernel-Power 107, Kernel-Power 507, At startup, At logon |
| 入口 | VBS（GUI 子系统）→ pwsh → Set-RefreshRate.ps1（自动模式） |

## 安装

```powershell
.\scripts\Install-AutoRefreshRate.ps1                           # 默认 60Hz/165Hz
.\scripts\Install-AutoRefreshRate.ps1 -BatteryHz 48 -AcHz 120  # 自定义
```

安装脚本会生成 VBS 包装器并注册计划任务。

## 使用

```powershell
.\scripts\Set-RefreshRate.ps1                    # 自动模式（根据电源选择）
.\scripts\Set-RefreshRate.ps1 -Hz 60             # 手动切 60Hz
.\scripts\Set-RefreshRate.ps1 -Hz 165            # 手动切 165Hz
.\scripts\test-refresh-rate.ps1                  # 交互式测试（10秒安全回滚）
```

## 卸载

```powershell
schtasks /Delete /TN "\事件查看器任务\离电来电自动刷新率切换" /F
```

## 文档

详见 `docs/联想刷新率自动化全流程.md`
