$DaysInactive = 90
$time=[datetime]::Today.AddDays(-$DaysInactive)
$today = [datetime]::Today.AddDays(0)
 
Get-ADComputer -Filter {
          LastLogonDate -ge $time -and LastLogonDate -le $today -and OperatingSystem -like "Windows 7*" 
     } -Properties LastLogonTimeStamp, OperatingSystem, description | Select-Object Name, OperatingSystem, Description,
     @{Name="Stamp"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}} | Export-Csv 'C:\temp\Windows7report.csv' 