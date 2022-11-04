$vnetReportPath = "$PSScriptRoot\$(get-date -format "yyyyMMMdd")networkReport.csv"
$routeReportPath = "$PSScriptRoot\$(get-date -format "yyyyMMMdd")routeReport.csv"
$nsgReportPath = "$PSScriptRoot\$(get-date -format "yyyyMMMdd")nsgReport.csv"
"Subscription,Resource Group,VNET Name,VNET AddressSpace,VNET DNS Servers,Subnet Name,Subnet Address Space" | out-file $vnetReportPath
"Subscription,Resource Group,Route Table Name,Route Name,Route Prefix,Route Next Hop Type,Route Next Hop" | out-file $routeReportPath
"Subscription,Resource Group,Name,Rule Name,Priority,Direction (In/Out),Allow/Deny,Protocol,Source Address,Source Ports,Destination Address,Destination Ports,Attached to (Count), Attached To Subnets, Attached To NICs" | out-file $nsgreportPath
$subs = get-azsubscription | select -expandpropert name
foreach ($sub in $subs){
    set-azcontext $sub
    #get and process RTs
    foreach($routeTable in get-azroutetable){
        foreach($route in $routeTable.RoutesText){
            #route comes as a string thats json
            ## break it down to processible objects, then loop through those to get actual report data
            $route = ConvertFrom-Json $route
            foreach($r in $route){
                "$sub,$($routeTable.ResourceGroupName),$($routeTable.name),$($r.name),$($r.AddressPrefix),$($r.NextHopType),$($r.NextHopIpAddress)" | out-file $routeReportPath -append
            }
        }
    }
    #get all network details
    foreach($vnet in get-azvirtualnetwork){
        foreach($subnet in $vnet.subnets){
            "$sub,$($vnet.ResourceGroupName),$($vnet.name),$((convertfrom-json $vnet.AddressSpaceText).AddressPrefixes.replace(",",";")),$($vnet.DhcpOptions.DnsServers),$($subnet.name),$($subnet.AddressPrefix)" | out-file $vnetReportPath -append
        }
    }

    #get all nsg details
    foreach($nsg in (Get-AzNetworkSecurityGroup)){
        foreach($rule in $nsg.SecurityRules){
            "$sub,$($nsg.ResourceGroupName),$($nsg.name),$($rule.name),$($rule.priority),$($rule.Direction),$($rule.Access),$($rule.Protocol),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.Count + $nsg.NetworkInterfaces.Count),$(($nsg.Subnets | %{$_.id.split("/")[-1]})),$(($nsg.NetworkInterfaces | %{$_.id.split("/")[-1]}))" | out-file $nsgReportPath -append
        }
        foreach($rule in $nsg.DefaultSecurityRules){
            "$sub,$($nsg.ResourceGroupName),$($nsg.name),[Default] $($rule.name),$($rule.priority),$($rule.Direction),$($rule.Access),$($rule.Protocol),$($rule.SourceAddressPrefix),$($rule.SourcePortRange),$($rule.DestinationAddressPrefix),$($rule.DestinationPortRange),$($nsg.Subnets.Count + $nsg.NetworkInterfaces.Count),$(($nsg.Subnets | %{$_.id.split("/")[-1]})),$(($nsg.NetworkInterfaces | %{$_.id.split("/")[-1]}))" | out-file $nsgReportPath -append
        }
    }

}
