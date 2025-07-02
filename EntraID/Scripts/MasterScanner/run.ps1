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

# Helper to create .url shortcut
function New-UrlShortcut {
    param(
        [string]$TargetPath,
        [string]$ShortcutPath
    )
    $content = @"
[InternetShortcut]
URL=file:///$($TargetPath -replace '\\','/')
"@
    Set-Content -Path $ShortcutPath -Value $content -Encoding ASCII
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log -Message "This script must be run in PowerShell 7 or higher. Current version: $($PSVersionTable.PSVersion)" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
    exit 1
}

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

# --- Add shortcuts to reports at the root of the zip ---
# Build dynamic paths for the reports
$scubaFolder = Get-ChildItem -Path $resultsFolder -Directory | Where-Object { $_.Name -like "$tenantName-SCuBA*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$scubaReportPath = if ($scubaFolder) { Join-Path $scubaFolder.FullName "BaselineReports.html" } else { $null }

# Find the latest Maester test results HTML file
$maesterTestResultsDir = Join-Path $resultsFolder "maester-tests\test-results"
$maesterReportFile = if (Test-Path $maesterTestResultsDir) {
    Get-ChildItem -Path $maesterTestResultsDir -Filter "TestResults-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else { $null }
$maesterReportPath = if ($maesterReportFile) { $maesterReportFile.FullName } else { $null }

# Prepare temp folder for shortcuts
$tempShortcutDir = Join-Path $env:TEMP ("MasterScannerShortcuts_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempShortcutDir | Out-Null

# Create shortcuts if reports exist
$shortcutFiles = @()
if ($scubaReportPath -and (Test-Path $scubaReportPath)) {
    $scubaShortcut = Join-Path $tempShortcutDir "SCuBA_BaselineReports.url"
    New-UrlShortcut -TargetPath $scubaReportPath -ShortcutPath $scubaShortcut
    $shortcutFiles += $scubaShortcut
}
if ($maesterReportPath -and (Test-Path $maesterReportPath)) {
    $maesterShortcut = Join-Path $tempShortcutDir "Maester_TestResults.url"
    New-UrlShortcut -TargetPath $maesterReportPath -ShortcutPath $maesterShortcut
    $shortcutFiles += $maesterShortcut
}

if (Test-Path $resultsFolder) {
    try {
        Compress-Archive -Path "$resultsFolder\*" -DestinationPath $archivePath -Force
        # Add shortcuts to the root of the zip
        foreach ($shortcut in $shortcutFiles) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Update)
            try {
                $entryName = [System.IO.Path]::GetFileName($shortcut)
                $entry = $zip.CreateEntry($entryName)
                $stream = $entry.Open()
                [byte[]]$bytes = [System.IO.File]::ReadAllBytes($shortcut)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Close()
            } finally {
                $zip.Dispose()
            }
        }
        Write-Log -Message "Archived results to $archivePath" -Type "SUCCESS" -LogPath $logPath -LoggingLevel $loggingLevel
    } catch {
        Write-Log -Message "Failed to archive results folder`n$_" -Type "ERROR" -LogPath $logPath -LoggingLevel $loggingLevel
    } finally {
        # Clean up temp shortcut files
        Remove-Item -Path $tempShortcutDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Log -Message "Results folder not found at $resultsFolder" -Type "WARNING" -LogPath $logPath -LoggingLevel $loggingLevel
}
