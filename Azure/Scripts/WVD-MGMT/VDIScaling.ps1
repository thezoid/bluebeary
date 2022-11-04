#read in encrypted credentials
$user = "svc_wvd_scaling@domain.com"
$password = Get-Content "C:\WVDAutomation\scalescript.pw" | ConvertTo-SecureString 
$credential = New-Object System.Management.Automation.PsCredential($user,$password)

#import the module for use
Import-Module -Name Microsoft.RDInfra.RDPowerShell
#add an administratige account to manage RDS as
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com" -Credential $credential
#import the module for use
Import-Module -Name az
#connect to your Azure account
Connect-AzAccount -Credential $credential
#set the subscription to the sub containing our  VMs2
Select-AzSubscription "azure sub name"

Start-Transcript "c:\temp\WVDLogs\corpCommScaling.log"

#pool1
$rdstenantname = "wvd tenant name"
$hostpoolname = "pool1"
$RGName = "wvd rg name" 
$VMSSName = "wvd ss name"

#the total number of hosts in the pool
$maxHosts = (Get-AzVmssvm -ResourceGroupName $RGName -VMScaleSetName $VMSSName).count
#the number current active users
$currentSessions = (Get-RdsUserSession -TenantName $rdstenantname -HostPoolName $hostpoolname | select SessionState | where {$_.SessionState -eq "Active"}).count
#the number of active hosts that can be connected to
$availableHosts = (Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,status| where {$_.status -eq "Available"}).count
#5% of the pool size
$scaleUpBuffer = [int][Math]::Ceiling(0.05 * $maxHosts)
$scaleUpPercentage = 0.05
#15% of the pool size
$scaleDownBuffer = [int][Math]::Ceiling(0.15 * $maxHosts)
$scaleDownPercentage = 0.85
$scaleDownTriggerPercentage = 0.15
$minimumActiveHosts = [int][Math]::Ceiling(0.10 * $maxHosts)
Write-host "`n----------------------------------------`nScaling $hostpoolname WVD Pool`n----------------------------------------`n"
Write-host "Max Hosts: $maxHosts`nMinimum active hosts: $minimumActiveHosts`nScale up buffer: $scaleUpBuffer`nScale up percentage: $scaleUpPercentage`nScale down buffer: $scaleDownBuffer`nScale down percentage: $scaleDownPercentage`nScale down percentage: $scaleDownTriggerPercentage`nCurrent Sessions: $currentSessions`nAvailable hosts: $availableHosts"

#check if we need to scale up to have a buffer of 5% of the max machines
if( ($availableHosts - $currentSessions) -le $scaleUpBuffer){
    #turn on $buffer machines
    write-host "turn on $scaleUpBuffer machines"
    $scaleUpTo = [int][Math]::Ceiling($scaleUpPercentage * $maxHosts)
    #get all the VMs in the scale set
    $vms = Get-AzVmssvm -ResourceGroupName $RGName -VMScaleSetName $VMSSName | select -ExpandProperty InstanceID
    #get all machines not available
    $machinesNotInUse = Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,sessions,status | where {$_.status -ne "Available"} | select sessionhostname
    #tracker for how many jobs have been started
    #this stops too many jobs from being triggered, allowing us to run VM updates asynchronously
    $jobsStarted = 0
    foreach($machine in $machinesNotInUse){
        #report we're at max capacity
        if($availableHosts -eq $maxHosts ){
            Write-host "we are at max capacity!" -ForegroundColor Red
            break2
        }
        #report we've scaled up to our target
        if($availableHosts -eq $scaleUpTo -or $jobsStarted -eq $scaleUpBuffer){
            Write-host "Scaled up to buffer!"
            break
        }
        #attempt to turn on the machine not in use
        write-host "attempting to turn on $($machine.SessionHostName)" -forcegroundcolor yellow
        $count = 0
        #loop through all VMs in a scale set and check if they're a machine reporting unavailable in the WVD pool
        #if there is a match, start that machine and break out of the loop, allowing the next machine to be tested
        foreach($id in $vms){
            $count++
            $vm = Get-AzVmssvm -ResourceGroupName $RGName -VMScaleSetName $VMSSName -InstanceId $id
            write-host "`t`t[$count/$($vms.Count)]checking against $($vm.OsProfile.ComputerName).domain.com"
            if("$($vm.OsProfile.ComputerName).domain.com" -eq $machine.SessionHostName){
                Write-host "`t`t`tstarting $($machine.SessionHostName)" -foregroundcolor green
                Start-AzVmss -ResourceGroupName $RGName -VMScaleSetName $VMSSName -InstanceId $id -AsJob
                $jobsStarted++
                break
            }else{
                write-host "`t`t`talready on..." -ForegroundColor Yellow
            }
        }
        #update our available host count
        $availableHosts = (Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,status| where {$_.status -eq "Available"}).count
    }
}
#check if we need to scale down
#scale down if $scaleDownTriggerPercentage of the $availableHosts are not being used
elseif(($availableHosts - $currentSessions) -gt ($scaleDownTriggerPercentage * $availableHosts)){
    #turn off machines until only buffer remains
    write-host "turning off $([int][Math]::Floor($scaleDownTriggerPercentage * $availableHosts)) machines"
    $scaleDownTo = [int][Math]::Floor($scaleDownPercentage * $availableHosts)
    write-host "scaling down to $scaleDownTo machines"
    #get all the VMs in the scale set
    $vms = Get-AzVmssvm -ResourceGroupName $RGName -VMScaleSetName $VMSSName | select -ExpandProperty InstanceID
    #get all the machines currently not hosting a user session
    $machinesNotInUse = Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,sessions,status | where {$_.Sessions -eq 0}
    #tracker for how many jobs have been started
    #this stops too many jobs from being triggered, allowing us to run VM updates asynchronously
    $jobsStarted = 0
    foreach($machine in $machinesNotInUse){
        #report we're at minimum capacity and stop
        if($availableHosts -eq $minimumActiveHosts){
            Write-host "we are at min capacity!" -ForegroundColor Red
            break
        }
        #report we've scaled down and stop
        #additionally triggers if all our jobs have been kicked off
        if($availableHosts -eq $scaleDownTo -or 
            $jobsStarted -eq [int][Math]::Floor($scaleDownTriggerPercentage * $availableHosts)){
            Write-host "Scaled down to $scaleDownTo hosts"
            break
        }
        #check again if the machine isnt hosting a user session
        #loop through all VMs and turn them off if they arent hosting user sessions
        if($machine.sessions -eq 0){
            $count = 0
            foreach($id in $vms){
                $count++
                $vm = Get-AzVmssvm -ResourceGroupName $RGName -VMScaleSetName $VMSSName -InstanceId $id
                write-host "`t`t[$count/$($vms.Count)]checking against $($vm.OsProfile.ComputerName).domain.com"
                if("$($vm.OsProfile.ComputerName).domain.com" -eq $machine.SessionHostName){
                    $jobsStarted++
                    Write-host "`t`t`t[$jobsStarted/$([int][Math]::Floor($scaleDownTriggerPercentage * $availableHosts))]turning off $($machine.SessionHostName)" -foregroundcolor green
                    Stop-AzVmss -ResourceGroupName $RGName -VMScaleSetName $VMSSName -InstanceId $id -Force -AsJob
                    break
                }
            }
        }else{
            write-host "`t`t`t[$($machine.SessionHostName)]active user session..." -ForegroundColor Yellow
        }
        #update the host count
        $availableHosts = (Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,status| where {$_.status -eq "Available"}).count
    }
}

Stop-Transcript