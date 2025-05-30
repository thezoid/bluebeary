Param(
     [Parameter(Mandatory=$true)][string]$tenantName,
     [Parameter(Mandatory=$true)][string]$userPrincipalName,
     [ValidateSet("commercial", "gcc", "gcchigh", "dod")][string]$m365Environment="commercial",
     [string]$logPath = "c:\\MasterScanner\\Logs",
     [int]$loggingLevel = 5
)

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
             $logFile = Join-Path $LogPath ("scuba-" + (Get-Date -Format 'yyyyMMdd') + ".log")
             Add-Content -Path $logFile -Value "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message"
         }
     }
}

# Ensure ScubaGear is available from PowerShell 7 installation path
$ps7ModulePath = "$HOME\Documents\PowerShell\Modules"
$winPSModulePath = "$HOME\Documents\WindowsPowerShell\Modules"
$scubaModulePath = Join-Path $ps7ModulePath "ScubaGear"

if (Test-Path $scubaModulePath) {
    Copy-Item -Path $scubaModulePath -Destination $winPSModulePath -Recurse -Force -ErrorAction SilentlyContinue
    $env:PSModulePath = "$winPSModulePath;$env:PSModulePath"
}

Import-Module ScubaGear -Force
Initialize-SCuBA
Invoke-SCuBA -Version
Invoke-SCuBA -ProductNames * `
     -OutPath "c:\MasterScanner\Results" `
     -OutFolderName "$($tenantName)-SCuBA" `
     -DisconnectOnExit `
     -M365Environment $m365Environment 