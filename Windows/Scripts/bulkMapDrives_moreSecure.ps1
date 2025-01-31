# Update to map to your locations
$drives = @{
     "X"="\\10.0.0.100\Backups"
     "Y"="\\10.0.0.100\Projects"
     "Z"="\\10.0.0.100\Home"
 }
 
 # Define the credentials for mapped drives
 # KeyGen example: https://github.com/thezoid/bluebeary/blob/main/Windows/Scripts/pwdKeyGen.ps1
 # Encryption example: https://github.com/thezoid/bluebeary/blob/main/Windows/Scripts/pwdEncrypt.ps1
 # Decryption example: https://github.com/thezoid/bluebeary/raw/refs/heads/main/Windows/Scripts/pwdDecrypt.ps1
 $PasswordFile = "C:\temp\cred.txt"
 $KeyFile = "C:\temp\crypt.key"
 $Key = Get-Content $KeyFile
 $pwd = Get-Content $PasswordFile | ConvertTo-SecureString -Key $Key
 $userName = "username"
 $cred = New-Object System.Management.Automation.PSCredential ($userName, $pwd)
 
 foreach ($key in $drives.Keys) {
     if (Get-PSDrive -Name $key -ErrorAction SilentlyContinue) {
         Write-Host "Found $($key) -> $($drives[$key]) already mounted"
         net use /d "$($key):"
     }
     Write-Host "Attempting to mount $($key) -> $($drives[$key])"
     try {
         New-PSDrive -Name $key -Root $drives[$key] -PSProvider FileSystem -Scope Global -Credential $cred -Persist -ErrorAction Stop
     } catch {
         Write-Error "Failed to mount $($key) -> $($drives[$key]): $_"
     }
 }