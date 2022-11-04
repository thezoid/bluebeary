$erroraction = "continue"
function writeLog([string]$message, [string]$status){
    if(-not $status -or $status -eq ""){
        $status = "info"
    }
    if(-not(test-path "$($PSScriptRoot)\logs")){
        new-item "$($PSScriptRoot)\logs"
    }
    switch($status.ToLower()){
        "info"{write-host "*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Blue; try{"*[$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "$($PSScriptRoot)\logs\$(get-date -Format "yyyyMMMdd")-90PwdEnforce.log" -Append}catch{} }
        "warning"{write-host "![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Yellow; try{"![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "$($PSScriptRoot)\logs\$(get-date -Format "yyyyMMMdd")-90PwdEnforce.log" -Append}catch{}  }
        "error"{write-host "!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" -ForegroundColor Red;  try{"!!![$(get-date -Format "yyyyMMMdd@hh:mm:ss")] $($message)" | Out-File "$($PSScriptRoot)\logs\$(get-date -Format "yyyyMMMdd")-90PwdEnforce.log" -Append}catch{} }
    }
}

$outpath = "c:\temp\logs\$(get-date -format "yyyyMMMdd")activeUserPwdOlderThan90days_forcedReset.csv"
if(-not (test-path "c:\temp\logs")){new-item -itemtype directory -force -path "c:\temp\logs"}
$knownServiceAccounts = get-content "$($PSScriptRoot)\knownServiceAccounts.txt" #"\\<network share path>\knownServiceAccounts.txt"
$exceptionList = get-content "$($PSScriptRoot)\90dayPwdException.txt" #"\\<network share path>\90dayPwdException.txt" # Get-ADGroupMember -Identity some90dExceptionGroup | select samaccountname
"User`tDescription`tPassword Age (days)`tDN`tPassword never expires`tPassword Last Set Date`tNotes" | out-file $outpath
$users = get-aduser -filter * -Properties distinguishedName,PasswordLastSet,Description,PasswordNeverExpires  | ?{$_.enabled -eq $true}
foreach($user in $users){
    if($user.SamAccountName -like "svc*" -or $user.SamAccountName -like "srv*" -or $knownServiceAccounts -contains $user.SamAccountName -or $exceptionList -contains $user.SamAccountName){
        writeLog "Skipping $($user.SamAccountName) - it is a service account" "warning"
        continue
    } 
    if($user.distinguishedName -like "*OU=ServiceAccounts,DC=domain,DC=com"){
        writeLog "Skipping $($user.SamAccountName) - in service account ou" "warning"
        continue
    }
    if($knownServiceAccounts -contains $user.SamAccountName -or $exceptionList -contains $user.SamAccountName){
        writeLog "Skipping $($user.SamAccountName) - it is an admin account" "warning"
        continue
    }
    #filter out admins
    #if($user.SamAccountName -like "a_*" -or $user.SamAccountName -like "d_*" -or $user.SamAccountName -like "w_*"-or $user.SamAccountName -like "s_*"){
    #    writeLog "Skipping $($user.SamAccountName) - it is an admin account" "warning"
    #    continue
    #}
    if($user.PasswordLastSet){
        if(((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days -ge 90)){
            writeLog "Enforcing password at next logon on $($user.SamAccountName)" "info"
            writeLog "$($user.SamAccountName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})`t$((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days)`t$($user.DistinguishedName)`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(get-date -Format "yyyyMMMdd") flipped to password required at next logon" "info"
            "$($user.SamAccountName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})`t$((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days)`t$($user.DistinguishedName)`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(get-date -Format "yyyyMMMdd") flipped to password required at next logon" | Out-File $outpath -Append
            try{
                Set-ADUser -Identity $user.SamAccountName -CannotChangePassword:$false -PasswordNeverExpires:$false -ChangePasswordAtLogon:$true -ErrorAction "stop"
            }catch{
                writeLog "error modifying $($user.SamAccountName)`n-----ErrorStart-----`n$_`n-----ErrorEnd-----`n"
            }
        }
    }else{
        writeLog "$($user.SamAccountName) missing PasswordLastSet" "warning"
        writeLog "$($user.SamAccountName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})`t<PasswordLastSet missing - password never changed or value was lost or pending reset>`t$($user.DistinguishedName)`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(get-date -Format "yyyyMMMdd") flipped to password required at next logon" "info"
        "$($user.SamAccountName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})`t<PasswordLastSet missing - password never changed or value was lost or pending reset>`t$($user.DistinguishedName)`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(get-date -Format "yyyyMMMdd") flipped to password required at next logon" | Out-File $outpath -Append
        try{
            Set-ADUser -Identity $user.SamAccountName -CannotChangePassword:$false -PasswordNeverExpires:$false -ChangePasswordAtLogon:$true -ErrorAction "stop"
        }catch{
            writeLog "error modifying $($user.SamAccountName)`n-----ErrorStart-----`n$_`n-----ErrorEnd-----`n"
        }
    }
    
}