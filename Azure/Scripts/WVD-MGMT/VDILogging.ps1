#import the module for use
Import-Module -Name Microsoft.RDInfra.RDPowerShell
#add an administratige account to manage RDS as
Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com"
#the root directory of the stats save location
$statsLoc = "c:\temp\WVDlogs"
#how often to log data points - in seconds (1 hour = 3600, 30 minute = 1800)
$sleepTime = 60
$headers = "Date, Pool Name,Max Pool Hosts, Active Hosts, Concurrent User Sessions"

#dont change this, or it stops the infinite log loop
$stop = $FALSE
while(-not $stop){
    $currentDay = get-date -Format "MM-dd-yyyy"
    $poolOneLog = "$statsLoc\$($currentDay)_poolOneStats.csv"
    $currentDate = get-date -Format "MM/dd/yyyy hh:mm:ss"
    Write-host "[$currentDate] Starting to gather data"

    if(-not (Test-Path -path $statsLoc)){
        mkdir $statsLoc
    }

    if(-not (Test-Path -path $poolOneLog)){
        "$headers" | Out-file $poolOneLog
    }

    #Commercial and Corporate
    $rdstenantname = "WVD TENANT"
    $hostpoolname = "POOL 1"

    #currently powered on machines
    $availableHosts = (Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,status| where {$_.status -eq "Available"}).count
    #total VMs registered in the pool
    $maxPoolSize = (Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname).count
    #current user sessions
    $sessions = Get-RdsSessionHost -TenantName $rdstenantname -HostPoolName $hostpoolname | Select SessionHostName,sessions,status,lastheartbeat | Sort-Object status,Sessions,sessionhostname | Where{$_.Sessions -eq 1}
    
    $currentDate = get-date -Format "MM/dd/yyyy hh:mm:ss"
    Write-host "[$currentDate] Reporting Corporate and Commerical session count: $($sessions.count)"
    "$currentDate,$hostpoolname,$maxPoolSize,$availableHosts,$($sessions.count)"|Out-File $poolOneLog -Append

    #PAUSE
    $currentDate = get-date -Format "MM/dd/yyyy hh:mm:ss"
    Write-host "[$currentDate] Starting sleep for $sleepTime seconds..."
    Start-Sleep -s $sleepTime
}