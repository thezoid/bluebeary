# Function to ensure the Az module is available
function Ensure-AzModule {
     if (!(Get-Module -ListAvailable -Name Az)) {
          Write-Host "Az module not found. Attempting to install..."
 
          try {
               Install-Module -Name Az -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
               Write-Host "Az module installed successfully."
          }
          catch {
               Write-Error "Failed to install the Az module. Ensure you have network access and sufficient permissions."
               Exit 1
          }
     }
 
     try {
          Import-Module -Name Az -ErrorAction Stop
          Write-Host "Az module imported successfully."
     }
     catch {
          Write-Error "Failed to import the Az module. Ensure it is installed correctly."
          Exit 1
     }
}
 
# Function to ensure the Azure Resource Group exists
function Ensure-AzResourceGroup {
     param (
          [string]$resourceGroupName,
          [string]$location
     )
 
     $rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
     if (-not $rg) {
          Write-Host "Resource group '$resourceGroupName' not found. Creating it..."
          New-AzResourceGroup -Name $resourceGroupName -Location $location
          Write-Host "Resource group '$resourceGroupName' created successfully."
     }
     else {
          Write-Host "Resource group '$resourceGroupName' already exists."
     }
}
 
# Function to ensure the Azure DNS Zone exists
function Ensure-AzDnsZone {
     param (
          [string]$zoneName,
          [string]$resourceGroupName
     )
 
     $zone = Get-AzDnsZone -Name $zoneName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
     if (-not $zone) {
          Write-Host "DNS zone '$zoneName' not found. Creating it..."
          New-AzDnsZone -Name $zoneName -ResourceGroupName $resourceGroupName
          Write-Host "DNS zone '$zoneName' created successfully."
     }
     else {
          Write-Host "DNS zone '$zoneName' already exists."
     }
}

function Get-GoDaddyDNSRecords {
     param (
          [string]$domain,
          [string]$apiKey,
          [string]$apiSecret
     )
 
     $headers = @{
          Authorization = 'sso-key ' + $apiKey + ':' + $apiSecret
     }
     $uri = "https://api.godaddy.com/v1/domains/$domain/records"
 
     $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
     return $response
}

#godaddy domain
$domain = "yourdomain.com"
#godaddy api key
$apiKey = "your_api_key"
#godaddy api secret
$apiSecret = "your_api_secret"
#the rg your zone is in
$resourceGroupName = "YourResourceGroup"
#the name of your Azure DNS zone
$zoneName = "yourdomain.com"
$azLocation = "East US 2"

# GoDaddy
$dnsRecords = Get-GoDaddyDNSRecords -domain $domain -apiKey $apiKey -apiSecret $apiSecret
#create a log of records for archival purposes
$dnsRecords | ConvertTo-Json | out-file "$PSScriptRoot/GoDaddyDNSRecords.json"

#Azure
Ensure-AzModule
Connect-AzAccount
Ensure-AzResourceGroup -resourceGroupName $resourceGroupName -location $azLocation
Ensure-AzDnsZone -zoneName $zoneName -resourceGroupName $resourceGroupName
foreach ($record in $dnsRecords) {
     $recordName = if ($record.name -eq "@") { $zoneName } else { $record.name }
     $recordType = $record.type
     $ttl = $record.ttl

     switch ($recordType) {
          "A" {
               $dnsRecord = New-AzDnsRecordConfig -IPv4Address $record.data
          }
          "AAAA" {
               $dnsRecord = New-AzDnsRecordConfig -IPv6Address $record.data
          }
          "CNAME" {
               $dnsRecord = New-AzDnsRecordConfig -Cname $record.data
          }
          "MX" {
               $dnsRecord = New-AzDnsRecordConfig -Preference $record.priority -Exchange $record.data
          }
          "TXT" {
               $dnsRecord = New-AzDnsRecordConfig -Value $record.data
          }
          "SRV" {
               $dnsRecord = New-AzDnsRecordConfig -Priority $record.priority -Weight $record.weight -Port $record.port -Target $record.data
          }
          "NS" {
               $dnsRecord = New-AzDnsRecordConfig -Nsdname $record.data
          }
          "PTR" {
               $dnsRecord = New-AzDnsRecordConfig -Ptrdname $record.data
          }
          default {
               Write-Host "Record type $recordType is not supported."
               continue
          }
     }

     # Create the record set in Azure DNS
     New-AzDnsRecordSet -Name $recordName -RecordType $recordType -ZoneName $zoneName -ResourceGroupName $resourceGroupName -Ttl $ttl -DnsRecords $dnsRecord
}