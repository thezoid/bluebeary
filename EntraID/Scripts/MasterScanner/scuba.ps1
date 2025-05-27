Param(
     [Parameter(Mandatory=$true)][string]$tenantName,
     [Parameter(Mandatory=$true)][string]$userPrincipalName,
     [ValidateSet("commercial", "gcc", "gcchigh", "dod")][string]$m365Environment="commercial",
     [string]$logPath = "c:\MasterScanner\Logs",
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
             $logFilePath = Join-Path -Path $LogPath -ChildPath "$(Get-Date -Format 'yyyyMMdd').log"
             Add-Content -Path $logFilePath -Value "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message"
         }
     }
 }

if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
     Write-Log "SCuBA requires PowerShell 5.1" "Error" $logPath $loggingLevel
     exit 1
}

$ErrorActionPreference = "Continue"
if (-not (Get-Module -ListAvailable -Name ScubaGear)) {
     Install-Module -Name ScubaGear -AllowClobber -Force
}
 
if (-not (Get-Module -Name ScubaGear)) {
     Import-Module ScubaGear
}
 
Initialize-SCuBA 
Invoke-SCuBA -Version

#run scuba
Invoke-SCuBA -ProductNames * `
     -OutPath "c:\MasterScanner\Results" `
     -OutFolderName "SCuBA" `
     -DisconnectOnExit `
     -M365Environment $m365Environment 
# -AppID $clientId `
# -Organization  $tenantName `
# -CertificateThumbprint $certThumbprint `
