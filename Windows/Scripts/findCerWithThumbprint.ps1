$toMatch = "your cert thumb without spaces"
foreach($file in (Get-ChildItem C:\Certs -file -recurse | ?{$_.extension -eq ".cer"})){
    #if($file.extension -eq ".cer"){
        write-host "Found cert: $($file.FullName)"
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "$($file.FullName)"
        if($cert.Thumbprint -eq $toMatch){
            write-host "ITS HERE: $($file.fullname)" -ForegroundColor Green
        }
    #}   
}
