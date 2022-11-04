$sitecode = "<put site code here>"
$managementPointHostname = "<mp hostname here>"
c:\windows\ccmsetup\ccmsetup.exe /uninstall
Start-Sleep -s 600
c:\windows\ccmsetup\ccmsetup.exe /mp:$managementPointHostname /logon SMSSITECODE=$sitecode