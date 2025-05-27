Param(
    [Parameter(Mandatory = $true)][string]$tenantName,
    [Parameter(Mandatory = $true)][string]$userPrincipalName,
    [ValidateSet("commercial", "gcc", "gcchigh", "dod")][string]$m365Environment = "commercial",
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

# make staging folders
write-log -Message "Creating staging folders" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
if (-not (Test-Path -Path "c:\MasterScanner")) {
    mkdir -Path "c:\MasterScanner" -Force
}
if (-not (Test-Path -Path "c:\MasterScanner\Results")) {
    mkdir -Path "c:\MasterScanner\Results" -Force
}
if (-not (Test-Path -Path "c:\MasterScanner\Logs")) {
    mkdir -Path "c:\MasterScanner\Logs" -Force
}
if (-not (Test-Path -Path "c:\MasterScanner\Results\maester-tests")) {
    mkdir -Path "c:\MasterScanner\Results\maester-tests" -Force
}

# # Check if already connected to Microsoft Graph
# try {
#     $graphContext = Get-MgProfile -ErrorAction Stop
#     write-log -Message "Already connected to Microsoft Graph" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
# } catch {
#     write-log -Message "Connecting to Microsoft Graph" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
#     Connect-MgGraph -Scopes "Application.ReadWrite.All","Directory.ReadWrite.All" 
# }

# # Create a new application and service principal using Microsoft.Graph
# write-log -Message "Creating application 'Arrow Team - SCuBA'" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
# $app = New-MgApplication -DisplayName "Arrow Team - SCuBA"
# write-log -Message "Creating service principal for the application" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
# $servicePrincipal = New-MgServicePrincipal -AppId $app.AppId

# # Generate a certificate
# $cert = New-SelfSignedCertificate -Subject "CN=Arrow Team - SCuBA" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -NotAfter (Get-Date).AddYears(1)
# # Export the certificate
# $certPath = "c:\MasterScanner\SCuBA.pfx"
# $certPassword = ConvertTo-SecureString -String "@rrowSC00ba!" -Force -AsPlainText
# Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" -FilePath $certPath -Password $certPassword

# # Prepare key credential payload (modified)
# $keyCredential = New-Object -TypeName Microsoft.Graph.PowerShell.Models.KeyCredential
# $keyCredential.customKeyIdentifier = [System.Text.Encoding]::UTF8.GetBytes("SCuBA")
# $keyCredential.displayName         = "SCuBA Certificate"
# $keyCredential.endDateTime         = (Get-Date).AddYears(1)
# $keyCredential.key                 = [System.IO.File]::ReadAllBytes($certPath)
# $keyCredential.keyId               = [guid]::NewGuid().ToString()
# $keyCredential.startDateTime       = Get-Date
# $keyCredential.type                = "AsymmetricX509Cert"
# $keyCredential.usage               = "Verify"

# # Update the application with the new key credential using Microsoft.Graph
# Update-MgApplication -ApplicationId $app.Id -KeyCredentials @($keyCredential)

# Return the client ID and certificate path
return [PSCustomObject]@{
    ClientId     = $app.AppId
    CertPath     = $certPath
    CertPassword = $certPassword
}