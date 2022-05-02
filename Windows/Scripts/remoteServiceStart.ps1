# get all computers
## modify filter or add where clause (?{$_.field -eq "some value"}) to increase precision of targeted computers
$computers = get-adcomputer -filter *
$jobs = @()
$sb = {
     # update service name to the display name of the service
     # can be found in services.msc
     start-service -name "target service" 
}

# create jobs to run the command across your targets
# jobs allows the script to execute "faster" by multithreading the invocations 
foreach($computer in $computers){
     write-host "Creating job to start service on $($computer.name)"
     $jobs += (invoke-command -computername $computer.name -scriptblock $sb -asjob)
}

# check and report in on jobs still running
do{
     $runningJobs = $jobs | ?{$_.state -ne "Completed" -and $_.state -ne "Failed"}
     if($runningJobs.count -ne 0){
          write-host "Waiting on:"
          $runningJobs
          write-host "$($runningJobs.count) jobs still running`nPausing for next update..."
          start-sleep -seconds 5
     }
}while($runningJobs.count -gt 0)

# report on failed jobs
write-host "Failed jobs:"
$jobs | ?{$_.state -eq "Failed"}
write-host "$(($jobs | ?{$_.state -eq "Failed"}).count) jobs failed"