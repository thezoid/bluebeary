#KEY GEN RUN ONCE - SAVE IT TO USER DATA
$KeyFile = "c:\temp\crypt.key"
$Key = New-Object Byte[] 32   # You can use 16, 24, or 32 for AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
$Key | out-file $KeyFile