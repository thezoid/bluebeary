$sentinel = "EXIT"
do{
    $userIn = read-host "Please provide a samaccountname"
    if(get-aduser $userIn){
        Set-ADUser -Identity $userIn -CannotChangePassword:$false -PasswordNeverExpires:$false -ChangePasswordAtLogon:$false
    }
}while($userIn.tolower() -ne $sentinel.tolower())


