#GET DECRYPTED PASSWORD
$PasswordFile = "c:\temp\Password.txt"
$KeyFile = "c:\temp\crypt.key"
$Key = Get-Content $KeyFile
$pwd = Get-Content $PasswordFile | ConvertTo-SecureString -Key $key
$dpwd = [System.Net.NetworkCredential]::new("", $pwd).Password