function get-adgroupmember-recursive {
    param(
        $groupname
    )
    $list = ""
    foreach ($member in Get-ADGroupMember $groupname) {
        #write-host "$member is a $($member.ObjectClass)"
        if ($member.ObjectClass.tolower() -eq "group") {
            write-host "found group: $($member.samaccountName)"
            $list += "$($member.samaccountName),$($member.ObjectClass),$($member.distinguishedname.replace(",",";"))`n"
            $list += get-adgroupmember-recursive $member.samaccountName
        }else{
            $list += "$($member.samaccountName),$($member.ObjectClass),$($member.distinguishedname.replace(",",";"))`n"
        }    
    }
    return $list
}
get-adgroupmember-recursive "Domain Admins" | Write-Host
