# EcoRefresh

省电笔记本：根据电源自动切换显示器刷新率。**个人项目**——纯 PowerShell 脚本 + Windows 计划任务，无安装包，无 GUI，无通用性保证。仅在自己 ThinkBook 上测试通过。

## 功能

- 电池供电 → 自动切 60Hz（省电）
- 接通电源 → 自动切 165Hz（流畅）


## 同类对比

| 方案 | 说明 | 自动切换 | ThinkBook | 零闪烁 | 费用 |
|---|---|---|---|---|---|
| **EcoRefresh** | 脚本 + 计划任务 | ✅ 电源感知 | ✅ | ✅ | 免费 |
| Windows 设置 | 系统自带 GUI | ❌ 纯手动 | ✅ | — | 免费 |
| LenovoLegionToolkit | 桌面应用 | ✅ | ❌ 仅 Legion | ✅ | 免费 |
| CRU | 驱动级工具 | ❌ 纯手动 | ✅ | — | 免费 |
| DisplayFusion | 商业应用 | ⚠️ 需自写脚本 | ✅ | ❌ | ~$35 |
| HRC | 热键工具 | ❌ 按热键 | 未知 | — | 免费 |

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

安装脚本需要管理员权限（自动提权），会生成 VBS 包装器并注册事件驱动计划任务。

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

## 兼容性

| 项目 | 要求 |
|---|---|
| 操作系统 | Windows 10/11（64 位） |
| Shell | PowerShell 7+（pwsh），非 Windows PowerShell 5.1 |
| 测试机型 | ThinkBook 16+ G6+ AHP（3200×2000 @ 165Hz 面板） |
| 理论兼容 | 任何支持多刷新率的 Windows 笔记本 |

**已知限制**：
- 仅切换刷新率，不改变分辨率
- 依赖 `user32.dll` 的 `ChangeDisplaySettingsW`——某些显卡驱动可能忽略此 API
- 计划任务必须在用户登录后运行（Session 0 无法访问显示器）
- 安装需要管理员权限（脚本自动提权）
