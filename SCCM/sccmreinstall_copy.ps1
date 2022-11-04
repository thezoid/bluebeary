$sitecode = "<site code here>"
$managementPointHostname = "<mp hostname here>"
$pathToSCCMClientFolder = "\\serverIPorHostname\SCCM_Client"
if(!Test-Path("c:\windows\ccmsetup\")){
     mkdir "c:\windows\ccmsetup\"
}
Copy-Item -Path "$($pathToSCCMClientFolder)\*" -Destination "c:\windows\ccmsetup\"
Start-Sleep -s 120 #time tuned to environment
c:\windows\ccmsetup\ccmsetup.exe /uninstall
Start-Sleep -s 600 #time tuned to environment
c:\windows\ccmsetup\ccmsetup.exe /mp:$managementPointHostname /logon SMSSITECODE=$sitecode