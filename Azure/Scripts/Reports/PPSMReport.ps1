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

$reportPath = "c:\temp\$(get-date -format "yyyyMMdd")networkreport.csv"
"Subscription,Resource Group,NSG Name,Rule Name,Priority,Direction (In/Out),Allow/Deny,Protocol,Source Address,Source Ports,Destination Address,Destination Ports,Attached to (Count)" | out-file $reportPath

$subs = get-azsubscription
foreach($sub in $subs){
    write-host "==========`nProcessing $($sub.Name)"
     $nsgs = Get-AzNetworkSecurityGroup
     foreach($nsg in $nsgs){
        write-host "`tProcessing $($nsg.Name)"
        foreach($rule in $nsg.SecurityRules){
            write-host "`t`tProcessing $($rule.name)"
            "$($sub.Name),$($nsg.ResourceGroupName),$($nsg.name),$($rule.name),$($rule.priority),$($rule.Direction),$($rule.Access),$($rule.Protocol),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.Count + $nsg.NetworkInterfaces.Count)" | out-file $reportPath -append
        }
        foreach($rule in $nsg.DefaultSecurityRules){
            write-host "`t`tProcessing [Default] $($rule.name)"
            "$($sub.name),$($nsg.ResourceGroupName),$($nsg.name),[Default] $($rule.name),$($rule.priority),$($rule.Direction),$($rule.Access),$($rule.Protocol),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.Count + $nsg.NetworkInterfaces.Count)" | out-file $reportPath -append
        }
     }
}