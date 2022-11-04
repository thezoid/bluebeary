#Build Creds
$domain = "domain.com"
$password = 'SA_PASSWORD' | ConvertTo-SecureString -asPlainText -Force
$username = "$domain\svcADjoin" 
$credential = New-Object System.Management.Automation.PSCredential($username, $password)
$ouPath = "OU DISTINGUISHED PATH"
if ((gwmi win32_computersystem).partofdomain -eq $false) {    
    #Join To Domain
    Add-Computer -DomainName $domain -Credential $credential -OUPath $ouPath
}
else {
    Write-Host "Already in a domain!"
}

#restart
$Users = quser.exe
if ($Users -match 'No\sUser') {
    Restart-Computer -force
}