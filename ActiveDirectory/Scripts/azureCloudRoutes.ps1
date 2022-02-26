param(
     $targetRGName,
     $targetRTName     
)
if(-not $targetRGName -or -not $targetRGName -or $targetRGName -eq "" -or $targetRTName -eq ""){throw "Invalid flag values provided"}
#download the tag json here: https://www.microsoft.com/en-us/download/details.aspx?id=56519
#set the address prefix to the services you want to next hop to the internet, side dooring your backplane traffic directly to the azure backbone
#prefix can be specified to regions by taking the region specific version of the service tag - ex. AzureCloud.eastus2
#note: not all service tags have region lock, thus you must refer to the json from the link above
$rt = Get-AzRouteTable -ResourceGroupName $targetRGName -Name $targetRTName
Add-AzRouteConfig -Name "Backbone-AzureCloud" -AddressPrefix "AzureCloud" -NextHopType "Internet" -RouteTable $rt
Add-AzRouteConfig -Name "Backbone-AzureMonitor" -AddressPrefix "AzureMonitor" -NextHopType "Internet" -RouteTable $rt
Add-AzRouteConfig -Name "Backbone-AzureStorage" -AddressPrefix "Storage" -NextHopType "Internet" -RouteTable $rt
Add-AzRouteConfig -Name "Backbone-AzureGuestAndHybridMGMT" -AddressPrefix "GuestAndHybridManagement" -NextHopType "Internet" -RouteTable $rt
Add-AzRouteConfig -Name "Backbone-AzureActiveDirectory" -AddressPrefix "AzureActiveDirectory" -NextHopType "Internet" -RouteTable $rt
Add-AzRouteConfig -Name "Backbone-APIMGMT-GovVA" -AddressPrefix "ApiManagement" -NextHopType "Internet" -RouteTable $rt
Set-AzRouteTable -RouteTable $rt

