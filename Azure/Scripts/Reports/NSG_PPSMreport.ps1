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
$reportPath = "c:\temp\$(get-date -format "yyyyMMdd")nsgReport.csv"
"Subscription,Resource Group,NSG Name,Rule Name,Priority,Direction (In/Out),Allow/Deny,Protocol,Source Address,Source Ports,Destination Address,Destination Ports,Attached to (Count)" | out-file $reportPath

$subs = get-azsubscription
foreach($sub in $subs){
    Write-host "Processing $($sub.name)"
    Set-AzContext $sub
    $nsgs = Get-AzNetworkSecurityGroup
    foreach($nsg in $nsgs){
        Write-host "`tProcessing $($nsg.Name)"
        foreach($rule in $nsg.DefaultSecurityRules){
            write-host "`t`t`Processing [Default] $($rule.name)"
           "$($sub.name),$($nsg.ResourceGroupName),$($nsg.Name),[Default] $($rule.name),$($rule.priority),$($rule.direction),$($rule.access),$($rule.priority),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.count + $nsg.NetworkInterfaces.Count)" | out-file $reportPath -Append
        }
        foreach($rule in $nsg.SecurityRules){
            write-host "`t`t`Processing $($rule.name)"
            "$($sub.name),$($nsg.ResourceGroupName),$($nsg.Name),$($rule.name),$($rule.priority),$($rule.direction),$($rule.access),$($rule.priority),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.count + $nsg.NetworkInterfaces.Count)" | out-file $reportPath -Append
        }
    }
}