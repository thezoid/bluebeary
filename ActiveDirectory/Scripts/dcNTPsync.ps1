$computers = get-adcomputer -filter * -SearchBase "OU=Domain Controllers,DC=domain,DC=com"
$pdcname =  Get-ADForest | Select-Object -ExpandProperty RootDomain | Get-ADDomain | Select-Object -expandproperty PDCEmulator
$sb = {
    $logPath = "c:\temp\NTPSync\Logs\$(get-date -Format "yyyyMMMdd")timeSync.log"
    new-item -ItemType "directory" -Force -Path $logPath
    "`n----------`n$($env:COMPUTERNAME)`n----------`n" | Add-Content $logPath 
    try{
        w32tm /stripchart /computer:$pdcname /dataonly /samples:8 | Add-Content $logPath
        w32tm /resync | Add-Content $logPath
        w32tm /query /status | Add-Content $logPath
        w32tm /stripchart /computer:$pdcname /dataonly /samples:8 | Add-Content $logPath
    }catch{
        "$($env:COMPUTERNAME) failed to run time sync" | Add-Content $logPath
    }
}
foreach($computer in $computers){
    Invoke-Command -ComputerName $computer.name -ScriptBlock $sb
}