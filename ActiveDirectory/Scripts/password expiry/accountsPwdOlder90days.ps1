$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")userPwdOlderThan90days.csv"
"User`tPassword Age (days)`tDN`tPassword never expires`tPassword Last Set Date`tNotes`tDescription" | out-file $outpath
$users = get-aduser -filter * -Properties PasswordLastSet,Description,PasswordNeverExpires  | ?{$_.enabled -eq $true}
foreach($user in $users){
    if($user.PasswordLastSet){
        if(((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days -ge 90)){
            write-host "$($user.SamAccountName)`t$((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days)`t$($user.DistinguishedName.replace(",",";"))`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(if($user.SamAccountName -like "svc*" -or $user.SamAccountName -like "srv*"){"service account, contact system owner before reseting password to prevent system break"})`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})"
            "$($user.SamAccountName)`t$((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days)`t$($user.DistinguishedName.replace(",",";"))`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(if($user.SamAccountName -like "svc*" -or $user.SamAccountName -like "srv*"){"service account, contact system owner before reseting password to prevent system break"})`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | Out-File $outpath -Append
        }
    }else{
        write-host "$($user.SamAccountName)`t<PasswordLastSet missing - password never changed or value was lost or pending reset>`t$($user.DistinguishedName.replace(",",";"))`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(if($user.SamAccountName -like "svc*" -or $user.SamAccountName -like "srv*"){"service account, contact system owner before reseting password to prevent system break"})`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})"
        "$($user.SamAccountName)`t<PasswordLastSet missing - password never changed or value was lost or pending reset>`t$($user.DistinguishedName.replace(",",";"))`t$($user.PasswordNeverExpires)`t$($user.PasswordLastSet)`t$(if($user.SamAccountName -like "svc*" -or $user.SamAccountName -like "srv*"){"service account, contact system owner before reseting password to prevent system break"})`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | Out-File $outpath -Append
    }
    
}

write-host "found $(($users | ?{($_.PasswordLastSet -and ((New-TimeSpan -Start $_.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days -ge 90)) -or -not($_.PasswordLastSet)}).count) user objects with passwords too old"

