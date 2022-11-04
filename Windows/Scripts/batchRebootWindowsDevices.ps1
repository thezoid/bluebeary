$machines = get-content "C:\temp\reboot1.txt" #expects 1 machine name per line
#can be commented out if your current user will have permission to reboot the remote devices
#combine with my pwd encryption/decryption code for easier automation
$cred = get-credential
#tracker for how far into the batch we are
$count = 0
#the amount of servers to reboot in one go
#i recommend doing 25 do have a feasible number to check in on
#lower is better when power state monitoring is enabled - or you may get hundreds of emails :^)
$batchSize = 25 
#how long, in seconds, to pause between batches
$sleepLength = 10
foreach ($machine in $machines) {
     try {
          Write-host "Force restarting $machine"
          restart-computer -ComputerName $machine -credential $cred -force
          $count++
          if ($count -ge $batchSize) {
               $count = 0
               Start-Sleep -Seconds $sleepLength
          }
     }
     catch {
          Write-Error "Couldn't restart $machine"
          continue
     }
}