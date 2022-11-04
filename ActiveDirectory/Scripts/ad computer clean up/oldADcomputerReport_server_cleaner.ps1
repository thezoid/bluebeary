#-----
#vars
#-----
$targetRange = 180
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")-$($targetRange)day-OldADComputerReport-Cleaner-Desktops.csv"
$disabledComputerOUDN = "OU=Servers,OU=Stale,DC=domain,DC=com"
#-----
#user input
#-----

#get function action (move or delete)
do {
    $operation = read-host "[m]ove`n[d]elete`nSelect an operation"
}while ($operation.tolower() -ne "move" -and $operation.tolower() -ne "m" -and $operation.tolower() -ne "delete" -and $operation.tolower() -ne "d")
#check if we want to dynamically run the script, or parse a gathered list
#will prompt for valid file path until given
#assumes the list has the headers Name,LastLogonDate,Days Since LastLogonDate,Enabled,DistinguishedName,OperatingSystem,OperatingSystemVersion,SID
$fromFile = $false
$fromFileGood = $false
do {
    $fromFileOperation = read-host "Load data from a file? y/N"
    if ($fromFileOperation.ToLower() -eq "y") {
        $fromFile = $true
        $fromFileGood = $true
        do {
            $inputFilePath = read-host "Please provide a valid path to the input file"
        }while (-not(test-path $inputFilePath))
    }
    elseif ($fromFileOperation.ToLower() -eq "n" -or $fromFileOperation.ToLower() -eq "") {
        $fromFile = $false
        $fromFileGood = $true
    }
    else {
        write-host "Invalid input - try again"
        $fromFileGood = $false
    }
}while (!$fromFileGood)

#-----
#main
#-----

#prepare report file
"Name`tLastLogonDate`tDays Since LastLogonDate`tEnabled`tDistinguishedName`tOperatingSystem`tOperatingSystemVersion`tSID" | out-file $outpath

#get target data
if ($fromFile) {
    Write-Host "Importing targets from $inputFilePath"
    $targets = import-csv -path $inputFilePath -Header @("Name", "LastLogonDate", "Days Since LastLogonDate", "Enabled", "DistinguishedName", "OperatingSystem", "OperatingSystemVersion", "SID") -Delimiter "`t"
}
else {
    Write-Host "Dynamically identifying targets from AD"
    $targets = get-adcomputer -filter * -properties LastLogonDate, lastLogonTimestamp, enabled, OperatingSystem, OperatingSystemVersion, PasswordLastSet `
    | ? { [datetime]::FromFileTime($_.lastLogonTimestamp) -lt (get-date).AddDays(-$targetRange)`
            -or (New-TimeSpan -start (Get-CimInstance -ComputerName $_.name -Class CIM_OperatingSystem | Select-Object -expandproperty LastBootUpTime) -end (get-date)).days -ge $targetRange `
            -or (New-TimeSpan -start ($target.PasswordLastSet) -end (get-date)).days -ge $targetRange
    } `
    | ? { $_.distinguishedname -like "*OU=Servers,DC=domain, DC=com" }`
    | ? { $_.OperatingSystem -like "*Windows Server*" }
    write-host "Identified $($targets.count) targets"
}

#begin to process computer objects
foreach ($target in $targets) {
    if ($fromFile) {
        $target.DistinguishedName = $target.DistinguishedName.replace(";", ",")
    }
    write-host "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)"
    "$($target.Name)`t$($target.LastLogonDate)`t$((New-TimeSpan -start ([datetime]::FromFileTime($target.lastLogonTimestamp)) -end (get-date)).days)`t$($target.Enabled)`t$($target.DistinguishedName.replace(',',";"))`t$($target.OperatingSystem)`t$($target.OperatingSystemVersion)`t$($target.SID)" | out-file $outpath -append
    if ($operation.tolower() -eq "move" -or $operation.tolower() -eq "m") {
        write-host "Disabling and moving $($target.name)"
        Disable-ADAccount -Identity $target.DistinguishedName
        Move-ADObject -Identity $target.DistinguishedName -TargetPath $disabledComputerOUDN
    }
    elseif ($operation.tolower() -eq "delete" -or $operation.tolower() -eq "d") {
        if (-not($creds.UserName)) {
            write-host "Please provide administrative credentials to delete objects" -ForegroundColor Yellow
            $creds = Get-Credential
        }
        write-host "Deleting $($target.name)"
        Remove-ADObject -Identity $target.DistinguishedName -Credential $creds -force
    }
}

write-host "Finished processing $($targets.count) stale computer objects"

