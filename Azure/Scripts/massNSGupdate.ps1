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

$subs = get-azsubscription
foreach($sub in $subs){
    Set-AzContext $sub
    $nsgs = Get-AzNetworkSecurityGroup
    foreach($nsg in $nsgs){
        #add inbound rule
        $nsg | Add-AzNetworkSecurityRuleConfig -Name AllowOnPremInbound -Description "Allow inbound connectivity from the internal IP ranges" -Access Allow -Protocol * -Direction Inbound -Priority 300 -SourceAddressPrefix 10.0.0.0/8 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *
        #add outbound rule
        $nsg | Add-AzNetworkSecurityRuleConfig -Name AllowOnPremOutbound -Description "Allow outbound connectivity to the internal IP ranges" -Access Allow -Protocol * -Direction Outbound -Priority 300 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix 10.0.0./8 -DestinationPortRange *
        $nsg | Set-AzNetworkSecurityGroup
    }
}