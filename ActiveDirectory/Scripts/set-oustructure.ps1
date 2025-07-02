# Ensure script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator. Please restart PowerShell with elevated privileges."
    exit 1
}

Import-Module ActiveDirectory

# Get domain distinguished name
try {
    $domainDn = (Get-ADDomain).DistinguishedName
} catch {
    Write-Error "Could not get domain DN. Are you running on a domain-joined machine with permissions?"
    exit 1
}

# OU Structure Definitions
$ouList = @(
    "OU=Azure,$domainDn",
    "OU=DisabledObjects,$domainDn",
    "OU=Servers,OU=DisabledObjects,$domainDn",
    "OU=Users,OU=DisabledObjects,$domainDn",
    "OU=Workstations,OU=DisabledObjects,$domainDn",
    "OU=DomainUserComputers,$domainDn",
    "OU=DomainUsers,$domainDn",
    "OU=DomainUserGroups,OU=DomainUsers,$domainDn",
    "OU=PrivilegedUsers,OU=DomainUsers,$domainDn",
    "OU=DomainAdmin,OU=PrivilegedUsers,OU=DomainUsers,$domainDn",
    "OU=ServerAdmin,OU=PrivilegedUsers,OU=DomainUsers,$domainDn",
    "OU=WorkstationAdmin,OU=PrivilegedUsers,OU=DomainUsers,$domainDn",
    "OU=StandardUsers,OU=DomainUsers,$domainDn",
    "OU=TestUsers,$domainDn",
    "OU=100,OU=TestUsers,$domainDn",
    "OU=1000,OU=TestUsers,$domainDn",
    "OU=10000,OU=TestUsers,$domainDn",
    "OU=500,OU=TestUsers,$domainDn",
    "OU=5000,OU=TestUsers,$domainDn",
    "OU=EnterpriseServices,$domainDn",
    "OU=General,OU=EnterpriseServices,$domainDn",
    "OU=Groups,OU=General,OU=EnterpriseServices,$domainDn",
    "OU=Servers,OU=General,OU=EnterpriseServices,$domainDn",
    "OU=ServiceAccounts,OU=General,OU=EnterpriseServices,$domainDn",
    "OU=MS-SQL,OU=EnterpriseServices,$domainDn",
    "OU=PKI,OU=EnterpriseServices,$domainDn",
    "OU=SCCM,OU=EnterpriseServices,$domainDn",
    "OU=SCO,OU=EnterpriseServices,$domainDn",
    "OU=TrueNAS,OU=EnterpriseServices,$domainDn",
    "OU=EnterpriseSites,$domainDn"
)

# Create OUs if they do not exist
foreach ($ou in $ouList) {
    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$ou)" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name (($ou -split ',')[0] -replace 'OU=', '') -Path (($ou -split ',',2)[1])
    }
}

# Set StandardUsers as the default user creation OU
$standardUsersDn = "OU=StandardUsers,OU=DomainUsers,$domainDn"
Write-Host "Setting default user OU to: $standardUsersDn"
try {
    redirusr $standardUsersDn
} catch {
    Write-Warning "Unable to set default user OU. $_"
}

# Set DomainUserComputers as the default computer creation OU
$domainUserComputersDn = "OU=DomainUserComputers,$domainDn"
Write-Host "Setting default computer OU to: $domainUserComputersDn"
try {
    redircmp $domainUserComputersDn
} catch {
    Write-Warning "Unable to set default computer OU. $_"
}

# Enable AD Recycle Bin
try {
    $forest = Get-ADForest
    $forestDn = $forest.DistinguishedName
    Write-Host "Forest DN: $forestDn"
    if ($null -ne $forestDn -and $forestDn -ne "") {
        Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $forestDn -ErrorAction Stop
        Write-Host "AD Recycle Bin enabled."
    } else {
        Write-Warning "Forest distinguished name is null or empty. Skipping AD Recycle Bin enablement."
    }
} catch {
    Write-Warning "Unable to enable AD Recycle Bin: $_"
}

# Set Tombstone Lifetime to 30 days
try {
    $rootDse = Get-ADRootDSE
    $configDn = $rootDse.configurationNamingContext
    $dsDn = "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$configDn"
    Write-Host "Directory Service DN: $dsDn"
    $adObject = Get-ADObject -Identity $dsDn -ErrorAction Stop
    Set-ADObject $dsDn -Replace @{'tombstoneLifetime' = 30}
    Write-Host "Tombstone lifetime set to 30 days."
} catch {
    Write-Warning "Unable to set tombstone lifetime: $_"
}

Write-Output "OU Structure created, defaults set, AD Recycle Bin enabled (if possible), and tombstone lifetime set to 30 days (if possible)."
