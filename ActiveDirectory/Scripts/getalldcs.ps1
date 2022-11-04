$targets = get-adcomputer -SearchBase "OU=Domain Controllers,DC=domain,DC=com" -filter * -properties lastLogonTimestamp,enabled,OperatingSystem,OperatingSystemVersion
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-DC-ADComputerReport.csv"
"Name`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion" | out-file $outpath
foreach($target in $targets){
    Write-Host "$($target.Name)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)"
    "$($target.Name)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)" | out-file $outpath -append
}
