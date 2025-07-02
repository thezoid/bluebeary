<#
.SYNOPSIS
    Links or updates the management partner (partnerId) on all Azure subscriptions and Microsoft 365 product SKUs (e.g., Teams, Power Automate) in the current tenant.
.DESCRIPTION
    This script validates module versions, installs missing modules if needed, then connects to Azure and Microsoft Graph and applies the specified partnerId across all subscriptions and SKUs.
.PARAMETER partnerId
    Your Microsoft Partner Network (MPN) ID (Partner Location Account ID).
.EXAMPLE
    .\Set-PartnerRecordAllProducts.ps1 -partnerId 12345
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$partnerId
)

function installAndImportModules {
    # Validate loaded Az.Accounts version
    $loadedAccounts = Get-Module -Name Az.Accounts
    if ($loadedAccounts) {
        if ($loadedAccounts.Version -lt [Version]'4.0.1') {
            Write-Host "Loaded Az.Accounts version $($loadedAccounts.Version) is below required 4.0.1. Please update Az.Accounts and restart PowerShell." -ForegroundColor Red
            exit 1
        }
    } else {
        # Check available versions
        $available = Get-Module -ListAvailable -Name Az.Accounts | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $available -or $available.Version -lt [Version]'4.0.1') {
            Write-Host "No Az.Accounts >= 4.0.1 detected. Installing..." -ForegroundColor Yellow
            Install-Module -Name Az.Accounts -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host 'Az.Accounts installed. Please restart PowerShell and rerun.' -ForegroundColor Yellow
            exit 1
        }
        Import-Module Az.Accounts -ErrorAction Stop
    }

    # Az
    if (-not (Get-Module -Name Az)) {
        Write-Host 'Installing Az module...' -ForegroundColor Yellow
        Install-Module -Name Az -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module Az -ErrorAction Stop

    # Az.ManagementPartner
    if (-not (Get-Module -ListAvailable -Name Az.ManagementPartner)) {
        Write-Host 'Installing Az.ManagementPartner module...' -ForegroundColor Yellow
        Install-Module -Name Az.ManagementPartner -Scope CurrentUser -Force -ErrorAction Stop
    }
    try {
        Import-Module Az.ManagementPartner -ErrorAction Stop
    } catch {
        Write-Host "Failed to import Az.ManagementPartner: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Microsoft.Graph
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
        Write-Host 'Installing Microsoft.Graph module...' -ForegroundColor Yellow
        Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module Microsoft.Graph -ErrorAction Stop
}

function connectToServices {
    $tenantId = (Get-AzTenant).TenantId
    Write-Host "Connecting to Azure (TenantId: $tenantId)..." -ForegroundColor Cyan
    Connect-AzAccount -TenantId $tenantId -ErrorAction Stop | Out-Null

    Write-Host "Connecting to Microsoft Graph (TenantId: $tenantId)..." -ForegroundColor Cyan
    Connect-MgGraph -TenantId $tenantId -Scopes 'Directory.ReadWrite.All','Organization.ReadWrite.All' -ErrorAction Stop | Out-Null
}

function setPartnerRecordOnAzureSubscriptions {
    param([string]$partnerId)
    $subscriptions = Get-AzSubscription -ErrorAction Stop
    foreach ($sub in $subscriptions) {
        Write-Host "Processing Azure subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Cyan
        try {
            Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null
            $existing = Get-AzManagementPartner -ErrorAction Stop
            if ($existing.PartnerId -ne $partnerId) {
                Write-Host 'Updating partner record on subscription...' -ForegroundColor Yellow
                Update-AzManagementPartner -PartnerId $partnerId | Out-Null
                Write-Host 'Subscription updated.' -ForegroundColor Green
            } else {
                Write-Host 'Already set; skipping.' -ForegroundColor Gray
            }
        } catch {
            Write-Host 'Creating partner record on subscription...' -ForegroundColor Yellow
            New-AzManagementPartner -PartnerId $partnerId | Out-Null
            Write-Host 'Subscription created.' -ForegroundColor Green
        }
    }
}

function setPartnerRecordOnProductSkus {
    param([string]$partnerId)
    $skuList = Get-MgSubscribedSku -ErrorAction Stop
    foreach ($sku in $skuList) {
        Write-Host "Processing SKU: $($sku.SkuPartNumber)" -ForegroundColor Cyan
        try {
            $body = @{ partnerInformation = @{ partnerId = $partnerId } }
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/subscribedSkus/$($sku.Id)" -Body ($body | ConvertTo-Json -Depth 3) -ContentType 'application/json' -ErrorAction Stop
            Write-Host 'SKU updated.' -ForegroundColor Green
        } catch {
            Write-Host "Failed on $($sku.SkuPartNumber): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Main
installAndImportModules
connectToServices
setPartnerRecordOnAzureSubscriptions -partnerId $partnerId
setPartnerRecordOnProductSkus -partnerId $partnerId

Write-Host 'Processing complete.' -ForegroundColor Green
