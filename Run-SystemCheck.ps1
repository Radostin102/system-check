function Write-Log {
    [CmdletBinding(DefaultParameterSetName = "Info")]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Info", Position = 0)]
        [string]$Info,

        [Parameter(Mandatory = $true, ParameterSetName = "Warning")]
        [string]$Warning,

        [Parameter(Mandatory = $true, ParameterSetName = "Error")]
        [string]$Error,

        [Parameter(Mandatory = $true, ParameterSetName = "Success")]
        [string]$Success
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Success" { $msg = $Success; $sym = "[+]"; $col = "Green"  }
        "Warning" { $msg = $Warning; $sym = "[-]"; $col = "Yellow" }
        "Error"   { $msg = $Error;   $sym = "[-]"; $col = "Red"    }
        default   { $msg = $Info;    $sym = "[*]"; $col = "Blue"   }
    }

    Write-Host "$sym $msg" -ForegroundColor $col
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "Requesting administrative privileges"

    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        exit
    }
    catch {
        Write-Log -Error "Admin prompt declined; exiting script"
        exit
    }
}

Clear-Host
Write-Host "`n--- SYSTEM CHECK ---`n" -ForegroundColor Cyan

Write-Log "Running DISM..."
DISM /Online /Cleanup-Image /RestoreHealth

Write-Log "Running SFC..."
sfc /scannow

Write-Log "Running DNS flush..."
ipconfig /flushdns

Write-Log "Running storage optimization..."
Optimize-Volume -DriveLetter C -ReTrim -Defrag -Verbose

Write-Log -Success "System check completed"
Pause
