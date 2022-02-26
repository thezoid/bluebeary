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
$reportPath = "c:\temp\$(get-date -format "yyyyMMdd")vmreport.csv"
"VM Name, Subscription, Resource Group, VM Size, CPU, RAM (GB),IP,Data Disks (Name:SKU:Tier:Capacity in GB),Tags" | out-file $reportPath

$subs = get-azsubscription
foreach($sub in $subs){
    Set-AzContext $sub
    $vms = get-azvm
    foreach($vm in $vms){
        $line = ""  
        $size = Get-AzVMSize -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName | ?{$_.name -eq $vm.HardwareProfile.VmSize}
        #write-host "$($vm.Name),$($vm.ResourceGroupName),$($size.NumberOfCores),$($size.MemoryInMB/1024),"
        #get compute and org data
        $line += "$($vm.Name),$($sub.Name),$($vm.ResourceGroupName),$($vm.HardwareProfile.VmSize),$($size.NumberOfCores),$($size.MemoryInMB/1024),"
        #get all IPs for the VM
        foreach($nic in $vm.NetworkProfile.NetworkInterfaces){
            $n = Get-AzNetworkInterface -ResourceId $nic.id
            foreach($ipcon in $n.IpConfigurations){
                $line+= "$($ipcon.PrivateIpAddress);"
            }
        }
        #get data disks
        $line+= ","
        $line+= "$($vm.StorageProfile.OsDisk.Name):$($vm.StorageProfile.OsDisk.ManagedDisk.StorageAccountType):$((Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name).tier):$($vm.StorageProfile.OsDisk.DiskSizeGB);"
        foreach($disk in $vm.StorageProfile.DataDisks){
            $line+= "$($disk.Name):$($disk.ManagedDisk.StorageAccountType):$((Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $disk.Name).tier):$($disk.DiskSizeGB);"
        }
        #get tags
        $line+=","
        foreach($tag in $vm.Tags.Keys){
            $line+= "$($tag):$($vm.Tags.item($tag));"
        }
        
        write-host $line
        $line | out-file $reportPath -Append
    }
}

Write-host "Report complete" -foregroundcolor green 