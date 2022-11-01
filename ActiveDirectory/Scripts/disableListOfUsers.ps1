#headers assumed firstname,lastname,samaccountname,email
$users = import-csv "C:\temp\userList.csv" -Header "firstname","lastname","samaccountname","email"

foreach($user in $users){
     write-host "=====`nAttempting to disable:`n`tName: $($user.firstname) $($user.lastname)`n`tEmail: $($user.email)`n`tsAMAccountName: $($user.samaccountname)"
     disable-adaccount -identity $user.samaccountname -whatif
}