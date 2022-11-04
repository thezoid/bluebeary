#-----
#vars
#-----
$targetRange = 180
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Disabler-Desktops-auto.csv"
$disabledComputerOUDN = "OU=Workstations,OU=Stale,DC=domain,DC=com"
#-----
#functions
#-----
function writeLog([string]$message, [string]$status) {
    if (-not $status -or $status -eq "") {
        $status = "info"
    }
    switch ($status.ToLower()) {
        "info" {
            write-host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue
            try { "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Disabler-Desktops-auto.log" -Append }catch {} 
        }
        "warning" {
            write-host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow
            try { "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Disabler-Desktops-auto.log" -Append }catch {}  
        }
        "error" {
            write-host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red
            try { "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Disabler-Desktops-auto.log" -Append }catch {} 
        }
    }
}

#-----
#main
#-----

#prepare report file
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion`tSID" | out-file $outpath

#get target data
writeLog "Dynamically identifying targets from AD" "info"
$targets = get-adcomputer -filter * -properties LastLogonDate, lastLogonTimestamp, enabled, OperatingSystem, OperatingSystemVersion `
    | ? { [datetime]::FromFileTime($_.lastLogonTimestamp) -lt (get-date).AddDays(-$targetRange) } `
    | ? { $_.distinguishedname -like "*OU=Workstations,DC=domain,DC=com" `
            -or $_.distinguishedname -notlike "*$($disabledComputerOUDN)"
    }   
    | ? { $_.OperatingSystem -notlike "*Windows Server*" }
writeLog "Identified $($targets.count) targets" "info"

#begin to process computer objects
foreach ($target in $targets) {
    writeLog "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)" "info"
    "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)" | out-file $outpath -append
    writeLog "Disabling and moving $($target.name) to Purgatory" "info"
    try {
        Disable-ADAccount -Identity $target.DistinguishedName -ErrorAction "stop"
        Move-ADObject -Identity $target.DistinguishedName -TargetPath $disabledComputerOUDN -ErrorAction "stop"
    }
    catch {
        writeLog "Failed to disable or move $($target.name) - details to follow`n-----Error start-----`n$($_)`n-----Error end-----`n" "error"
    }
}

writeLog "Finished processing $($targets.count) stale computer objects" "info"

