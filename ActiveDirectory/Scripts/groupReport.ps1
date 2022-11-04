$groups = get-adgroup -filter * -Properties *
$groups | out-file c:\temp\groupdump_raw.txt
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")groupsReport.csv"

"Name`tDN`tSID`tDescription`tCreation Date`tLast Modification Date`tMember Count`tMember List`tGroup Membership Count`tGroup Membership" | out-file $outpath
foreach($group in $groups){
    $line = "$($group.SamAccountName)`t$($group.DistinguishedName)`t$($group.SID)`t$($group.Description)`t$($group.whenCreated)`t$($group.whenChanged)`t$($group.Members.count)`t"
    #get all group members
    foreach($member in $group.Members){
        $line += "$($member.split(",")[0].split("=")[1]):"
    }
    $line+="`t$($group.MemberOf.count)`t"
    #get all groups this group is nested in
    if($group.MemberOf.count -gt 0){
        foreach($ngroup in $group.MemberOf){
            $line+= "$($ngroup.split(",")[0].split("=")[1]):"
        }
    }

    write-host $line
    $line | out-file $outpath -Append
}
