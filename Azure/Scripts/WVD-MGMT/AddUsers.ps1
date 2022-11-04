#install the powershell module for WVD/RDS management - REQUIRES ELEVATED PRIVLEDGES
Install-Module -Name Microsoft.RDInfra.RDPowerShell
#import the module for use
Import-Module -Name Microsoft.RDInfra.RDPowerShell
#add an administratige account to manage RDS as
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"
$rdstenantname = "WVD TENANT NAME"
$hostpoolname = "WVD POOL NAME"
#an array to add many users at once
#each upn must be in quotes, and the list must be comma separated 
$toAdd = (
'user1@domain.com',
'user2@domain.com'
)
#loop through $toAdd and add all those users to the last specified pool
foreach($user in $toAdd){
    Write-host "Adding $user to $hostpoolname"
    Add-RdsAppGroupUser -TenantName $rdstenantname  -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group" -UserPrincipalName $user
}

