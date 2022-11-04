#------------------------ESTABLISH CONNECTIONS----------------------------------
#install the powershell module for WVD/RDS management - REQUIRES ELEVATED PRIVLEDGES
Install-Module -Name Microsoft.RDInfra.RDPowerShell
#import the module for use
Import-Module -Name Microsoft.RDInfra.RDPowerShell
#add an administrative account to manage RDS as
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"

#------------------------STANDARD VARIABLES----------------------------------
$aadtenantid = "<ENTER ID>"
$azuresubscriptionid = "<ENTER ID>"
$rdsOwnerGroupID = "<ENTER ID>"
$rdsContributorGroupID = "<ENTER ID>"

#------------------------TENANT CREATION----------------------------------
#Create a new RDS Tenant - Most pools can be put under the same tenant
New-RdsTenant -Name $rdstenantname -AadTenantId $aadtenantid -AzureSubscriptionId $azuresubscriptionid

#DUPLICATE A POOL SECTION FOR EACH NEEDED POOL
#------------------------START OF POOL----------------------------------
$rdstenantname = "<ENTER TENANT NAME>"
$hostpoolname = "<ENTER POOL NAME>" 
$tokenPath = "c:\temp\$($hostpoolname)_token.txt"

#Setup AD groups to roles for administrating WVD
New-RdsRoleAssignment -RoleDefinitionName "RDS Owner" -GroupObjectId $rdsOwnerGroupID  -TenantGroupName "Default Tenant Group" -TenantName $rdstenantname
New-RdsRoleAssignment -RoleDefinitionName "RDS Contributor" -GroupObjectId $rdsContributorGroupID  -TenantGroupName "Default Tenant Group" -TenantName $rdstenantname

#Create a new RDS Host Pool (previously known as collection)
New-RdsHostPool -TenantName $rdstenantname -Name $hostpoolname

#Create a new RDS Desktop Group
New-RdsAppGroup -TenantName $rdstenantname -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group"

#limit RDS pool to only put one session per host
#additionally set the pool to use breadth first load balancing
Set-RdsHostPool -TenantName $rdstenantname -Name $hostpoolname -BreadthFirstLoadBalancer -MaxSessionLimit 1

#Generate Token
#this token is used for the CSE that automatically installs and configures the RDS agent
$token = New-RdsRegistrationInfo -TenantName $rdstenantname  -HostPoolName $hostpoolname -ExpirationHours 8760 | Select-Object -ExpandProperty Token
"$token" | Out-File $tokenPath
Write-host "Finished creating new pool $hostpoolname. Please find the token @ $tokenPath"
#------------------------END OF POOL----------------------------------