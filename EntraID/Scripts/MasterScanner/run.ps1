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
     $stagingResults = & "$PSScriptRoot\stage.ps1" -TenantName $tenantName -UserPrincipalName $userPrincipalName -LogPath $logPath -LoggingLevel $loggingLevel
} catch {
     Write-Log -Message "Failed to stage`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
     exit 1
}

# $clientId = $stagingResults.ClientId
# $certPath = $stagingResults.CertPath
# $certPassword = $stagingResults.CertPassword
# $certThumbprint = (Get-PfxCertificate -FilePath $certPath).Thumbprint

#cd c:\MasterScanner

# run scuba
# requires in powershell 5
if ($PSVersionTable.PSVersion -join "." -notlike "5.*") {
    Write-Log -Message "SCuBA requires PowerShell 5 - launching SCuBA subprocess in new PS5 instance" -Type "warning" -LogPath $logPath -LoggingLevel $loggingLevel
    $scubaprocess = Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-Version 5.1",
        "-Command `"& {& '$PSScriptRoot\scuba.ps1' -TenantName '$tenantName' -UserPrincipalName '$userPrincipalName' -M365Environment '$m365Environment' -LogPath '$logPath' -LoggingLevel $loggingLevel}`""
    ) -NoNewWindow -Wait
}else{
    write-log -Message "Running SCuBA" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
    $scubaprocess = & "$PSScriptRoot\scuba.ps1" -TenantName $tenantName -UserPrincipalName $userPrincipalName -M365Environment $m365Environment -LogPath $logPath -LoggingLevel $loggingLevel
}

# run maester
try {
    write-log -Message "Running Maester" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
    $maesterprocess = & "$PSScriptRoot\maester.ps1" -TenantName $tenantName -UserPrincipalName $userPrincipalName -M365Environment $m365Environment -LogPath $logPath -LoggingLevel $loggingLevel
} catch {
    Write-Log -Message "Failed to run Maester`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
    exit 1
}