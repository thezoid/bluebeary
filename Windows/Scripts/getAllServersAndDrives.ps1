$gigabyteAsBytes = (1024 * 1024 * 1024) #cheap var for calcs later
$reportLocation = "c:\temp\$(get-date -Format "yyyyMMMdd")-ServerAndDrivesReport.csv" #path to write report to
$creds = Get-Credential
$headers = "Name,IP,OS,Drive (Letter:Used/Capacity:Utilization%)" #headers for final output csv
$headers | out-file $reportLocation
$machineList = get-adcomputer -filter * -properties ipv4Address,enabled,OperatingSystem,OperatingSystemVersion `
    | ?{$_.distinguishedname -notlike "*OU=Servers,DC=domain,DC=com"} `
    | ?{$_.OperatingSystem -like "*Windows Server*"}
foreach($machine in $machineList){
    try{
        if($machine.name.ToLower() -eq $env:COMPUTERNAME.ToLower()){
            $drives = get-WmiObject win32_logicaldisk -Computername $machine.name -ErrorAction stop
        }else{
            $drives = get-WmiObject win32_logicaldisk -Computername $machine.name -Credential $creds -ErrorAction stop
        }
        foreach($drive in $drives){
            #skip empty drives so we dont divide by zero
            #todo: just fix the math for drives below so we can track empty/zeroed drives
            if($drive.FreeSpace -eq 0 -or $null -eq $drive.FreeSpace){
                write-host "skipping empty drive($($machine)- $($drive.DeviceID[0]))" -ForegroundColor blue
                continue
            }
            $driveSpace = [math]::Round($drive.FreeSpace/$gigabyteAsBytes,2)
            $driveSize = [math]::Round($drive.size/$gigabyteAsBytes,2)
            $driveLetter = $drive.DeviceID[0]
            write-host "$($machine.name),$($machine.ipv4Address),$($machine.OperatingSystem) $($machine.OperatingSystemVersion),$($driveLetter):$($driveSize-$driveSpace)GB/$($driveSize)GB:$(100-[math]::Round($driveSpace/$driveSize*100))%"
            "$($machine.name),$($machine.ipv4Address),$($machine.OperatingSystem) $($machine.OperatingSystemVersion),$($driveLetter):$($driveSize-$driveSpace)GB/$($driveSize)GB:$(100-[math]::Round($driveSpace/$driveSize*100))%" | out-file -Append $reportLocation
        }
    }catch{
        write-host "$($machine.name),$($machine.ipv4Address),$($machine.OperatingSystem) $($machine.OperatingSystemVersion),N/A Unable to pull drive information" -ForegroundColor yellow
        "$($machine.name),$($machine.ipv4Address),$($machine.OperatingSystem) $($machine.OperatingSystemVersion),N/A Unable to pull drive information" | out-file -Append $reportLocation
    }
}