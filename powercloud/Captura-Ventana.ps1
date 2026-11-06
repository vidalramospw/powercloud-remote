<#
.SYNOPSIS
    Captura en PNG las ventanas visibles de los procesos cuyo ejecutable esta en -Carpeta
    (por defecto la vista previa de D:\pcbuild\vista). Usa PrintWindow: sirve aunque la
    ventana este tapada por otras.
#>
param(
    [string]$Carpeta = "D:\pcbuild\vista",
    [string]$Salida = "D:\pcbuild\capturas",
    [string]$Nombre = "captura"
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class PcVentanas {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static List<IntPtr> DeProceso(uint pid) {
        var l = new List<IntPtr>();
        EnumWindows((h, p) => { uint q; GetWindowThreadProcessId(h, out q);
            if (q == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
"@
[void][PcVentanas]::SetProcessDPIAware()
New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$i = 0
foreach ($p in Get-Process | Where-Object { $_.Path -like "$Carpeta\*" }) {
    foreach ($h in [PcVentanas]::DeProceso([uint32]$p.Id)) {
        $r = New-Object PcVentanas+RECT
        [void][PcVentanas]::GetWindowRect($h, [ref]$r)
        $w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
        if ($w -lt 200 -or $hh -lt 150) { continue }
        $bmp = New-Object System.Drawing.Bitmap $w, $hh
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $dc = $g.GetHdc()
        [void][PcVentanas]::PrintWindow($h, $dc, 2)
        $g.ReleaseHdc($dc); $g.Dispose()
        $i++
        $archivo = Join-Path $Salida "$Nombre-$i.png"
        $bmp.Save($archivo, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        "$archivo ($w x $hh)"
    }
}
if ($i -eq 0) { "No hay ventanas visibles de $Carpeta" }
