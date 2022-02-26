if (-not(get-module az)){
    try{
    import-module az
  }catch{
    install-module az
    import-module az
  }
}
try{
    get-azcontext
}catch{
    connect-azaccount
}

set-azcontext "target subscription"
$vmNames = (
"vm01name",
"vm02name"
)
$AAName = "automation account name"
$AARG = "automation account resource group"
$nodeConfigName = "DSC configuration name"
foreach($name in $vmNames){
    Write-host "$(get-date -format "yyyyMMMdd_hh:mm:ss") - Attempting to register $name to $AAName with $nodeConfigName"
    $vm = get-azvm -name $name
    Register-AzAutomationDscNode -AutomationAccountName $AAName -AzureVMName $vm.name -AzureVMResourceGroup $vm.resourcegroupname -ResourceGroupName $AARG -NodeConfigurationName $nodeConfigName -ActionAfterReboot ContinueConfiguration -ConfigurationMode ApplyAndMonitor
}
