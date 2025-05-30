Param(
     [Parameter(Mandatory=$true)][string]$tenantName,
     [Parameter(Mandatory=$true)][string]$userPrincipalName,
     [ValidateSet("commercial", "gcc", "gcchigh", "dod")][string]$m365Environment="commercial",
     [string]$logPath = "c:\MasterScanner\Logs",
     [int]$loggingLevel = 5
)
$ErrorActionPreference = "Continue"
function Write-Log {
    param (
        [string]$Message,
        [string]$Type,
        [string]$LogPath,
        [int]$LoggingLevel,
        [bool]$WriteToFile = $true
    )
    $logLevels = @{
        "ALWAYS" = 0
        "ERROR" = 1
        "WARNING" = 2
        "SUCCESS" = 2
        "INFO" = 3
        "DEBUG" = 4
        "TRACE" = 5
    }
    $level = $logLevels[$Type.ToUpper()]
    if ($LoggingLevel -ge $level) {
        Write-Host "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message"
        if ($WriteToFile) {
            if (-not (Test-Path $LogPath)) {
                New-Item -ItemType Directory -Path $LogPath
            }
            $logFilePath = Join-Path -Path $LogPath -ChildPath "$(Get-Date -Format 'yyyyMMdd').log"
            Add-Content -Path $logFilePath -Value "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message"
        }
    }
}

#vars
#endvar

#run stage
try {
    & "$PSScriptRoot\stage.ps1" -TenantName $tenantName -UserPrincipalName $userPrincipalName -LogPath $logPath -LoggingLevel $loggingLevel
} catch {
     Write-Log -Message "Failed to stage`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
     exit 1
}

# --- SCUBA ---
Write-Log -Message "Running SCuBA via Windows PowerShell 5.1" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel

try{
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\scuba.ps1" `
        -TenantName $tenantName `
        -UserPrincipalName $userPrincipalName `
        -M365Environment $m365Environment `
        -LogPath $logPath `
        -LoggingLevel $loggingLevel
}catch{
    Write-Log -Message "Failed to run SCuBA`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
}


# --- Maester ---
Write-Log -Message "Running Maester natively in PowerShell 7" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
try {
    & "$PSScriptRoot\maester.ps1" `
        -TenantName $tenantName `
        -UserPrincipalName $userPrincipalName `
        -M365Environment $m365Environment `
        -LogPath $logPath `
        -LoggingLevel $loggingLevel
}
catch {
    Write-Log -Message "Failed to run Maester`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
}

# Archive the results folder to a zip file
$resultsFolder = "C:\MasterScanner\Results"
$archiveDir = Split-Path -Path $resultsFolder -Parent
$archiveName = "$($tenantName)_$((Get-Date -Format 'yyyyMMdd_HHmmss')).zip" 
$archivePath = Join-Path -Path $archiveDir -ChildPath $archiveName
$archivePath = Join-Path -Path $PSScriptRoot -ChildPath ("results_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

if (Test-Path $resultsFolder) {
    try {
        Compress-Archive -Path "$resultsFolder\*" -DestinationPath $archivePath -Force
        Write-Log -Message "Archived results to $archivePath" -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
    } catch {
        Write-Log -Message "Failed to archive results folder`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
    }
} else {
    Write-Log -Message "Results folder not found at $resultsFolder" -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
}