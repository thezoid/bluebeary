$reportpath = "c:\temp\$(get-date -format "yyyyMMMdd")-UsersWithNullZeroLastLogonDate.csv"
"samaccountname,lastlogondate,whencreated,whenchanged" | Out-File $reportpath
foreach($user in (get-aduser -filter * -Properties * | ?{$_.LastLogonDate -eq 0 -or $_.LastLogonDate -eq $null})){
    write-host "$($user.samaccountname),$($user.lastlogondate),$($user.whencreated),$($user.whenchanged)" 
    "$($user.samaccountname),$($user.lastlogondate),$($user.whencreated),$($user.whenchanged)" | out-file $reportpath -Append
}