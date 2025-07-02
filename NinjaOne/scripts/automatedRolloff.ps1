<#
.SYNOPSIS
    Automated offboarding script for NinjaOne-managed devices.

.DESCRIPTION
    This script retrieves device data from the NinjaOne API, identifies devices that have been offline for a configurable period (default 90 days),
    sends notifications via email and Microsoft Teams, and schedules stale devices for offboarding. 
    All configuration and secrets are loaded from a .env file.

.NOTES
    Author: The Arrow Team
    Requires: NinjaOne PowerShell module, Microsoft.Graph PowerShell module
    Configuration: Place a valid .env file in the script directory.
#>

if (-not (get-module -Name NinjaOne -ListAvailable)) {
     Install-Module -Name NinjaOne -Scope CurrentUser -Force -AllowClobber
}
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
     Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
}
if (-not (Get-Module -Name NinjaOne)) { 
     Import-Module NinjaOne 
}
if (-not (Get-Module -Name Microsoft.Graph.Authentication)) { 
     Import-Module Microsoft.Graph.Authentication 
}
# Add global organization cache if not already defined
if (-not $global:OrgCache) { $global:OrgCache = @{} }

<#
.SYNOPSIS
    Writes a log message to the console and optionally to a log file.

.DESCRIPTION
    Supports multiple log levels and color-coded output. 
    Log file is created per day in the specified log directory.

.PARAMETER Message
    The message to log.

.PARAMETER Type
    The log level/type (ALWAYS, ERROR, WARNING, SUCCESS, INFO, DEBUG, TRACE).

.PARAMETER LogPath
    The directory path for log files.

.PARAMETER LoggingLevel
    The current logging verbosity level.

.PARAMETER WriteToFile
    Whether to write the log message to a file (default: $true).
#>
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
          $color = switch ($Type.ToUpper()) {
               "ERROR" { "Red" }
               "WARNING" { "Yellow" }
               "SUCCESS" { "Green" }
               "INFO" { "White" }
               "DEBUG" { "Cyan" }
               "TRACE" { "Magenta" }
               DEFAULT { "White" }
          }
          Write-Host "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message" -ForegroundColor $color
          if ($WriteToFile) {
               if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath | Out-Null }
               $logFilePath = Join-Path -Path $LogPath -ChildPath "$(Get-Date -Format 'yyyyMMdd').log"
               Add-Content -Path $logFilePath -Value "[$($Type.ToUpper())][$(Get-Date -Format 'yyyyMMdd@HH:mm:ss')] $Message"
          }
     }
}

<#
.SYNOPSIS
    Loads environment variables from a .env file.

.DESCRIPTION
    Reads key-value pairs from a .env file and returns them as a hashtable.

.PARAMETER Path
    The path to the .env file.

.OUTPUTS
    Hashtable of environment variables.
#>
function Load-DotEnv {
    param([string]$Path)
    $envTable = @{}
    if (Test-Path $Path) {
        Get-Content $Path | Where-Object { $_ -match '=' -and -not ($_ -match '^\s*#') } | ForEach-Object {
            $parts = $_ -split '=', 2
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            $envTable[$key] = $value
        }
    }
    return $envTable
}

<#
.SYNOPSIS
    Authenticates with NinjaOne API and retrieves an access token.

.DESCRIPTION
    Uses client credentials to obtain a bearer token for NinjaOne API.

.PARAMETER clientId
    The NinjaOne API client ID.

.PARAMETER clientSecret
    The NinjaOne API client secret.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.OUTPUTS
    NinjaOne API access token string.
