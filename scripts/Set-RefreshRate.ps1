# Set-RefreshRate.ps1
# 切换显示器刷新率（仅刷新率，不动分辨率）
# 用法:
#   .\Set-RefreshRate.ps1 -Hz 165                  # 手动切 165Hz
#   .\Set-RefreshRate.ps1                           # 自动模式（电池→60Hz，电源→165Hz）
#   .\Set-RefreshRate.ps1 -BatteryHz 48 -AcHz 120   # 自定义对应关系

param(
    [int]$Hz,
    [int]$BatteryHz = 60,
    [int]$AcHz      = 165
)

$ErrorActionPreference = 'Stop'

# ====== Win32 API (raw IntPtr buffer, 此机型托管 DEVMODEW 返回 0) ======
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Disp
{
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int EnumDisplaySettingsW(IntPtr l, int i, IntPtr d);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int ChangeDisplaySettingsW(IntPtr d, int f);
    public const int ENUM_CURRENT=-1, CDS_UPDATEREGISTRY=1, CDS_TEST=2, SUCCESS=0;
    public const int OFF_SIZE=68, OFF_FIELDS=72, OFF_W=172, OFF_H=176, OFF_HZ=184;
    public const int DM_HZ=0x00400000, BUF=512;
}
'@

function Set-Hz($targetHz) {
    $f = [Runtime.InteropServices.Marshal]

    # Test first
    $b = $f::AllocHGlobal([Disp]::BUF)
    try {
        for ($i=0;$i-lt[Disp]::BUF;$i++){$f::WriteByte($b,$i,0)}
        $f::WriteInt16($b,[Disp]::OFF_SIZE,188)
        $f::WriteInt32($b,[Disp]::OFF_FIELDS,[Disp]::DM_HZ)
        $f::WriteInt32($b,[Disp]::OFF_HZ,$targetHz)
        if ([Disp]::ChangeDisplaySettingsW($b,[Disp]::CDS_TEST) -ne [Disp]::SUCCESS) { return $false }
    } finally { $f::FreeHGlobal($b) }

    # Apply
    $b = $f::AllocHGlobal([Disp]::BUF)
    try {
        for ($i=0;$i-lt[Disp]::BUF;$i++){$f::WriteByte($b,$i,0)}
        $f::WriteInt16($b,[Disp]::OFF_SIZE,188)
        $f::WriteInt32($b,[Disp]::OFF_FIELDS,[Disp]::DM_HZ)
        $f::WriteInt32($b,[Disp]::OFF_HZ,$targetHz)
        return ([Disp]::ChangeDisplaySettingsW($b,[Disp]::CDS_UPDATEREGISTRY) -eq [Disp]::SUCCESS)
    } finally { $f::FreeHGlobal($b) }
}

# ====== 自动模式：根据电源选择目标 Hz ======
if (-not $PSBoundParameters.ContainsKey('Hz')) {
    Add-Type -AssemblyName System.Windows.Forms
    Start-Sleep -Seconds 1
    $onBattery = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Offline')
    $Hz = if ($onBattery) { $BatteryHz } else { $AcHz }
}

# ====== 读取当前刷新率，避免重复切换 ======
$b = [Runtime.InteropServices.Marshal]::AllocHGlobal([Disp]::BUF)
try {
    for ($i=0;$i-lt[Disp]::BUF;$i++){[Runtime.InteropServices.Marshal]::WriteByte($b,$i,0)}
    [Runtime.InteropServices.Marshal]::WriteInt16($b,[Disp]::OFF_SIZE,188)
    $r   = [Disp]::EnumDisplaySettingsW([IntPtr]::Zero,[Disp]::ENUM_CURRENT,$b)
    $cur = [Runtime.InteropServices.Marshal]::ReadInt32($b,[Disp]::OFF_HZ)
    $w   = [Runtime.InteropServices.Marshal]::ReadInt32($b,[Disp]::OFF_W)
    $h   = [Runtime.InteropServices.Marshal]::ReadInt32($b,[Disp]::OFF_H)
} finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($b) }

if ($r -eq 0) { Write-Error "无法读取当前显示设置"; exit 1 }
if ($cur -eq $Hz) { Write-Host "已是 ${Hz}Hz，无需切换 (${w}x${h})"; exit 0 }

Write-Host "切换: ${w}x${h} @ ${cur}Hz → ${Hz}Hz"
if (Set-Hz $Hz) {
    Write-Host "✓ 已切换为 ${Hz}Hz"
} else {
    Write-Error "切换失败"; exit 1
}
