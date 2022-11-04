$outpath = "c:\temp\$(get-date -Format "yyyyMMMdd")90dayresetadminemails.csv"
"samaccountname,emailaddress" | out-file $outpath
$users = get-aduser -filter * -Properties PasswordLastSet,Description,PasswordNeverExpires  | ?{$_.enabled -eq $true}
foreach($user in $users){
    if($user.PasswordLastSet){
        if(((New-TimeSpan -Start $user.PasswordLastSet.tostring("yyyy-MM-dd") -End (get-date -Format "yyyy-MM-dd")).Days -ge 90)){
            if($user.SamAccountName.tolower() -like "a_*" -or $user.SamAccountName.tolower() -like "d_*" -or $user.SamAccountName.tolower() -like "w_*"){
                try{
                    if(get-aduser $user.samaccountname.split("_")[1]){
                        get-aduser $user.samaccountname.split("_")[1] -properties emailaddress | select emailaddress | %{"$($user.samaccountname.split("_")[1]),$($_.emailaddress)" | Out-File $outpath -Append}
                    }
                }catch{
                    write-host "failed to get email from $($user.samaccountname.split("_")[1])`n$($Error[0])"
                    continue
                }
            }        
        }
    }
}