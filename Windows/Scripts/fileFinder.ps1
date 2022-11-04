$targetRoot = "\\filesharehostname\share"
$targetPattern = "*ha*y*b*ay"
#grab all files and directories in $targetRoot path
$items = get-childitem $targetRoot -recurse
$found = $false #a flag used later to report if the file was found
$count = 0
#loop through all the items captured
#report when we find something that matches $targetPattern
foreach($item in $items){
    $count++
    write-host "[$($count)/$($items.count)]analyzing $($item.fullname)"
    if($item.Name.tolower() -like $targetPattern){
        write-host "check here:`t$($item.FullName)" -foregroundcolor green
        $found = $true
    }
}

if(-not $found){
    write-host "could not find a file matching [$targetPattern] under [$targetRoot]"
}