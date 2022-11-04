$ErrorActionPreference = "Continue"
$targetRange = 180
$targets = get-adcomputer -filter * -properties LastLogonDate,lastLogonTimestamp,enabled,OperatingSystem,OperatingSystemVersion,PasswordLastSet `
    | ?{$_.distinguishedname -like "*OU=Servers,DC=domain,DC=com" `
    | ?{$_.OperatingSystem -like "*Windows Server*"}

$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Servers.csv"
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion`tLast Reboot`tTime Since Last Reboot`tPasswordLastSet`tDays Since PasswordLastSet" | out-file $outpath
foreach($target in $targets){
    try{
        $lastrboot = (Get-CimInstance -ComputerName $_.name -Class CIM_OperatingSystem | Select-Object -expandproperty LastBootUpTime)
        $timeSincelastrboot = (New-TimeSpan -start $lastrboot -end (get-date)).days
        if((New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days -lt $targetRange){
            Write-host "[$($target.Name)] Found PasswordLastSet < target range, skipping" -ForegroundColor Yellow
            continue
        }elseif([datetime]::FromFileTime($_.lastLogonTimestamp) -gt (get-date).AddDays(-$targetRange)){
            Write-host "[$($target.Name)] Found lastlogon < target range, skipping" -ForegroundColor Yellow
            continue
        }elseif($timeSincelastrboot -lt $targetRange){
            Write-host "Found last reboot < target range" -ForegroundColor blue
        }
        write-host "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($lastrboot)`t$($timeSincelastrboot)`t$($target.PasswordLastSet)`t$((New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days)"
        "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($lastrboot)`t$($timeSincelastrboot)`t$($target.PasswordLastSet)`t$((New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days)" | out-file $outpath -append
    }catch{
        Write-host "Failed to get last reboot time span because:`n$_" -foregroundcolor red
        write-host "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`tn\a`tn\a`t$($target.PasswordLastSet)`t$((New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days)"
        "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`tn\a`tn\a`t$($target.PasswordLastSet)`t$((New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days)" | out-file $outpath -append
        continue
    }

}