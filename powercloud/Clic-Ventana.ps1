<#
.SYNOPSIS
    Hace clic en una posicion (x, y relativa a la ventana) de la vista previa de D:\pcbuild\vista,
    para llegar a otras pantallas antes de capturarlas.
#>
param([int]$X, [int]$Y, [string]$Carpeta = "D:\pcbuild\vista")
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PcClic {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[void][PcClic]::SetProcessDPIAware()
$p = Get-Process | Where-Object { $_.Path -like "$Carpeta\*" -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { "No hay ventana de la vista previa"; exit 1 }
$h = $p.MainWindowHandle
[void][PcClic]::SetForegroundWindow($h)
# Ventana completa dentro de la pantalla principal (1440 x 960) para que el clic caiga en ella.
[void][PcClic]::SetWindowPos($h, [IntPtr]::Zero, 40, 40, 1440, 960, 0x0040)
Start-Sleep -Milliseconds 600
Start-Sleep -Milliseconds 300
$r = New-Object PcClic+RECT
[void][PcClic]::GetWindowRect($h, [ref]$r)
[void][PcClic]::SetCursorPos($r.Left + $X, $r.Top + $Y)
Start-Sleep -Milliseconds 150
[PcClic]::mouse_event(0x02, 0, 0, 0, [IntPtr]::Zero)
[PcClic]::mouse_event(0x04, 0, 0, 0, [IntPtr]::Zero)
"clic en ($X, $Y)"
