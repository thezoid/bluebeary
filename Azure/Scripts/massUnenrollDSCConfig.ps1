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

set-azcontext ""
$AAName = ""
$AARG = ""
$nodeConfigName = "STIGServer2019.localhost"
foreach($node in (Get-AzAutomationDscNode -ResourceGroupName $AARG -AutomationAccountName $AAName -ConfigurationName $nodeConfigName)){
    Write-host "$(get-date -format "yyyyMMMdd_hh:mm:ss") - Attempting to unregister $($node.name) from $AAName with $nodeConfigName"
    Unregister-AzAutomationDscNode -AutomationAccountName $AAName -ResourceGroupName $AARG -Id $node.Id -force
}
