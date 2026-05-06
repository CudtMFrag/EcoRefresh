# test-refresh-rate.ps1
# 测试显示器刷新率切换 —— 10 秒内不确认自动回滚
# 用法: 右键 → 使用 PowerShell 运行，或终端: .\test-refresh-rate.ps1
# 安全: 仅切换刷新率；超时或取消自动回滚；任何时候重启即恢复

$ErrorActionPreference = 'Stop'

# ====== Win32 API (raw IntPtr 方案，兼容性最好) ======
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class Disp
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int EnumDisplaySettingsW(IntPtr lpszDeviceName, int iModeNum, IntPtr lpDevMode);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int ChangeDisplaySettingsW(IntPtr lpDevMode, int dwFlags);

    public const int ENUM_CURRENT_SETTINGS = -1;
    public const int CDS_UPDATEREGISTRY    = 0x01;
    public const int CDS_TEST              = 0x02;
    public const int DISP_CHANGE_SUCCESSFUL = 0;

    // DEVMODEW field offsets (64-bit, Pack=8 default)
    // offset  0: dmDeviceName   WCHAR[32]   (64 bytes)
    // offset 64: dmSpecVersion  WORD         (2)
    // offset 66: dmDriverVersion WORD        (2)
    // offset 68: dmSize         WORD         (2)
    // offset 70: dmDriverExtra  WORD         (2)
    // offset 72: dmFields       DWORD        (4)
    // offset 76: dmPositionX    LONG         (4)
    // offset 80: dmPositionY    LONG         (4)
    // offset 84: dmDisplayOrientation  DWORD (4)
    // offset 88: dmDisplayFixedOutput  DWORD (4)
    // offset 92: dmColor        SHORT        (2)
    // offset 94: dmDuplex       SHORT        (2)
    // offset 96: dmYResolution  SHORT        (2)
    // offset 98: dmTTOption     SHORT        (2)
    // offset100: dmCollate      SHORT        (2)
    // offset102: dmFormName     WCHAR[32]    (64)
    // offset166: dmLogPixels    WORD         (2)
    // offset168: dmBitsPerPel   DWORD        (4)
    // offset172: dmPelsWidth    DWORD        (4)
    // offset176: dmPelsHeight   DWORD        (4)
    // offset180: dmDisplayFlags DWORD        (4)
    // offset184: dmDisplayFrequency DWORD    (4)
    public const int OFF_DMSIZE      = 68;
    public const int OFF_DMFIELDS    = 72;
    public const int OFF_PELSWIDTH   = 172;
    public const int OFF_PELSHEIGHT  = 176;
    public const int OFF_DISPLAYFREQ = 184;
    public const int DM_DISPLAYFREQUENCY = 0x00400000;
    public const int BUF_SIZE = 512;
}
'@

function Read-DevModeInt32($buf, $offset) {
    return [Runtime.InteropServices.Marshal]::ReadInt32($buf, $offset)
}
function Write-DevModeInt16($buf, $offset, $value) {
    [Runtime.InteropServices.Marshal]::WriteInt16($buf, $offset, $value)
}
function Write-DevModeInt32($buf, $offset, $value) {
    [Runtime.InteropServices.Marshal]::WriteInt32($buf, $offset, $value)
}
function New-DevModeBuf {
    $buf = [Runtime.InteropServices.Marshal]::AllocHGlobal([Disp]::BUF_SIZE)
    for ($i = 0; $i -lt [Disp]::BUF_SIZE; $i++) {
        [Runtime.InteropServices.Marshal]::WriteByte($buf, $i, 0)
    }
    return $buf
}
function Free-DevModeBuf($buf) {
    [Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
}

function Get-CurrentDisplayMode {
    $buf = New-DevModeBuf
    try {
        Write-DevModeInt16 $buf ([Disp]::OFF_DMSIZE) 188
        $ret = [Disp]::EnumDisplaySettingsW([IntPtr]::Zero, [Disp]::ENUM_CURRENT_SETTINGS, $buf)
        if ($ret -eq 0) { return $null }
        return @{
            Width  = Read-DevModeInt32 $buf ([Disp]::OFF_PELSWIDTH)
            Height = Read-DevModeInt32 $buf ([Disp]::OFF_PELSHEIGHT)
            Hz     = Read-DevModeInt32 $buf ([Disp]::OFF_DISPLAYFREQ)
            Fields = Read-DevModeInt32 $buf ([Disp]::OFF_DMFIELDS)
        }
    } finally { Free-DevModeBuf $buf }
}

function Get-AvailableRefreshRates($width, $height) {
    $rates = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; ; $i++) {
        $buf = New-DevModeBuf
        try {
            Write-DevModeInt16 $buf ([Disp]::OFF_DMSIZE) 188
            $ret = [Disp]::EnumDisplaySettingsW([IntPtr]::Zero, $i, $buf)
            if ($ret -eq 0) { break }
            $w  = Read-DevModeInt32 $buf ([Disp]::OFF_PELSWIDTH)
            $h  = Read-DevModeInt32 $buf ([Disp]::OFF_PELSHEIGHT)
            $hz = Read-DevModeInt32 $buf ([Disp]::OFF_DISPLAYFREQ)
            if ($w -eq $width -and $h -eq $height -and $hz -gt 0 -and $rates -notcontains $hz) {
                $rates.Add($hz)
            }
        } finally { Free-DevModeBuf $buf }
    }
    $rates.Sort()
    return $rates
}

