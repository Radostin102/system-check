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
    } catch {
        Write-Log -Error "Admin prompt declined; exiting script"
    }

    exit
}

Clear-Host
Write-Host "`n--- SYSTEM CHECK ---`n" -ForegroundColor Cyan

Write-Log "This may take several minutes"
Write-Log "Running DISM..."
DISM /Online /Cleanup-Image /RestoreHealth

Write-Log "Running SFC..."
sfc /scannow

Write-Log "Running DNS flush..."
ipconfig /flushdns

Write-Log "Running storage optimization..."
Optimize-Volume -DriveLetter C -ReTrim -Defrag -Verbose

Write-Log "Cleaning temporary files..."
$totalBytesDeleted = 0
$tempPaths = @(
    "$env:windir\Temp",
    $env:TEMP
)

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        Write-Log "Cleaning: $path"

        $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if (-not $item.PSIsContainer) {
                $totalBytesDeleted += $item.Length
            }
        }

        $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$totalMb = $totalBytesDeleted / 1000000
$formatted = "{0:N2} MB" -f $totalMb
Write-Log -Success "Cleaned $formatted of temporary files"

Write-Log -Success "System check completed"

$response = (Read-Host "Restart machine? (Y/n)").Trim()
if ($response -ieq "y" -or -not $response) {
    Write-Host "Restarting machine..."
    Restart-Computer
} else {
    Write-Host "Exiting..."
    exit
}
