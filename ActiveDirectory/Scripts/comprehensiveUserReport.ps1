$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")comprehensiveUserReport.csv"
"Name;DN;SID;Description;Creation Date;Last Modification Date;Password last changed;Password Age (Days);Enabled;Group Membership Count;Group Membership" | out-file $outpath
foreach($user in (get-aduser -filter * -properties *)){
    $line = "$($user.SamAccountName));$($user.distinguishedname);$($user.sid);$($user.description.replace("`r",'').replace("`n",''));$($user.whenCreated);$($user.whenChanged);$($user.PasswordLastSet);$((New-TimeSpan -Start $user.PasswordLastSet.ToString("yyyy-MM-dd") -End (get-date).ToString("yyyy-MM-dd")).Days);$($user.Enabled);$($user.MemberOf.Count);"
    foreach($group in $user.MemberOf){
        $line += "$($group.split(",")[0].split("=")[1]):"
    }
    write-host $line
    $line | out-file $outpath -Append
}




