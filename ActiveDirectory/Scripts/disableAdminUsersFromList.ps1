#headers assumed firstname,lastname,samaccountname,email
$users = import-csv "C:\temp\userList.csv" -Header "firstname","lastname","samaccountname","email"

foreach($user in $users){  
    if(get-aduser -Filter "samaccountname -like '$($user.samaccountname)'"){
        write-host "Attempting to disable:`n`tName: $($user.firstname) $($user.lastname)`n`tEmail: $($user.email)`n`tsAMAccountName: $($user.samaccountname)"
        "Name: $($user.firstname) $($user.lastname),Email: $($user.email),`tsAMAccountName: $($user.samaccountname)" | Out-File "c:\temp\disabledusers.csv" -Append
        disable-adaccount -identity $user.samaccountname
        get-aduser -Filter "samaccountname -like '$($user.samaccountname)'" | Set-ADObject -Description "Disabled $(get-date -Format "yyyy/MM/dd") as part of offboarding"
    }
    #domain admins
    if(get-aduser -Filter "samaccountname -like 'd_$($user.samaccountname)'"){
        write-host "Attempting to disable:`n`tName: $($user.firstname) $($user.lastname)`n`tEmail: $($user.email)`n`tsAMAccountName: d_$($user.samaccountname)"
        "Name: $($user.firstname) $($user.lastname),Email: $($user.email),`tsAMAccountName: $($user.samaccountname)" | Out-File "c:\temp\disabledusers.csv" -Append
        disable-adaccount -identity "d_$($user.samaccountname)"
        get-aduser -Filter "samaccountname -like 'd_$($user.samaccountname)'" | Set-ADObject -Description "Disabled $(get-date -Format "yyyy/MM/dd") as part of offboarding"
    }
    #server admins
    if(get-aduser -Filter "samaccountname -like 'a_$($user.samaccountname)'"){
        write-host "Attempting to disable:`n`tName: $($user.firstname) $($user.lastname)`n`tEmail: $($user.email)`n`tsAMAccountName: a_$($user.samaccountname)"
        "Name: $($user.firstname) $($user.lastname),Email: $($user.email),`tsAMAccountName: a_$($user.samaccountname)" | Out-File "c:\temp\disabledusers.csv" -Append
        disable-adaccount -identity "a_$($user.samaccountname)"
        get-aduser -Filter "samaccountname -like 'a_$($user.samaccountname)'" | Set-ADObject -Description "Disabled $(get-date -Format "yyyy/MM/dd") as part of offboarding"
    }
    #workstation admins
    if(get-aduser -Filter "samaccountname -like 'w_$($user.samaccountname)'"){
        write-host "Attempting to disable:`n`tName: $($user.firstname) $($user.lastname)`n`tEmail: $($user.email)`n`tsAMAccountName: a_$($user.samaccountname)"
        "Name: $($user.firstname) $($user.lastname),Email: $($user.email),`tsAMAccountName: a_$($user.samaccountname)" | Out-File "c:\temp\disabledusers.csv" -Append
        disable-adaccount -identity "a_$($user.samaccountname)"
        get-aduser -Filter "samaccountname -like 'a_$($user.samaccountname)'" | Set-ADObject -Description "Disabled $(get-date -Format "yyyy/MM/dd") as part of offboarding"
    }
}