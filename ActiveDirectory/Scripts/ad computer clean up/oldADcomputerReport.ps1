$targetRange = 90
$targets = get-adcomputer -filter * -properties LastLogonDate,lastLogonTimestamp,enabled,OperatingSystem,OperatingSystemVersion | ?{[datetime]::FromFileTime($_.lastLogonTimestamp) -lt (get-date).AddDays(-$targetRange)}
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport.csv"
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion" | out-file $outpath
foreach($target in $targets){
    write-host "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)"
    "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)" | out-file $outpath -append
}
