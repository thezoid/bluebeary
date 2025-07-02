<#
.SYNOPSIS
    Generates a report of files in an Azure File Share sorted by file size.
.DESCRIPTION
    Connects to Azure via browser-based authentication, lists all files in the specified file share (recursively), and outputs Name, Uri, Length (Bytes), and LastModified, sorted by size descending.
.PARAMETER resourceGroupName
    Name of the resource group containing the storage account.
.PARAMETER storageAccountName
    Name of the storage account.
.PARAMETER shareName
    Name of the Azure file share.
.EXAMPLE
    .\Get-AzFileShareContentsReport.ps1 -resourceGroupName "RG1" -storageAccountName "mystorage" -shareName "myshare"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$shareName
)

function Ensure-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$moduleName
    )
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        try {
            Write-Host "Installing module $moduleName..." -ForegroundColor Yellow
            Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
        } catch {
            Write-Error "Failed to install module $moduleName. $_"
            exit 1
        }
    }
    try {
        Import-Module $moduleName -ErrorAction Stop
    } catch {
        Write-Error "Failed to import module $moduleName. $_"
        exit 1
    }
}

# Ensure required modules
Ensure-Module -moduleName Az.Accounts
Ensure-Module -moduleName Az.Storage

# Connect to Azure via browser
try {
    Write-Host "Opening browser for Azure login..." -ForegroundColor Cyan
    Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop
} catch {
    Write-Error "Azure browser login failed. $_"
    exit 1
}

# Get storage context
try {
    $storageKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -ErrorAction Stop
    $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKeys[0].Value -ErrorAction Stop
} catch {
    Write-Error "Failed to get storage account context. $_"
    exit 1
}

# List files recursively
try {
    $files = Get-AzStorageFile -Context $ctx -ShareName $shareName -Path "/" -Recurse -ErrorAction Stop
} catch {
    Write-Error "Failed to retrieve file list from share '$shareName'. $_"
    exit 1
}

# Build report
$report = $files | Select-Object `
    @{Name='Name';Expression={ $_.Name }}, `
    @{Name='Uri';Expression={ $_.CloudFile.Uri.AbsoluteUri }}, `
    @{Name='LengthBytes';Expression={ $_.Properties.Length }}, `
    @{Name='LastModified';Expression={ $_.Properties.LastModified.UtcDateTime.ToString('u') }} |
    Sort-Object LengthBytes -Descending

# Output report
$report | Format-Table -AutoSize
