# ref https://www.reddit.com/r/PowerShell/comments/4w9rey/advanced_help_creating_dynamic_script_block_with/
Start-Transcript "C:\Temp\robocopyTranscript_$(Get-Date -Format "yyyyMMMdd").log"
$dest = ""
$denylist = ("Windows", "Users")
$targetFolders = Get-ChildItem -Path "c:\" -Directory | ? { $denylist -notcontains $_.Name }
$jobs = @()
ForEach ($folder in $targetFolders) {
     $sb = {
          param($folder)
          Write-Host "Copying $($folder.fullname) to $dest"
          robocopy $folder.fullname $dest /e /COPY:DAT /DCOPY:DAT /z /r:3 /W:5 /MT:32 /log:"C:\Temp\RobocopyLog_$($folder.name)_$(Get-Date -Format MM-dd-yyyy_HH_mm_ss).log"
     }
     $jobs += invoke-command -scriptblock $sb -asjob -computername $env:computername -ArgumentList $folder
}
do {
     $runningJobs = $jobs | ? { $_.state -ne "Completed" -and $_.state -ne "Failed" }
     if ($runningjobs.count -ne 0) {
          write-host "waiting on:"
          $runningJobs
          write-host "$($runningjobs.count) jobs still running`nPausing for next update..."
          start-sleep -seconds 5
     }
}while ($runningjobs.count -gt 0)
write-host "failed jobs:"
$jobs | ? { $_.state -eq "Failed" }
write-host "$(($jobs | ?{$_.state -eq "Failed"}).count) jobs failed"
Stop-Transcript