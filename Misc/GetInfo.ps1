#2022Oct31 note - past me needed this, but in the present, i have zero clue when you would use this - 95% sure this was copy and pasted out from the console, instead of writing to a file
#theres also a bat of this? again, not sure why

#create local admin user named CDW Admin
#prompts user for a password
Write-host "\n\n-----------------------------------------------------------\nCreating Admin User\n-----------------------------------------------------------\n\n"
$password = Read-Host "Enter admin password:" -AsSecureString
$user = New-LocalUser -Name "CDWAdmin" -Password $password
Add-LocalGroupMember -Group "Administrators" -Member "CDWAdmin"

#capture all software installed using wmic
Write-host "\n\n-----------------------------------------------------------\nSoftware Report\n-----------------------------------------------------------\n\n"
#Get-WmiObject Win32_product | select name, packagecache
wmic product get name

#get drive id (ex: C:), free space, and total size (IN BYTES) of all drives
Write-host "\n\n-----------------------------------------------------------\nDrive Report\n-----------------------------------------------------------\n\n"
Get-WmiObject win32_LogicalDisk -Filter "DeviceID = C:" | Select DeviceID, FreeSpace, Size

Write-host "\n\n-----------------------------------------------------------\nOS Info\n-----------------------------------------------------------\n\n"
#os name
(Get-WMIObject win32_operatingsystem).name
#32 vs 64 bit
(Get-WmiObject Win32_OperatingSystem).OSArchitecture