#CAUTION - THIS SCRIPT IS TO BE RAN IN PARTS OR USED AS REFERENCE ONLY - DO NOT RUN ITS ENTIRETY
write-host "CAUTION - THIS SCRIPT IS TO BE RAN IN PARTS OR USED AS REFERENCE ONLY - DO NOT RUN ITS ENTIRETY" -BackgroundColor Red -ForegroundColor yellow
exit

##Connecting
#install the powershell module for WVD/RDS management - REQUIRES ELEVATED PRIVLEDGES
Install-Module -Name Microsoft.RDInfra.RDPowerShell -force
#import the module for use
Import-Module -Name Microsoft.RDInfra.RDPowerShell
#add an administratige account to manage RDS as
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"

 
#standard vars
$aadtenantid = "<ENTER ID>"
$azuresubscriptionid = "<ENTER ID>"
$appgroupname =  "Desktop Application Group"
$rdstenantname = "<ENTER TENANT NAME>"

#STORE POOL NAMES IN VARS HERE FOR EASIER MULTI-POOL MANAGEMENT
#POOL1
$hostpoolname = "POOL1"
#POOL2
$hostpoolname = "POOL2"
#POOL3
$hostpoolname = "POOL3"

#--------------------------------------
#       Creation
#       FOR FIRST TIME CREATION, DEFER TO Establish-WVD.ps1
#--------------------------------------
#Create a new RDS Tenant - Most pools can be put under the same tenant
New-RdsTenant -Name $rdstenantname -AadTenantId $aadtenantid -AzureSubscriptionId $azuresubscriptionid
#Create a new RDS Host Pool (previously known as collection)
New-RdsHostPool -TenantName $rdstenantname -Name $hostpoolname

#set a friendly name
Set-RdsRemoteDesktop -TenantName $rdstenantname -HostPoolName $hostpoolname -AppGroupName $appgroupname -FriendlyName $hostpoolname
Get-RdsRemoteDesktop -TenantName $rdstenantname -HostPoolName $hostpoolname -AppGroupName $appgroupname

#limit RDS pool to only put one session per host
set-RdsHostPool -TenantName $rdstenantname -Name $hostpoolname -BreadthFirstLoadBalancer -MaxSessionLimit 1

##Generate Token
#this token is used for the script that automatically installs and configures the RDS agent on the 
New-RdsRegistrationInfo -TenantName $rdstenantname  -HostPoolName $hostpoolname -ExpirationHours 1440 | Select-Object -ExpandProperty Token
#get the token needed for RDS agent scripts from a created pool
Export-RdsRegistrationInfo -TenantName $rdstenantname -HostPoolName $hostpoolname | Select-Object -ExpandProperty Token

#--------------------------------------
#     Management
#--------------------------------------
#Pull back the session hosts and how many sessions they have 
Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,sessions,status,lastheartbeat | Sort-Object status,Sessions,sessionhostname 
$removeHosts = Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select -expandproperty SessionHostName
#get all user sessions of a host pool
#use this to figure out which machine to jump
Get-RdsUserSession -TenantName $rdstenantname -HostPoolName $hostpoolname | select AdUserName,SessionHostName,sessionid,sessionstate | Sort-Object sessionstate,adusername, sessionhostname 

#attempt to force a user disconnect (not sign off)
Disconnect-RdsUserSession -TenantName $rdstenantname -HostPoolName $hostpoolname -SessionHostName 'hostname.domain.com'  -SessionId "60" -NoUserPrompt

#remove OLD sessions - DO NOT REMOVE CURRENT SESSIONS
#this helps get rid of stale session hosts when scaling down a scale set
$removeHosts = (
'hostname.domain.com'
)
foreach($h in $removeHosts){
    Write-host "Removing $h from $hostpoolname"
    Remove-RdsSessionHost -TenantName $rdstenantname  -HostPoolName $hostpoolname -Name $h -force
}

#get the token needed for RDS agent scripts from a created pool
Export-RdsRegistrationInfo -TenantName $rdstenantname -HostPoolName $hostpoolname | Select-Object -ExpandProperty Token

#attempt to force a user disconnect (not sign off)
Disconnect-RdsUserSession -TenantName $rdstenantname -HostPoolName $hostpoolname -SessionHostName 'hostname.domain.com'  -SessionId "60" -NoUserPrompt
#log off user session
Invoke-RdsUserSessionLogoff -TenantName $rdstenantname -HostPoolName $hostpoolname -SessionHostName 'hostname.domain.com'  -SessionId "49" -NoUserPrompt
#search for user session and log it off
Get-RdsUserSession -TenantName $rdstenantname -HostPoolName $hostpoolname | where { $_.UserPrincipalName -eq "domain\user" } | Invoke-RdsUserSessionLogoff -NoUserPrompt

#--------------------------------------
#     Permissions
#--------------------------------------

#an array to add many users at once
#each upn must be in quotes, and the list must be comma separated 
$toAdd = (
'user@domain.com'
)

#loop through $toAdd and add all those users to the last specified pool
foreach($user in $toAdd){
    Write-host "Adding $user to $hostpoolname"
    Add-RdsAppGroupUser -TenantName $rdstenantname  -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group" -UserPrincipalName $user
}

#loop through $toAdd and remove all those users to the last specified pool
foreach($user in $toAdd){
    Write-host $user
    Remove-RdsAppGroupUser -TenantName $rdstenantname  -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group" -UserPrincipalName $user
}

#get all the RDS role assignments of a user
Get-RdsRoleAssignment -SignInName  "user@domain.com"

#List all users who have been assigned to an app group
Get-RdsAppGroupUser -TenantName $rdstenantname -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group" | select userprincipalname
#Check if a specific user has been assigned to an app group
Get-RdsAppGroupUser -TenantName $rdstenantname -HostPoolName $hostpoolname -AppGroupName "Desktop Application Group" -UserPrincipalName "user@domain.com"

#Get error logs for the specified user in the specified pool - note a specific ActivityID
Get-RdsDiagnosticActivities -TenantName $rdstenantname -username "user@domain.com"
#Use a noted ActivityID from above with the commands below to get more details
(Get-RdsDiagnosticActivities -TenantName $rdstenantname -username "user@domain.com"-ActivityId <PUT ActivityID HERE> -Detailed).details 
(Get-RdsDiagnosticActivities -TenantName $rdstenantname -username "user@domain.com" -ActivityId <PUT ActivityID HERE> -Detailed).errors

#restart a list of machines that may be erroring out or have stuck, old user sessions
$toRestart=(
"aHost0012354.domain.com"
)
$cred = get-credential
foreach($machine in $toRestart){
    write-host $machine
    Restart-Computer -ComputerName $machine -Credential $cred -Force
}