$targetRange = 180
$targets = get-adcomputer -filter * -properties LastLogonDate,lastLogonTimestamp,enabled,OperatingSystem,OperatingSystemVersion `
    | ?{[datetime]::FromFileTime($_.lastLogonTimestamp) -lt (get-date).AddDays(-$targetRange)} `
    | ?{$_.distinguishedname -like "*OU=Workstations,DC=domain,DC=com" `
    | ?{$_.OperatingSystem -notlike "*Windows Server*"}
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Desktops.csv"
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion`tSID" | out-file $outpath
foreach($target in $targets){
    write-host "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)"
    "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)" | out-file $outpath -append
}
