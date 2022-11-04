$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")usersOlderThan180days.csv"
$outpathfail = "c:\temp\$(get-date -format "yyyyMMMdd")usersOlderThan180days_failed.csv"
"User`tLast Logon Date`tCan Delete?`tOU`tDescription" | out-file $outpath
"User`tOU" | out-file $outpathfail
$count = 0
$failcount = 0
foreach($user in get-aduser -filter * -Properties lastlogon,lastLogonTimestamp,whenChanged,description | ?{$_.enabled -eq $false}){
    
    if ($null -ne $user.lastLogonTimestamp -and $user.lastLogonTimestamp -ne 0 -and (get-date $user.lastLogonTimestamp) -lt (get-date).AddDays(-180)){
        "$($user.name)`t$([datetime]::FromFileTime($user.lastLogonTimestamp)|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | out-file $outpath -Append
        write-host "lastLogonTimestamp -- $($user.name)`t$([datetime]::FromFileTime($user.lastLogonTimestamp)|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})"
        $count++
    }
    elseif($null -ne $user.lastlogon -and $user.lastlogon -ne 0 -and (get-date $user.lastlogon) -lt (get-date).AddDays(-180)){
        "$($user.name)`t$($user.lastlogon|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | out-file $outpath -Append
        write-host "lastlogon -- $($user.name)`t$([datetime]::FromFileTime($user.lastlogon)|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" -foregroundcolor cyan
        $count++
    }elseif ($null -ne $user.whenChanged -and $user.whenChanged -ne 0 -and (get-date $user.whenChanged) -lt (get-date).AddDays(-180)){
        "$($user.name)`t$($user.whenChanged|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | out-file $outpath -Append
        write-host "whenChanged -- $($user.name)`t$([datetime]::FromFileTime($user.whenChanged)|get-date -format "yyyyMMMdd hh:mm:ss")`tYES`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" -foregroundcolor yellow
        $count++
    }
    elseif($null -eq $user.whenChanged){
        write-host "$($user.name) had null lastLogonTimestamp and lastlogon, or had 0/null value [$([datetime]::FromFileTime($user.whenChanged)|get-date -format "yyyyMMMdd hh:mm:ss")]" -foregroundcolor red
        "$($user.name)`t$($user.DistinguishedName)" | out-file $outpathfail -append
        $failcount++
    }elseif(($null -eq $user.lastLogonTimestamp -or $null -eq $user.lastlogon) -and (get-date $user.whenChanged) -lt (get-date).AddDays(-180)){
        write-host "$($user.name) had null lastLogonTimestamp and lastlogon, or had 0/null value [$([datetime]::FromFileTime($user.whenChanged)|get-date -format "yyyyMMMdd hh:mm:ss")/$([datetime]::FromFileTime($user.lastLogonTimestamp)|get-date -format "yyyyMMMdd hh:mm:ss")]" -foregroundcolor red
        "$($user.name)`t$($user.DistinguishedName)" | out-file $outpathfail -append
        $failcount++
    }
    else{
        write-host "$($user.name) not 180+ [$($user.whenChanged|get-date -format "yyyyMMMdd hh:mm:ss")/$([datetime]::FromFileTime($user.lastLogonTimestamp)|get-date -format "yyyyMMMdd hh:mm:ss")]" -foregroundcolor green
        "$($user.name)`t$($user.whenChanged|get-date -format "yyyyMMMdd hh:mm:ss")`tNO`t$($user.DistinguishedName)`t$(if($user.Description){$user.Description.replace("`t",' ').replace("`n",' ').replace("`r",' ')}else{"<no description>"})" | out-file $outpath -Append
    }

}

write-host "saw $count users past 180 days`ncouldnt process $failcount user objects`ntarget is earlier than: $((get-date).AddDays(-180))"


