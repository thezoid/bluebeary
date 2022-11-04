$certPath = "c:\path\to\ServerCertificate.crt"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "$certPath"
$chostname = "cert hostname"
$reqFile = "$($chostname)_$(get-date -format "yyyyMMMdd").csr"
$InfFile = @"
[NewRequest]`r
Subject = "$($cert.Subject)"`r
KeySpec = 1 `r
KeyLength = 4096 `r
"@
$sans = ($cert.DnsNameList | select -expandproperty unicode)
if($sans.count -gt 1){
    write-host "found more than 1 san!" -ForegroundColor Yellow
    $InfFile += "`n[Extensions]`n"
    $InfFile += "2.5.29.17 = `"{text}`"`n"
    foreach($san in $sans){
        write-host "`t$san"
        $InfFile += "_continue_ = `"dns=$($san)`"`n"
    }
}
$InfFile.replace("`n","`r")

Write-Host "Generating Certificate Request file..." -ForegroundColor Yellow
$FinalInfFile = "$($chostname)_$(get-date -format "yyyyMMMdd").inf"
if(Test-Path $reqFile){Remove-Item $reqFile}
if(test-path $FinalInfFile){Remove-Item $FinalInfFile}
New-Item $FinalInfFile -type file -value $InfFile -Force
cmd /c "certreq -new $FinalInfFile $ReqFile"
Write-Host " "
Write-Host "Certificate request file for $chostname successfully generated!" -foregroundcolor DarkGreen;
write-host "Confirm CSR validitiy at https://confirm.entrust.net/public/en (csr copied to clipboard)"
Set-Clipboard (get-content $reqFile)