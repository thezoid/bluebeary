Import-Module '\\<sccm primary site server>\C$\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1'
New-PSDrive -Name SCCM -PSProvider "AdminUI.PS.Provider\CMSite" -Root "<primary site server hostname>" -Description "SCCM Site"
CD SCCM:
$allDevices = get-cmdevice

$report = "Total,$($allDevices.Count)`n"
$report += "Domain,DeviceName,DeviceOS,LastPolicyRequest,LastPolicyRequest,LastSoftwareScan,LastLogonUser,LastHardwareScan,IsClient,BoundaryGroups,ADSiteName`n"
foreach ($device in $allDevices){
    $report+= "$($device.Domain),$($device.Name),$($device.DeviceOS),$($device.LastPolicyRequest),$($device.LastSoftwareScan),$($device.LastLogonUser),$($device.LastHardwareScan),$($device.IsClient),$($device.BoundaryGroups),$($device.ADSiteName)`n"
}

#write-host $report
$report | out-file "c:\temp\$(get-date -format "yyyyMMMMdd")_SCCMClientReport.csv"
