#sccm powershell boilerplate
Import-Module "C:\psmodules\SCCM-AdminGui\bin\ConfigurationManager.psd1"
if(get-psdrive -Name "SCCM"){
    write-host "sccm drive exists"
}else{
    New-PSDrive -Name SCCM -PSProvider "AdminUI.PS.Provider\CMSite" -Root "<sccm primary site server>" -Description "SCCM Site"
}
CD SCCM:

#report generation

#desktops
$outputPathDesktops = "c:\temp\$(get-date -format "yyyyMMMdd")_SCCMClientReport_DesktopsWBitlocker.csv"
"Device`tSerial Number`tIP`tModel`tOS Version`tOS Build`tAD Site Name`tMAC Address`tBitlocker Status(Drive letter:Protection Enabled)" | Out-File $outputPathDesktops
$items = invoke-cmquery -id "<report id gathering all the data>"
$lastSystemName = ""
foreach($item in $items){
    if($lastSystemName -eq $item.SMS_R_System.Name){continue}
    $lastSystemName = $item.SMS_R_System.Name
    $line = "$($item.SMS_R_System.Name)`t$($item.SMS_G_System_SYSTEM_ENCLOSURE.SerialNumber)`t$($item.SMS_R_System.IPAddresses | %{"$_;"})`t$($item.SMS_G_System_COMPUTER_SYSTEM.Model)`t$($item.SMS_R_System.OperatingSystemNameandVersion)`t$($item.SMS_G_System_OPERATING_SYSTEM.Version)`t$($item.SMS_R_System.ADSiteName)`t$($item.SMS_R_System.MACAddresses)`t"
    #add all drive bitlocker statuses
    $bitData = $items | ?{$_.SMS_R_System.Name -eq $lastSystemName}
    foreach($bd in $bitData){
        $line+= "$($bd.SMS_G_System_ENCRYPTABLE_VOLUME.DriveLetter)$($bd.SMS_G_System_ENCRYPTABLE_VOLUME.ProtectionStatus -eq 1);"
    }
    write-host $line
    $line | out-file $outputPathDesktops -Append
}

#servers
$outputPathServers = "c:\temp\$(get-date -format "yyyyMMMdd")_SCCMClientReport_Servers.csv"
"Device`tSerial Number`tIP`tModel`tOS Version`tOS Build`tAD Site Name`tMAC Address" | Out-File $outputPathServers
$items = invoke-cmquery -id "<report id gathering all the data>"
foreach($item in $items){
    $line = "$($item.SMS_R_System.Name)`t$($item.SMS_G_System_SYSTEM_ENCLOSURE.SerialNumber)`t$($item.SMS_R_System.IPAddresses | %{"$_;"})`t$($item.SMS_G_System_COMPUTER_SYSTEM.Model)`t$($item.SMS_R_System.OperatingSystemNameandVersion)`t$($item.SMS_G_System_OPERATING_SYSTEM.Version)`t$($item.SMS_R_System.ADSiteName)`t$($item.SMS_R_System.MACAddresses)`t"
    write-host $line
    $line | out-file $outputPathServers -Append
}

#clean up
cd C:
remove-psdrive sccm