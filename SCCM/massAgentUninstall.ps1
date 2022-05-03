$cred = get-credential
$jobs = @()
#servers.csv must have at least a "Computer" header
Foreach ($record in (import-csv -path "C:\temp\servers.csv")) {
     $sb = {
          function writeLog([string]$message, [string]$status) {
               if (-not $status -or $status -eq "") {
                    $status = 'info'
               }
               switch ($status.ToLower()) {
                    "info" { write-host "*[$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" -foregroundcolor blue; try { "*[$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" | out-file "$($PSScriptRoot)\$(get-date -format "yyyyMMMdd")-SCCMUninstall.csv" -append }catch {} }
                    "warning" { write-host "![$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" -foregroundcolor yellow; try { "![$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" | out-file "$($PSScriptRoot)\$(get-date -format "yyyyMMMdd")-SCCMUninstall.csv" -append }catch {} }
                    "error" { write-host "!!![$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" -foregroundcolor red; try { "!!![$(get-date -format "yyyyMMMdd@hh:mm:ss")] $($message)" | out-file "$($PSScriptRoot)\$(get-date -format "yyyyMMMdd")-SCCMUninstall.csv" -append }catch {} }
               }
          }
          If (test-path -path "C:\Windows\ccmsetup") {
               writeLog "attempting to uninstall SCCM agent..." "info"
               start-process -FilePath "C:\Windows\ccmsetup\ccmsetup.exe" -ArgumentList "/uninstall" -NoNewWindow
          }
          Else {
               writeLog "C:\Windows\ccmsetup was not found..." "error"
          }
     }
     If ($record.computer -eq $env:COMPUTERNAME) {
          $jobs += (invoke-command -ScriptBlock $sb -AsJob -Credential $cred)
     }
     Else {
          $jobs += (invoke-command -ScriptBlock $sb -AsJob -Credential $cred -ComputerName $record.computer)
     }
}

#monitor running jobs
do {
     $jobsinprogress = $jobs | where { $_.state -ne "Completed" -and $_.state -ne "Failed" }
     if ($jobsinprogress.count -gt 0) {
          Write-Host "waiting on..."
          $jobsinprogress
          Write-Host "$($jobsinprogress.count) jobs still running.."
          Start-Sleep -seconds 5
     }
}while ($jobsinprogress.count -gt 0)

#report failed jobs
Write-Host "failed jobs"
$jobs | where { $_.state -eq "Failed" }
Write-Host "$(($jobs | where {$_.state -eq "Failed"}).count) jobs failed"