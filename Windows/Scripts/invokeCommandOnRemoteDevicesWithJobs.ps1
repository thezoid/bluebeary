$computers = Get-ADComputer -Filter *
$jobs = @()
$sb = {
    write-host "do something on remote machines as a job"
}
$cred = get-credential
foreach($computer in $computers){
    Write-host "Attempting to start service on $($computer.name)"
    if($computer.name -eq $env:COMPUTERNAME){
        $jobs += (Invoke-Command -ScriptBlock $sb -AsJob -Credential $cred)
    }else{
        $jobs += (Invoke-Command -ComputerName $computer.name -ScriptBlock $sb -AsJob -Credential $cred)
    }
}

do{
    $runningJobs = $jobs | ?{$_.State -ne "Completed" -and $_.state -ne "Failed"}
    if($runningJobs.count -gt 0){
        write-host "Waiting on:"
        $runningJobs
        write-host "$($runningJobs.count) jobs still running`nPausing for next update..."
        Start-Sleep -Seconds 5
    }
}while($runningJobs.count -gt 0)

write-host "Failed jobs:"
($jobs | ?{$_.state -eq "Failed"})
write-host "$(($jobs | ?{$_.state -eq "Failed"}).count) jobs failed"