#>
function Get-NinjaAccessToken {
     param(
          [string]$clientId,
          [string]$clientSecret,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Initiating NinjaOne authentication..." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     Write-Log -Message "NinjaOne authentication request body prepared." -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
     $authUrl = "https://app.ninjarmm.com/ws/oauth/token"
     $authHeaders = @{
          'Content-Type' = 'application/x-www-form-urlencoded'
     }
     $authBody = @{
          'grant_type'    = 'client_credentials'
          'client_id'     = $clientId
          'client_secret' = $clientSecret
          'scope'         = 'monitoring management'
     }
     try {
          Write-Log -Message "Sending authentication request to NinjaOne." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          $response = Invoke-RestMethod -Uri $authUrl -Method Post -Headers $authHeaders -Body $authBody
          Write-Log -Message "NinjaOne authentication succeeded." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
          return $response.access_token
     }
     catch {
          Write-Log -Message "NinjaOne authentication failed: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          return $null
     }
}

<#
.SYNOPSIS
    Retrieves an access token for Microsoft Graph API (Entra ID).

.DESCRIPTION
    Uses client credentials to obtain a bearer token for Microsoft Graph API.

.PARAMETER tenantId
    Azure AD tenant ID.

.PARAMETER clientId
    Azure AD application client ID.

.PARAMETER clientSecret
    Azure AD application client secret.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.OUTPUTS
    Microsoft Graph API access token string.
#>
function Get-EntraAccessToken {
     param (
          [string]$tenantId,
          [string]$clientId,
          [string]$clientSecret,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Attempting to acquire access token for tenant '$tenantId'" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
     $authRequestBody = @{
          client_id     = $clientId
          scope         = "https://graph.microsoft.com/.default"
          client_secret = $clientSecret
          grant_type    = "client_credentials"
     }
     try {
          Write-Log -Message "Sending authentication request to Microsoft Graph." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          $authResponse = Invoke-RestMethod `
               -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
               -Method POST `
               -Body $authRequestBody
          Write-Log -Message "Access token successfully acquired for tenant '$tenantId'" -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
          return $authResponse.access_token
     }
     catch {
          Write-Log -Message "Failed to acquire access token: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          exit 1
     }
}

<#
.SYNOPSIS
    Retrieves device data from the NinjaOne API.

.DESCRIPTION
    Calls the NinjaOne API to get detailed device information.

.PARAMETER clientId
    NinjaOne API client ID.

.PARAMETER clientSecret
    NinjaOne API client secret.

.PARAMETER apiEndpoint
    NinjaOne API endpoint for devices.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.OUTPUTS
    Array of device objects.
#>
function Get-NinjaDeviceData {
     param (
          [string]$clientId,
          [string]$clientSecret,
          $apiEndpoint,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Retrieving NinjaOne device data..." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     Write-Log -Message "Preparing to request device data from $apiEndpoint" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
     try {
          $token = Get-NinjaAccessToken -clientId $clientId -clientSecret $clientSecret -logPath $logPath -loggingLevel $loggingLevel
          if (-not $token) {
               Write-Log -Message "Failed to acquire NinjaOne access token." -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Failed to acquire NinjaOne access token."
          }
          $headers = @{
               'Authorization' = "Bearer $token"
               'Accept'        = 'application/json'
          }
          Write-Log -Message "Sending GET request to NinjaOne devices endpoint." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          $response = Invoke-RestMethod -Uri $apiEndpoint -Headers $headers -Method Get
          if ($response -and $null -ne $response) {
               Write-Log -Message "Successfully retrieved device data." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
               Write-Log -Message "Response:`n$($response | ConvertTo-Json -Depth 10)" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
               return $response
          }
          else {
               Write-Log -Message "Device data response was null." -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Response was null when retrieving devices"
          }
     }
     catch {
          Write-Log -Message "Error retrieving device data: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          throw $_
     }
}

<#
.SYNOPSIS
    Retrieves organization data from the NinjaOne API.

.DESCRIPTION
    Calls the NinjaOne API to get organization details by org ID.

.PARAMETER clientId
    NinjaOne API client ID.

.PARAMETER clientSecret
    NinjaOne API client secret.

.PARAMETER apiEndpoint
    NinjaOne API endpoint for organizations.

.PARAMETER orgID
    Organization ID to retrieve.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.OUTPUTS
    Organization object.
#>
function Get-NinjaOrgData {
     param (
          [string]$clientId,
          [string]$clientSecret,
          $apiEndpoint,
          $orgID,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Retrieving NinjaOne org data for OrgID: $orgID" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     Write-Log -Message "Preparing to request org data from $apiEndpoint/$orgID" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
     try {
          $token = Get-NinjaAccessToken -clientId $clientId -clientSecret $clientSecret -logPath $logPath -loggingLevel $loggingLevel
          if (-not $token) {
               Write-Log -Message "Failed to acquire NinjaOne access token." -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Failed to acquire NinjaOne access token."
          }
          $headers = @{
               'Authorization' = "Bearer $token"
               'Accept'        = 'application/json'
          }
          Write-Log -Message "Sending GET request to NinjaOne org endpoint." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          $response = Invoke-RestMethod -Uri "$apiEndpoint/$orgID" -Headers $headers -Method Get
          if ($response -and $null -ne $response) {
               Write-Log -Message "Successfully retrieved org data." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
               Write-Log -Message "Response:`n$($response | ConvertTo-Json -Depth 10)" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
               return $response
          }
          else {
               Write-Log -Message "Org data response was null." -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Response was null when retrieving devices"
          }
     }
     catch {
          Write-Log -Message "Error retrieving org data: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          throw $_
     }
}

<#
.SYNOPSIS
    Removes a device from NinjaOne by device ID.

.DESCRIPTION
    Calls the NinjaOne API to delete a device.

.PARAMETER clientId
    NinjaOne API client ID.

.PARAMETER clientSecret
    NinjaOne API client secret.

.PARAMETER apiEndpoint
    NinjaOne API endpoint for device deletion.

.PARAMETER deviceID
    Device ID to remove.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.OUTPUTS
    API response object.
#>
function Remove-NinjaDevice {
     param (
          [string]$clientId,
          [string]$clientSecret,
          $apiEndpoint,
          $deviceID,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Removing NinjaOne device with ID $deviceID..." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     Write-Log -Message "Preparing to send DELETE request to $apiEndpoint/$deviceID" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
     try {
          $token = Get-NinjaAccessToken -clientId $clientId -clientSecret $clientSecret -logPath $logPath -loggingLevel $loggingLevel
          if (-not $token) {
               Write-Log -Message "Failed to acquire NinjaOne access token." -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Failed to acquire NinjaOne access token."
          }
          $headers = @{
               'Authorization' = "Bearer $token"
               'Accept'        = 'application/json'
          }
          Write-Log -Message "Sending DELETE request to NinjaOne device endpoint." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          $response = Invoke-RestMethod -Uri "$apiEndpoint/$deviceID" -Headers $headers -Method Delete
          if ($response -and $null -ne $response) {
               Write-Log -Message "Successfully removed device." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
               Write-Log -Message "Response:`n$($response | ConvertTo-Json -Depth 10)" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
               return $response
          }
          else {
               Write-Log -Message "Device removal response was null." -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
               throw "Response was null when removing device`n$($response | ConvertTo-Json -Depth 10)"
          }
     }
     catch {
          Write-Log -Message "Error removing device: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          throw $_
     }
}

<#
.SYNOPSIS
    Generates HTML table rows for device reporting.

.DESCRIPTION
    Builds HTML table rows for each device, using cached org data when available.

.PARAMETER devices
    Array of device objects.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.PARAMETER ninjaClientId
    NinjaOne API client ID.

.PARAMETER ninjaClientSecret
    NinjaOne API client secret.

.PARAMETER ninjaOrgAPIEndpoint
    NinjaOne API endpoint for organizations.

.OUTPUTS
    String containing HTML table rows.
#>
function Create-TableRows {
     param (
          $devices,
          [string]$logPath,
          [int]$loggingLevel,
          [string]$ninjaClientId,
          [string]$ninjaClientSecret,
          [string]$ninjaOrgAPIEndpoint
     )
     Write-Log -Message "Generating HTML table rows for devices." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     $rows = foreach ($device in $devices) {
          $orgID = $device.organizationId
          $cachedOrg = $global:OrgCache.Values | Where-Object { $_.id -eq $orgID }
          if ($cachedOrg) {
               $org = $cachedOrg
               Write-Log -Message "Using cached org data for OrgID: $orgID" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
          }
          else {
               Write-Log -Message "Fetching org data for OrgID: $orgID" -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
               $org = Get-NinjaOrgData -clientId $ninjaClientId -clientSecret $ninjaClientSecret -apiEndpoint $ninjaOrgAPIEndpoint -orgID $orgID -logPath $logPath -loggingLevel $loggingLevel
               $global:OrgCache[$org.name] = $org
          }
          $siteName = $org.name
          $deviceName = $device.systemName
          $lastActivity = [DateTimeOffset]::FromUnixTimeSeconds([math]::truncate($device.lastContact)).DateTime
          $timeSinceLastActivity = New-TimeSpan -Start $lastActivity -End (Get-Date)
          $dateEnrolled = [DateTimeOffset]::FromUnixTimeSeconds([math]::truncate($device.created)).DateTime
          $lastUser = $device.lastLoggedInUser
          "<tr>
             <td>$orgID</td>
             <td>$siteName</td>
             <td>$deviceName</td>
             <td>$lastActivity</td>
             <td>$($timeSinceLastActivity.Days)</td>
             <td>$dateEnrolled</td>
             <td>$lastUser</td>
         </tr>"
     }
     Write-Log -Message "HTML table rows generated." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
     return $rows -join "`n"
}

<#
.SYNOPSIS
    Sends a notification email using Microsoft Graph API.

.DESCRIPTION
    Sends an HTML email with optional attachments via Microsoft Graph.

.PARAMETER fromEmailAddress
    The sender's email address.

.PARAMETER toEmailAddress
    The recipient's email address.

.PARAMETER subject
    Email subject.

.PARAMETER body
    Email body (HTML).

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.

.PARAMETER clientId
    Azure AD application client ID.

.PARAMETER clientSecret
    Azure AD application client secret.

.PARAMETER tenantId
    Azure AD tenant ID.

.PARAMETER Attachments
    Array of file paths to attach.
#>
function Send-NotificationEmail {
     param (
          [string]$fromEmailAddress,
          [string]$toEmailAddress,
          [string]$subject,
          [string]$body,
          [string]$logPath,
          [int]$loggingLevel,
          [string]$clientId,
          [string]$clientSecret,
          [string]$tenantId,
          [string[]]$Attachments = @()
     )
     Write-Log -Message "Attempting to acquire Graph API access token for email." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     $token = Get-EntraAccessToken -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret -logPath $logPath -LoggingLevel $loggingLevel
     Write-Log -Message "Preparing to send Graph API email with subject: '$subject'" -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     $graphApiUri = "https://graph.microsoft.com/v1.0/users/$fromEmailAddress/sendMail"
     $graphApiHeaders = @{
          Authorization  = "Bearer $token"
          "Content-Type" = "application/json"
     }
     $attachmentsArray = @()
     foreach ($filePath in $Attachments) {
          if (Test-Path $filePath) {
               Write-Log -Message "Attaching file: $filePath" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
               $bytes = [System.IO.File]::ReadAllBytes($filePath)
               $base64Content = [Convert]::ToBase64String($bytes)
               $attachmentsArray += @{
                    '@odata.type' = "#microsoft.graph.fileAttachment"
                    name          = [System.IO.Path]::GetFileName($filePath)
                    contentBytes  = $base64Content
                    contentType   = "text/csv"
               }
          }
          else {
               Write-Log -Message "Attachment file not found: $filePath" -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
          }
     }
     $payload = @{
          message = @{
               subject      = $subject
               body         = @{
                    contentType = "HTML"
                    content     = $body
               }
               toRecipients = @(
                    @{
                         emailAddress = @{
                              address = $toEmailAddress
                         }
                    }
               )
          }
     }
     if ($attachmentsArray.Count -gt 0) {
         $payload.message.attachments = $attachmentsArray
     }
     $payload = $payload | ConvertTo-Json -Depth 10
     try {
          Write-Log -Message "Sending email via Microsoft Graph API." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          Invoke-RestMethod -Uri $graphApiUri -Method POST -Headers $graphApiHeaders -Body $payload
          Write-Log -Message "Graph API email sent successfully." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
     }
     catch {
          Write-Log -Message "Graph API email failed: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
     }
}

<#
.SYNOPSIS
    Sends a notification message to Microsoft Teams.

.DESCRIPTION
    Posts a message card to a Teams channel via webhook.

.PARAMETER message
    The message text to send.

.PARAMETER teamsWebhookUrl
    The Teams webhook URL.

.PARAMETER logPath
    Path to the log directory.

.PARAMETER loggingLevel
    Logging verbosity level.
#>
function Send-TeamsNotification {
     param (
          $message,
          $teamsWebhookUrl,
          [string]$logPath,
          [int]$loggingLevel
     )
     Write-Log -Message "Sending Teams notification..." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     $payload = @{
          '@type'    = 'MessageCard'
          '@context' = 'http://schema.org/extensions'
          summary    = 'Devices Scheduled for Offboarding'
          themeColor = '0078D7'
          title      = 'Devices Scheduled for Offboarding After 90+ Days Offline'
          sections   = @(
               @{
                    text = $message
               }
          )
          attachments = @()
     }
     $body = ConvertTo-Json $payload
     try {
          Write-Log -Message "Posting message to Teams webhook." -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
          Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -ContentType 'application/json' -Body $body
          Write-Log -Message "Teams notification sent successfully." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
     }
     catch {
          Write-Log -Message "Failed to send Teams notification: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
     }
}

$dotenvPath = Join-Path $PSScriptRoot ".env"
if(-not (Test-Path $dotenvPath)) {
     Write-Log -Message "Configuration file .env not found at $dotenvPath" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
     exit 1
}
$config = Load-DotEnv -Path $dotenvPath
$ninjaDevicesAPIEndpoint = $config['NINJA_DEVICES_API_ENDPOINT']
$ninjaDeviceAPIEndpoint  = $config['NINJA_DEVICE_API_ENDPOINT']
$ninjaOrgAPIEndpoint     = $config['NINJA_ORG_API_ENDPOINT']
$ninjaClientId           = $config['NINJA_CLIENT_ID']
$ninjaClientSecret       = $config['NINJA_CLIENT_SECRET']
$emailSubject      = $config['EMAIL_SUBJECT']
$emailTenantId     = $config['EMAIL_TENANT_ID']
$emailClientId     = $config['EMAIL_CLIENT_ID']
$emailClientSecret = $config['EMAIL_CLIENT_SECRET']
$fromEmailAddress  = $config['FROM_EMAIL_ADDRESS']
$toEmailAddress    = $config['TO_EMAIL_ADDRESS']
$logPath       = Join-Path $PSScriptRoot ($config['LOG_PATH'] ?? "logs")
$loggingLevel  = [int]($config['LOGGING_LEVEL'] ?? 5)
$teamsWebhookUrl = $config['TEAMS_WEBHOOK_URL']
$lookbackPeriod = [int]($config['LOOKBACK_PERIOD'] ?? 90)
$thresholdDate = (Get-Date).AddDays(-$lookbackPeriod)

# Load excluded device names from excludeddevices.txt
$excludedDevicesPath = Join-Path $PSScriptRoot "excludeddevices.txt"
$excludedDeviceNames = @()
if (Test-Path $excludedDevicesPath) {
    $excludedDeviceNames = Get-Content $excludedDevicesPath | Where-Object { $_.Trim() -ne "" -and -not ($_.Trim().StartsWith("#")) }
    Write-Log -Message "Loaded $($excludedDeviceNames.Count) excluded device names from excludeddevices.txt." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
} else {
    Write-Log -Message "No excludeddevices.txt found. No devices will be excluded." -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
}

# Main processing section
try {
     Write-Log -Message "Script execution started." -Type "ALWAYS" -LogPath $logPath -LoggingLevel $loggingLevel
     try {
          Write-Log -Message "Retrieving device data from NinjaOne API." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
          $devices = Get-NinjaDeviceData -clientId $ninjaClientId -clientSecret $ninjaClientSecret -apiEndpoint $ninjaDevicesAPIEndpoint -logPath $logPath -loggingLevel $loggingLevel
          Write-Log -Message "Device data retrieval complete." -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel

          # Filter out excluded devices by systemName
          if ($excludedDeviceNames.Count -gt 0) {
              $devices = $devices | Where-Object { $excludedDeviceNames -notcontains $_.systemName }
              Write-Log -Message "Excluded devices filtered. $($devices.Count) devices remain after exclusion." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
          }

          if ($devices.Count -ge 0) {
               Write-Log -Message "Successfully retrieved [$($devices.Count)] devices." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
               $devices | export-csv -nti $PSScriptRoot\allninjadevices.csv
          }
          else {
               Write-Log -Message "No devices found." -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
          }
     }
     catch {
          Write-Log -Message "Failed retrieving device data - EXITING: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          exit(1)
     }
     
     # Filter devices offline for over 90 days
     Write-Log -Message "Filtering devices for inactivity threshold." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     $staleDevices = $devices | Where-Object { 
          $lastContactDate = [DateTimeOffset]::FromUnixTimeSeconds([math]::truncate($_.lastContact)).DateTime
          $lastContactDate -lt $thresholdDate
     }
     Write-Log -Message "Filtering complete. $($staleDevices.Count) devices found." -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel

     if ($staleDevices.Count -gt 0) {
          try {
               $staleDevices | export-csv -nti $PSScriptRoot\staleninjadevices.csv
               Write-Log -Message "Found $($staleDevices.Count) stale devices for offboarding." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
               $tableRows = Create-TableRows -devices $staleDevices -logPath $logPath -loggingLevel $loggingLevel -ninjaClientId $ninjaClientId -ninjaClientSecret $ninjaClientSecret -ninjaOrgAPIEndpoint $ninjaOrgAPIEndpoint
               
               # Export cached orgs to CSV
               if ($global:OrgCache.Values.Count -gt 0) {
                    $global:OrgCache.Values | Export-Csv -Path "$PSScriptRoot\ninjaorgs.csv" -NoTypeInformation
                    Write-Log -Message "Organization cache exported to CSV." -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
               }
               
               $emailBody = @"
<html>
<head>
     <style>
          table {
               width: 100%;
               border-collapse: collapse;
          }
          th, td {
               border: 1px solid black;
               padding: 8px;
               text-align: left;
          }
          th {
               background-color: #f2f2f2;
          }
     </style>
</head>
<body>
     <p>The following devices have been offline for over 90 days and are scheduled for offboarding:</p>
     <table>
          <tr>
               <th>Org ID</th>
               <th>Org Name</th>
               <th>Device Name</th>
               <th>Last Date of Activity</th>
               <th>Days Since Last Activity</th>
               <th>Date Enrolled</th>
               <th>Last Signed-In User</th>
          </tr>
          $tableRows
     </table>
</body>
</html>
"@
               $attachments = @(
                    "$PSScriptRoot\allninjadevices.csv",
                    "$PSScriptRoot\staleninjadevices.csv",
                    "$PSScriptRoot\ninjaorgs.csv"
               )
               Write-Log -Message "Sending notification email." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
               Send-NotificationEmail -clientId $emailClientId -clientSecret $emailClientSecret -tenantId $emailTenantId -fromEmailAddress $fromEmailAddress -toEmailAddress $toEmailAddress -subject $emailSubject -body $emailBody -logPath $logPath -LoggingLevel $loggingLevel -Attachments $attachments
          }
          catch {
               Write-Log -Message "Error during email notification process: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          }
          
          try {
               $teamsMessage = "The following devices have been offline for over 90 days and are scheduled for offboarding:`n"
               $staleDevices | ForEach-Object {
                    $teamsMessage += "`n**Site Name:** $($_.organizationId)"
                    $teamsMessage += "`n**Device Name:** $($_.systemName)"
                    $teamsMessage += "`n**Last Date of Activity:** $( [DateTimeOffset]::FromUnixTimeSeconds([math]::truncate($_.lastContact)).DateTime)"
                    $teamsMessage += "`n**Date Enrolled:** $([DateTimeOffset]::FromUnixTimeSeconds([math]::truncate($_.created)).DateTime)"
                    $teamsMessage += "`n**Last Signed-In User:** $($_.lastLoggedInUser)`n"
               }
               Write-Log -Message "Sending Teams notification." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
               Send-TeamsNotification -message $teamsMessage -teamsWebhookUrl $teamsWebhookUrl -logPath $logPath -loggingLevel $loggingLevel
          }
          catch {
               Write-Log -Message "Error during Teams notification process: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          }

          try {
               $staleDevices | ForEach-Object {
                    Write-Log -Message "Processing device for offboarding: $($_.deviceName)" -Type "TRACE" -LogPath $logPath -LoggingLevel $loggingLevel
                    try{
                         Write-Log -Message "Scheduled offboarding for device: $($_.deviceName)" -Type "DEBUG" -LogPath $logPath -LoggingLevel $loggingLevel
                         Remove-NinjaDevice -clientId $ninjaClientId -clientSecret $ninjaClientSecret -apiEndpoint $ninjaDeviceAPIEndpoint -deviceID $_.id -logPath $logPath -loggingLevel $loggingLevel
                         Write-Log "Scheduled offboarding for device: $($_.deviceName)" "SUCCESS" $logPath $loggingLevel
                    }catch{
                         Write-Log -Message "Error during device offboarding: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
                    }
               }
          }
          catch {
               Write-Log -Message "Error during device offboarding: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
          }
     }
     else {
          Write-Log -Message "No devices have been offline for over 90 days." -Type "INFO" -LogPath $logPath -LoggingLevel $loggingLevel
     }
     Write-Log -Message "Script execution completed." -Type "ALWAYS" -LogPath $logPath -LoggingLevel $loggingLevel
}
catch {
     Write-Log -Message "Unexpected error in main process: $_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
}
