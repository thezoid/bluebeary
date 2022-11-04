$officeGroupName = "sg_office365_user"
$officeGroupMembers = get-adgroupMember $officeGroupName
$count = 0
$outpath = "c:\temp\$(get-date -format "yyyyMMMdd")officeUsersPruned.log"
"SamAccountName" | out-file $outpath
foreach($user in $officeGroupMembers){
    if($user.objectClass -ne "user"){
        write-host "found non-user object, removing"
        Remove-ADGroupMember -Identity $officeGroupName -members $user.SamAccountName -confirm:$false
    }else{
        $u = Get-ADUser $user.name -properties *
        if($u.enabled -eq $false){
            write-host "need to remove $($u.SamAccountName) [$($u.enabled)]"
            $user.name | out-file $outpath -Append
            Remove-ADGroupMember -Identity $officeGroupName -members $u.SamAccountName -confirm:$false
            $count++
        }
    }
}
write-host "Removed $count users from $officeGroupName"