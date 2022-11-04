#prompt for search phrase 
$targetPhrase = Read-Host -Prompt "phrase to search for" 
$domainName = "domain.com"
#get all GPOs in the domain 
write-host "loading all gpo..." 
$gpos = Get-GPO -all -domain $domainName
#look through each gpo for the target phrase 
foreach ($gpo in $gpos) { 
    write-host "analyzing $($gpo.DisplayName)..."
    $gporeport = Get-GPOReport -Guid $gpo.Id -ReportType Xml 
    if ($gporeport -match $targetPhrase) { 
        write-host "match found in: $($gpo.DisplayName)" -foregroundcolor "Green"
    }
}