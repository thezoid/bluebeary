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
        "ALWAYS"  = 0
        "ERROR"   = 1
        "WARNING" = 2
        "SUCCESS" = 2
        "INFO"    = 3
        "DEBUG"   = 4
        "TRACE"   = 5
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

Install-Module Pester -SkipPublisherCheck -Force -Scope CurrentUser
Install-Module Maester -Scope CurrentUser
Install-Module Az.Accounts -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

cd c:\MasterScanner\Results\maester-tests
Write-Log -Message "installing maester tests" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
Install-MaesterTests
Write-Log -Message "connecting to m365" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
Connect-Maester
Write-Log -Message "running maester tests" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
Invoke-Maester