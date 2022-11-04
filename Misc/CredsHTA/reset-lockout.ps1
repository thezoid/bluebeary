Param([Parameter(Mandatory = $true)][string]$user)
Function Write-Log {
     [CmdletBinding()]
     Param(
     [Parameter(Mandatory=$False)]
     [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
     [String]
     $Level = "INFO",
 
     [Parameter(Mandatory=$True)]
     [string]
     $Message,
 
     [Parameter(Mandatory=$False)]
     [string]
     $logfile
     )
 
     $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
     $Line = "$Stamp $Level $Message"
     If($logfile) {
         Add-Content $logfile -Value $Line
     }
     Else {
         Write-Output $Line
     }
 }

$date = Get-Date -format "yyyy-MMM-dd_hhmmss"
$logpath = "logs/$($date)_reset.log"
if(!$logpath){
     New-Item $logpath
} 
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path $logpath -append

#try to get account activity and add it to the message string
$svcUser = "MyUserName"
$File = "tmp\Password.txt"
$svcCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $svcUser, (Get-Content $File | ConvertTo-SecureString)
$command = Reset-AdfsAccountLockout $cred
$computer = "adfs1"

#"P@ssword1" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "tmp\Password.txt"

$sMessageProcessed = "Attempting to get account activity for $cred"
$activityOut = Invoke-Command -ComputerName $computer -ScriptBlock $command
$sMessageProcessed = "$sMessageProcessed`n$activityOut"

if ("tmp/out.txt") {
     $sMessageProcessed | Set-Content "tmp/out.txt"
}
else {
     New-Item -Path "tmp/out.txt"
     $sMessageProcessed | Set-Content "tmp/out.txt"
}

Stop-Transcript