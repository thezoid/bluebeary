$builtingroups = Get-ADGroup -Filter * | ? { $_.groupscope -eq "DomainLocal" } | select name
"" | out-file c:\temp\emptygroups.csv
$emptygroups = Get-ADGroup -Filter * -Properties * | ? { -not($builtingroups -contains $_.name) -and (-not($_.members)) -or $_.members.count -eq 0 } | select name, description, distinguishedname
foreach ($group in $emptygroups) {
    write-host "$($group.name);$($group.description);$($group.distinguishedname)"
    "$($group.name);$($group.description);$($group.distinguishedname)" | out-file c:\temp\emptygroups.csv -append
}