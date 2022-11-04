import-module msonline
Connect-MsolService
#$users = get-content "c:\temp\users.txt"
$users = get-msoluser -all | select -ExpandProperty UserPrincipalName
$count = 0
$headers = "Username`t"
$report = ""
foreach ($user in $users){
    $count += 1
    Write-host "Working on user $user [$count/$($users.count)]"
    $status = (Get-MsolUser -UserPrincipalName $user).Licenses | select * | where {$_.AccountSkuId -like "sdzg:STANDARDWOFFPACK"}
    $servStatus = $status.ServiceStatus
    $report += "$user`t"
    #get headers off first user
    if($count -eq 1){
        foreach($header in $servStatus.ServicePlan){
            Write-host "$($header.servicename)`t"
            $headers += "$($header.servicename)`t"
        }
    }
    #get status report
    foreach($provStatus in $servStatus.ProvisioningStatus){
        $report += "$provStatus`t"
    }
    $report += "`n"
}

"$headers`n$report" | out-file "c:\temp\licensesStatus.csv"