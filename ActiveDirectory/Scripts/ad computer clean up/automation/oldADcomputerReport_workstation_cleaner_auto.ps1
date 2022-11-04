#-----
#vars
#-----
$targetRange = 180
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Cleaner-Desktops-auto.csv"
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
            Write-Host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue
            try { "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Cleaner-Desktops-auto.log" -Append }catch {} 
        }
        "warning" {
            Write-Host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow
            try { "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Cleaner-Desktops-auto.log" -Append }catch {}  
        }
        "error" {
            Write-Host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red
            try { "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Cleaner-Desktops-auto.log" -Append }catch {} 
        }
    }
}

#-----
#main
#-----

#prepare report file
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion`tSID" | out-file $outpath

writeLog "Dynamically identifying targets" "info"
$targets = get-adcomputer -filter * -properties LastLogonDate, lastLogonTimestamp, enabled, OperatingSystem, OperatingSystemVersion `
| ? { $_.distinguishedname -like "*$($disabledComputerOUDN)" }
writelog "Identified $($targets.count) targets" "info"

#begin to process computer objects
foreach ($target in $targets) {
    writelog "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)"
    "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)" | out-file $outpath -append
    writelog "Deleting $($target.name)" "info"
    try {
        Remove-ADObject -Identity $target.DistinguishedName -ErrorAction "stop" -confirm:$false
    }
    catch {
        writeLog "Failed to delete $($target.name) - details to follow`n-----Error start-----`n$($_)`n-----Error end-----`n" "error"
        if ((get-adobject -Filter * -searchbase $target.DistinguishedName).count -gt 1) {
            $childobjs = (get-adobject -Filter * -searchbase $target.DistinguishedName)
            foreach ($childobj in $childobjs) {
                try {
                    writelog "Deleting $($childobj.name) $($childobj.ObjectClass)" "info"
                    Remove-ADObject -Identity $childobj.DistinguishedName -ErrorAction "stop" -confirm:$false
                }
                catch {
                    writeLog "Failed to delete $($childobj.name) $($childobj.ObjectClass) - details to follow`n-----Error start-----`n$($_)`n-----Error end-----`n" "error"
                }
            }
            Remove-ADObject -Identity $target.DistinguishedName -ErrorAction "stop" -confirm:$false
        }
    }
}

writelog "Finished processing $($targets.count) stale computer objects" "info"