function Set-RefreshRate($targetHz) {
    # Step 1: CDS_TEST
    $testBuf = New-DevModeBuf
    try {
        Write-DevModeInt16 $testBuf ([Disp]::OFF_DMSIZE) 188
        Write-DevModeInt32 $testBuf ([Disp]::OFF_DMFIELDS) ([Disp]::DM_DISPLAYFREQUENCY)
        Write-DevModeInt32 $testBuf ([Disp]::OFF_DISPLAYFREQ) $targetHz
        $r = [Disp]::ChangeDisplaySettingsW($testBuf, [Disp]::CDS_TEST)
        if ($r -ne [Disp]::DISP_CHANGE_SUCCESSFUL) { return $false }
    } finally { Free-DevModeBuf $testBuf }

    # Step 2: CDS_UPDATEREGISTRY
    $applyBuf = New-DevModeBuf
    try {
        Write-DevModeInt16 $applyBuf ([Disp]::OFF_DMSIZE) 188
        Write-DevModeInt32 $applyBuf ([Disp]::OFF_DMFIELDS) ([Disp]::DM_DISPLAYFREQUENCY)
        Write-DevModeInt32 $applyBuf ([Disp]::OFF_DISPLAYFREQ) $targetHz
        $r = [Disp]::ChangeDisplaySettingsW($applyBuf, [Disp]::CDS_UPDATEREGISTRY)
        return ($r -eq [Disp]::DISP_CHANGE_SUCCESSFUL)
    } finally { Free-DevModeBuf $applyBuf }
}

# ====== 主流程 ======
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  显示器刷新率切换测试工具"               -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 读取当前设置
$current = Get-CurrentDisplayMode
if (-not $current) {
    Write-Host "[错误] 无法读取当前显示设置" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}
$currentHz = $current.Hz
$currentW  = $current.Width
$currentH  = $current.Height
Write-Host "  当前分辨率 : ${currentW} x ${currentH}" -ForegroundColor White
Write-Host "  当前刷新率 : ${currentHz} Hz"            -ForegroundColor White
Write-Host ""

# 2. 枚举可用刷新率
Write-Host "  正在枚举可用刷新率..." -ForegroundColor DarkGray
$rates = Get-AvailableRefreshRates -width $currentW -height $currentH

if ($rates.Count -le 1) {
    Write-Host "[提示] 当前分辨率下只有 ${currentHz}Hz 一种刷新率可用，无需切换。" -ForegroundColor Yellow
    Read-Host "按 Enter 退出"
    exit 0
}

Write-Host "  当前分辨率下可用的刷新率:" -ForegroundColor White
for ($j = 0; $j -lt $rates.Count; $j++) {
    $marker = if ($rates[$j] -eq $currentHz) { "  ← 当前" } else { "" }
    Write-Host "    [$($j + 1)] $($rates[$j]) Hz$marker" -ForegroundColor Green
}
Write-Host ""

# 3. 选择目标
$others = $rates | Where-Object { $_ -ne $currentHz }
if ($others.Count -eq 1) {
    $targetHz = $others[0]
    Write-Host "  只有一个可选刷新率，自动选择: ${targetHz} Hz" -ForegroundColor Yellow
} else {
    $pick = Read-Host "  输入序号选择要测试的刷新率"
    try {
        $idx = [int]$pick - 1
        if ($idx -lt 0 -or $idx -ge $rates.Count) { throw }
        $targetHz = $rates[$idx]
    } catch {
        Write-Host "[错误] 无效选择" -ForegroundColor Red
        Read-Host "按 Enter 退出"
        exit 1
    }
}

if ($targetHz -eq $currentHz) {
    Write-Host "[提示] 选择了与当前相同的刷新率，无需切换。" -ForegroundColor Yellow
    Read-Host "按 Enter 退出"
    exit 0
}

# 4. 应用
Write-Host ""
Write-Host "  正在切换为 ${targetHz}Hz ..." -ForegroundColor Yellow
$ok = Set-RefreshRate $targetHz
if (-not $ok) {
    Write-Host "[错误] 切换 ${targetHz}Hz 失败！" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}
Write-Host "  已切换为 ${targetHz}Hz！" -ForegroundColor Green
Write-Host ""

# 5. 10 秒确认 / 自动回滚
$timeoutSeconds = 10
Write-Host "  ⚠ 请在 ${timeoutSeconds} 秒内确认屏幕显示正常 ⚠" -ForegroundColor Yellow
Write-Host ""

$wshell = New-Object -ComObject WScript.Shell
$popupResult = $wshell.Popup(
    "刷新率已切换为 ${targetHz}Hz`n`n屏幕显示是否正常？`n`n● 点「是」或按 Y = 保留新刷新率`n● 点「否」或按 N = 立即回滚`n● ${timeoutSeconds} 秒内不操作 = 自动回滚",
    $timeoutSeconds,
    "刷新率测试 - 确认",
    4 + 32   # 4=YesNo, 32=Warning icon
)

# 6. 处理结果
if ($popupResult -eq 6) {
    Write-Host ""
    Write-Host "  ✓ 已确认，刷新率保持 ${targetHz}Hz" -ForegroundColor Green
} else {
    Write-Host ""
    if ($popupResult -eq -1) {
        Write-Host "  ⏰ 超时未确认，正在回滚..." -ForegroundColor Red
    } else {
        Write-Host "  ↩ 用户取消，正在回滚..." -ForegroundColor Red
    }
    $ok = Set-RefreshRate $currentHz
    if ($ok) {
        Write-Host "  ✓ 已回滚为 ${currentHz}Hz" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ 回滚失败，请手动在 Windows 设置 → 屏幕 → 高级显示器中改回 ${currentHz}Hz" -ForegroundColor Red
    }
}

Write-Host ""
Read-Host "按 Enter 退出"
