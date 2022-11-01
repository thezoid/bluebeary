#WRITE ENCRYPTED PASSWORD TO FILE
$PasswordFile = "c:\temp\Password.txt"
$KeyFile = "c:\temp\crypt.key"
$Key = Get-Content $KeyFile
$Password = "P@ssword1" | ConvertTo-SecureString -AsPlainText -Force
$Password | ConvertFrom-SecureString -key $Key | Out-File $PasswordFile