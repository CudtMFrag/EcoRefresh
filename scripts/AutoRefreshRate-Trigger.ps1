$batteryHz = 60
$acHz      = 165
$switch    = 'C:\Users\Ryle_\scripts\Set-RefreshRate.ps1'

Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Seconds 1

$onBattery = ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -eq 'Offline')
$target = if ($onBattery) { $batteryHz } else { $acHz }

(New-Object -ComObject WScript.Shell).Run("pwsh -NoProfile -WindowStyle Hidden -File `"$switch`" -Hz $target", 0, 1)
