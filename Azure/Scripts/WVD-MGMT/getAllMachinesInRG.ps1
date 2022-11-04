##Connecting
#install the powershell module for WVD/RDS management - REQUIRES ELEVATED PRIVLEDGES
Install-Module -Name az
#import the module for use
Import-Module -Name az
#connect to your Azure account
Connect-AzAccount

#set the subscription to the sub containing our  VMs
Select-AzSubscription "AZURE SUB NAME"

$logTo = "c:\temp\SSVMs.txt"
remove-item -Path $logTo

write-host "`n-----------------------------------`nPOOL 1`n-----------------------------------`n"
$resourceGroup = "RG name"
$ssName = "scaleset name"
$vms = Get-AzVmssvm -ResourceGroupName "$resourceGroup" -VMScaleSetName "$ssName" | select -ExpandProperty InstanceID
foreach($id in $vms){
    $vm = Get-AzVmssvm -ResourceGroupName "$resourceGroup" -VMScaleSetName "$ssName" -InstanceId $id
    #Write-host $vm.Name `t $vm.OsProfile.ComputerName
    Write-host "$($vm.OsProfile.ComputerName).domain.com"
    "$($vm.OsProfile.ComputerName).jbg.com" | out-file -filepath $logTo -Append
}