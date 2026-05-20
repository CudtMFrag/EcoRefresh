' AutoRefreshRate-Trigger.vbs
' 无感启动 Set-RefreshRate.ps1（自动模式，根据电源切换刷新率）
' wscript.exe 是 GUI 子系统 → 不创建控制台窗口
' WSH.Run(..., 0) = SW_HIDE → 子进程 pwsh 从 CreateProcess 阶段即隐藏

Set fso = CreateObject("Scripting.FileSystemObject")
Set ws  = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path   = scriptDir & "\Set-RefreshRate.ps1"

ws.Run "pwsh -NoProfile -WindowStyle Hidden -File """ & ps1Path & """", 0, True
